import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the updater learned about the newest published release.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    this.publishedAt,
    this.releaseUrl,
    this.checkedAt,
    this.fromCache = false,
    this.checkFailure,
  });

  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;

  /// The release description, minus the download guide that older releases
  /// carried. This is what the dialog shows under "ما الجديد".
  final String releaseNotes;

  /// Direct APK download. Always resolves to the newest build.
  final String downloadUrl;

  final DateTime? publishedAt;

  /// The release page, for a "read more" escape hatch.
  final String? releaseUrl;

  /// When this answer was produced. A cached answer keeps the timestamp of the
  /// check that produced it, so the UI can say how old it is instead of
  /// pretending it just came back from GitHub.
  final DateTime? checkedAt;

  /// True when every live source failed and this is the last stored answer.
  ///
  /// This is the flag that separates "nothing newer exists" from "we could not
  /// ask". Without it a stale cache entry was indistinguishable from a fresh
  /// "you are up to date", which is how a rate-limited request used to tell
  /// people they were current when they were two releases behind.
  final bool fromCache;

  /// Technical reason the live check failed. Written to the log, never shown.
  final String? checkFailure;

  /// The same answer, relabelled as the stored copy.
  UpdateInfo asCached({String? failure}) {
    return UpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      publishedAt: publishedAt,
      releaseUrl: releaseUrl,
      checkedAt: checkedAt,
      fromCache: true,
      checkFailure: failure,
    );
  }

  /// A cached copy round-trips through here so a launch does not always cost
  /// a network round trip.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'has_update': hasUpdate,
      'current_version': currentVersion,
      'latest_version': latestVersion,
      'release_notes': releaseNotes,
      'download_url': downloadUrl,
      'published_at': publishedAt?.toIso8601String(),
      'release_url': releaseUrl,
      'checked_at': checkedAt?.toIso8601String(),
    };
  }

  static UpdateInfo? fromJson(Map<String, Object?> json) {
    final String latest = _string(json['latest_version']);
    final String current = _string(json['current_version']);
    if (latest.isEmpty || current.isEmpty) {
      return null;
    }
    return UpdateInfo(
      hasUpdate: json['has_update'] == true,
      currentVersion: current,
      latestVersion: latest,
      releaseNotes: _string(json['release_notes']),
      downloadUrl: _string(json['download_url']).isEmpty
          ? UpdateService.downloadUrl
          : _string(json['download_url']),
      publishedAt: DateTime.tryParse(_string(json['published_at'])),
      releaseUrl: _string(json['release_url']).isEmpty
          ? null
          : _string(json['release_url']),
      checkedAt: DateTime.tryParse(_string(json['checked_at'])),
    );
  }
}

/// One attempt at answering "is there a newer build?".
typedef _Attempt = ({UpdateInfo? info, String? source, String? failure});

/// Checks GitHub Releases for a newer build of this app.
///
/// The release is published by CI from `pubspec.yaml`, so the tag is always
/// `v<version>` and the APK is always attached as `bitaqati.apk`. That makes
/// both the comparison and the download URL predictable.
///
/// Three sources are tried in order, because a single one is not enough:
///
/// 1. the REST API, which carries the notes and the asset list;
/// 2. the releases Atom feed, which is not rate limited;
/// 3. the `/releases/latest` redirect, which only carries the tag.
///
/// The API alone used to be the whole system, and unauthenticated GitHub gives
/// an IP 60 requests an hour. Behind carrier NAT that budget is shared by
/// everyone on the same address, so a 403 was not an edge case: it was the
/// normal answer at peak times. The app read that 403 as "no answer", fell back
/// to a cached "no update", and told the user they were current.
class UpdateService {
  /// [prefs] is positional because it is the one required dependency; the
  /// rest exist so a test can inject a fake client and a fixed clock.
  UpdateService(this._prefs, {http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final http.Client _client;
  final DateTime Function() _clock;

  static const String owner = '7sn-17';
  static const String repo = 'bitaqati';

  static const String latestReleaseApi =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  /// Fallback one: an Atom document with the newest entries. GitHub serves it
  /// as a static file, so it is not subject to the API rate limit.
  static const String releasesFeed =
      'https://github.com/$owner/$repo/releases.atom';

  /// Fallback two: the `latest` URL answers `302` to the newest tag. One
  /// header, no body, no JSON, no quota.
  static const String releasePage =
      'https://github.com/$owner/$repo/releases/latest';

  /// Stable asset URL. CI renames the arm64 APK to exactly `bitaqati.apk` on
  /// every release, so this never changes between versions.
  static const String downloadUrl =
      'https://github.com/$owner/$repo/releases/latest/download/bitaqati.apk';

  static const String _userAgent = 'bitaqati-updater (Flutter; Android)';

  static const Map<String, String> _jsonHeaders = <String, String>{
    'Accept': 'application/vnd.github+json',
    'User-Agent': _userAgent,
  };

  static const Map<String, String> _documentHeaders = <String, String>{
    'Accept': 'application/atom+xml,text/html;q=0.9,*/*;q=0.8',
    'User-Agent': _userAgent,
  };

  static const Duration _timeout = Duration(seconds: 10);

  /// How long a remembered answer may stand in for a failed check.
  ///
  /// Every launch asks GitHub, so this is not a rate-limit shield: it is what
  /// keeps the prompt working on a phone that opens the app with no network.
  /// A week survives a holiday and is short enough that a release pulled from
  /// the repo stops being advertised soon after.
  static const Duration _cacheTtl = Duration(days: 7);

  static const String _cacheKey = 'update_cache';
  static const String _legacyCacheAtKey = 'update_cache_at';

  /// Version installed on this device, from the Android manifest.
  Future<String> currentVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String version = info.version.trim();
      if (version.isNotEmpty) {
        return version;
      }
    } catch (error) {
      debugPrint('[update] could not read the installed version: $error');
    }
    return '0.0.0';
  }

  /// Returns null when the check could not be made at all — offline and with
  /// nothing cached, or every source failing on a fresh install. Callers treat
  /// null as "nothing to show", never as "you are up to date".
  ///
  /// When a live check fails but a stored answer exists, that answer comes back
  /// with [UpdateInfo.fromCache] set. The caller is then free to show a pending
  /// update, but it must not claim the app is current: the stored answer is
  /// only as new as the check that wrote it.
  Future<UpdateInfo?> check() async {
    final String installed = await currentVersion();
    final String current = normaliseVersion(installed);
    _log('check start · installed=$installed · compared=$current');

    final _Attempt attempt = await _fetch(current);
    final UpdateInfo? fresh = attempt.info;
    if (fresh != null) {
      _log(
        'check ok via ${attempt.source} · latest=${fresh.latestVersion} · '
        'hasUpdate=${fresh.hasUpdate}',
      );
      _writeCache(fresh);
      return fresh;
    }

    _log('check failed on every source · ${attempt.failure}');
    final UpdateInfo? cached = _readCache(current);
    if (cached == null) {
      _log('no usable cache · reporting "could not check"');
      return null;
    }
    _log(
      'serving cache from ${cached.checkedAt} · latest=${cached.latestVersion} '
      '· hasUpdate=${cached.hasUpdate}',
    );
    return cached.asCached(failure: attempt.failure);
  }

  Future<_Attempt> _fetch(String current) async {
    final List<String> failures = <String>[];

    final UpdateInfo? api = await _fromApi(current, failures);
    if (api != null) {
      return (info: api, source: 'api', failure: null);
    }
    final UpdateInfo? feed = await _fromFeed(current, failures);
    if (feed != null) {
      return (info: feed, source: 'atom', failure: null);
    }
    final UpdateInfo? redirect = await _fromRedirect(current, failures);
    if (redirect != null) {
      return (info: redirect, source: 'redirect', failure: null);
    }
    return (info: null, source: null, failure: failures.join(' | '));
  }

  Future<UpdateInfo?> _fromApi(String current, List<String> failures) async {
    try {
      final http.Response response = await _client
          .get(Uri.parse(latestReleaseApi), headers: _jsonHeaders)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        final String note = _rateLimited(response.statusCode)
            ? ' (rate limited)'
            : '';
        failures.add('api HTTP ${response.statusCode}$note');
        _log(
          'api HTTP ${response.statusCode}$note · '
          '${_excerpt(response.body)}',
        );
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        failures.add('api body is not an object');
        return null;
      }
      final String tag = _string(decoded['tag_name']);
      if (tag.isEmpty) {
        failures.add('api response has no tag_name');
        _log('api response has no tag_name · ${_excerpt(response.body)}');
        return null;
      }
      _log('api tag=$tag');
      return _build(
        current: current,
        tag: tag,
        notes: _releaseNotes(decoded),
        assetUrl: _assetUrl(decoded),
        publishedAt: DateTime.tryParse(_string(decoded['published_at'])),
        releaseUrl: _string(decoded['html_url']),
      );
    } catch (error) {
      failures.add('api ${_describe(error)}');
      _log('api error: $error');
      return null;
    }
  }

  /// Fallback one: parse the newest entry out of the Atom feed.
  ///
  /// The feed is HTML-in-XML, so the notes need decoding and a light tag strip
  /// before the dialog can show them.
  Future<UpdateInfo?> _fromFeed(String current, List<String> failures) async {
    try {
      final http.Response response = await _client
          .get(Uri.parse(releasesFeed), headers: _documentHeaders)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        failures.add('atom HTTP ${response.statusCode}');
        _log('atom HTTP ${response.statusCode}');
        return null;
      }
      final String body = response.body;
      final int start = body.indexOf('<entry>');
      if (start < 0) {
        failures.add('atom has no entry');
        return null;
      }
      final int end = body.indexOf('</entry>', start);
      final String entry = body.substring(start, end < 0 ? body.length : end);

      final RegExpMatch? link = RegExp(r'href="([^"]*/releases/tag/[^"]+)"')
          .firstMatch(entry);
      if (link == null) {
        failures.add('atom entry has no release link');
        return null;
      }
      final String href = link.group(1) ?? '';
      final List<String> segments = Uri.parse(href).pathSegments;
      if (segments.isEmpty) {
        failures.add('atom link is not a tag URL');
        return null;
      }
      final String tag = segments.last;
      final String title = _xmlText(entry, 'title');
      _log('atom tag=$tag');
      return _build(
        current: current,
        tag: tag,
        notes: _cleanNotes(_plainFromHtml(_xmlText(entry, 'content')), title),
        assetUrl: null,
        publishedAt: DateTime.tryParse(_xmlText(entry, 'updated')),
        releaseUrl: href,
      );
    } catch (error) {
      failures.add('atom ${_describe(error)}');
      _log('atom error: $error');
      return null;
    }
  }

  /// Fallback two: read the tag straight off the redirect target.
  ///
  /// Only the version survives this path — no notes, no asset URL — but a
  /// version is the one thing the check cannot do without, and the download URL
  /// is stable, so a partial answer still gets the user updated.
  Future<UpdateInfo?> _fromRedirect(
    String current,
    List<String> failures,
  ) async {
    try {
      final http.Request request = http.Request('GET', Uri.parse(releasePage))
        ..followRedirects = false
        ..headers.addAll(_documentHeaders);
      final http.StreamedResponse response = await _client
          .send(request)
          .timeout(_timeout);
      try {
        await response.stream.drain<void>();
      } catch (error) {
        // The redirect carries no useful body, so a broken stream is not a
        // failure of the check.
        _log('redirect body could not be drained: $error');
      }
      final String location = response.headers['location'] ?? '';
      final List<String> segments =
          Uri.tryParse(location)?.pathSegments ?? const <String>[];
      final int index = segments.indexOf('tag');
      if (index < 0 || index + 1 >= segments.length) {
        failures.add('redirect HTTP ${response.statusCode} without a tag');
        _log('redirect HTTP ${response.statusCode} · location=$location');
        return null;
      }
      final String tag = segments[index + 1];
      _log('redirect tag=$tag');
      return _build(
        current: current,
        tag: tag,
        notes: '',
        assetUrl: null,
        publishedAt: null,
        releaseUrl: releasePage,
      );
    } catch (error) {
      failures.add('redirect ${_describe(error)}');
      _log('redirect error: $error');
      return null;
    }
  }

  UpdateInfo _build({
    required String current,
    required String tag,
    required String notes,
    required String? assetUrl,
    required DateTime? publishedAt,
    required String? releaseUrl,
  }) {
    final String latest = normaliseVersion(tag);
    final bool newer = isNewer(latest, current);
    _log('compare · latest=$latest vs current=$current · newer=$newer');
    return UpdateInfo(
      hasUpdate: newer,
      currentVersion: current,
      latestVersion: latest,
      releaseNotes: notes,
      downloadUrl: assetUrl == null || assetUrl.isEmpty
          ? downloadUrl
          : assetUrl,
      publishedAt: publishedAt,
      releaseUrl: releaseUrl == null || releaseUrl.isEmpty ? null : releaseUrl,
      checkedAt: _clock(),
    );
  }

  /// Prefers the `bitaqati.apk` asset when the release has one, and falls
  /// back to the stable `/releases/latest/download/` URL otherwise.
  String? _assetUrl(Map<String, Object?> json) {
    final Object? assets = json['assets'];
    if (assets is! List<Object?>) {
      return null;
    }
    for (final Object? entry in assets) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      if (_string(entry['name']) != 'bitaqati.apk') {
        continue;
      }
      final String url = _string(entry['browser_download_url']);
      if (url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  /// The release description, with the download guide cut out.
  ///
  /// Older releases carried a "which file do I download?" paragraph listing
  /// every APK by name, and the dialog showed it verbatim — so the first thing
  /// a user read about a new version was a filename like
  /// bitaqati-v1.1.0-arm64-v8a.apk. The pipeline no longer writes that
  /// paragraph; this drops it from the releases that already have it, because
  /// those are the ones still being offered to people on old builds.
  ///
  /// A block is removed whole rather than line by line: the heading and its
  /// list belong together, and deleting only the file names would leave a
  /// question hanging with nothing under it.
  static String _releaseNotes(Map<String, Object?> json) {
    final String fallback = _string(json['name']);
    return _cleanNotes(_string(json['body']), fallback);
  }

  static String _cleanNotes(String body, String fallback) {
    if (body.isEmpty) {
      return fallback;
    }
    final String notes = body
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'))
        .where((String block) => !block.toLowerCase().contains('.apk'))
        .join('\n\n')
        .trim();
    return notes.isEmpty ? fallback : notes;
  }

  UpdateInfo? _readCache(String current) {
    final String? raw = _prefs.getString(_cacheKey);
    if (raw == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final UpdateInfo? cached = UpdateInfo.fromJson(decoded);
      if (cached == null || cached.currentVersion != current) {
        // A fresh install or an update makes the cached comparison wrong.
        return null;
      }
      final DateTime? at = cached.checkedAt;
      if (at == null || _clock().difference(at) > _cacheTtl) {
        return null;
      }
      return cached;
    } catch (_) {
      return null;
    }
  }

  void _writeCache(UpdateInfo info) {
    try {
      _prefs.setString(_cacheKey, jsonEncode(info.toJson()));
    } catch (error) {
      debugPrint('[update] could not cache the check: $error');
    }
  }

  /// Drops the cached answer, used after the user updates.
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_legacyCacheAtKey);
  }

  /// Strips a leading `v` so `v1.0.0` and `1.0.0` compare equal.
  static String normaliseVersion(String raw) {
    String value = raw.trim();
    while (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    return value.split('+').first;
  }

  /// True when [candidate] is a later release than [current].
  static bool isNewer(String candidate, String current) {
    return compareVersions(candidate, current) > 0;
  }

  /// Semver-ish comparison: numeric segments first, then the pre-release tag.
  ///
  /// A release without a pre-release tag always wins over one with it, so
  /// `1.0.0` beats `1.0.0-beta.2`.
  static int compareVersions(String a, String b) {
    final List<int> left = _segments(a);
    final List<int> right = _segments(b);
    final int length = left.length > right.length ? left.length : right.length;
    for (int index = 0; index < length; index++) {
      final int l = index < left.length ? left[index] : 0;
      final int r = index < right.length ? right[index] : 0;
      if (l != r) {
        return l.compareTo(r);
      }
    }
    final String leftTag = _preRelease(a);
    final String rightTag = _preRelease(b);
    if (leftTag == rightTag) {
      return 0;
    }
    if (leftTag.isEmpty) {
      return 1;
    }
    if (rightTag.isEmpty) {
      return -1;
    }
    return leftTag.compareTo(rightTag);
  }

  static List<int> _segments(String version) {
    final String core = normaliseVersion(version).split('-').first;
    return <int>[
      for (final String part in core.split('.'))
        int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
    ];
  }

  static String _preRelease(String version) {
    final String core = normaliseVersion(version);
    final int dash = core.indexOf('-');
    return dash < 0 ? '' : core.substring(dash + 1);
  }

  /// 403 is what GitHub answers once the hourly budget is gone; 429 is the
  /// generic form. Both mean "ask again later", never "nothing new".
  static bool _rateLimited(int status) => status == 403 || status == 429;

  /// Every diagnostic goes through here so a future failure can be read
  /// straight off logcat with a single grep: `adb logcat | grep \[update\]`.
  static void _log(String message) {
    debugPrint('[update] $message');
  }

  static String _describe(Object error) {
    final String text = error.toString().replaceAll('\n', ' ');
    return text.length <= 140 ? text : text.substring(0, 140);
  }

  static String _excerpt(String body) {
    final String flat = body.replaceAll('\n', ' ').trim();
    return flat.length <= 160 ? flat : flat.substring(0, 160);
  }

  /// Reads the text of the first [tag] element, handling CDATA.
  static String _xmlText(String xml, String tag) {
    final RegExpMatch? match = RegExp(
      '<$tag[^>]*>(.*?)</$tag>',
      dotAll: true,
    ).firstMatch(xml);
    if (match == null) {
      return '';
    }
    String value = match.group(1) ?? '';
    if (value.startsWith('<![CDATA[')) {
      value = value.substring(9);
      final int end = value.indexOf(']]>');
      if (end >= 0) {
        value = value.substring(0, end);
      }
      return value.trim();
    }
    return _decodeEntities(value).trim();
  }

  static String _decodeEntities(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  /// Turns a release body that arrived as HTML into the plain list the dialog
  /// expects: bullets stay bullets, everything else is dropped.
  static String _plainFromHtml(String html) {
    if (html.isEmpty) {
      return '';
    }
    return html
        .replaceAll(RegExp(r'</li>\s*', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>\s*', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

String _string(Object? value) => value is String ? value.trim() : '';
