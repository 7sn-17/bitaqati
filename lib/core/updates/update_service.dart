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
    );
  }
}

/// Checks GitHub Releases for a newer build of this app.
///
/// The release is published by CI from `pubspec.yaml`, so the tag is always
/// `v<version>` and the APK is always attached as `bitaqati.apk`. That makes
/// both the comparison and the download URL predictable.
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

  /// Stable asset URL. CI renames the arm64 APK to exactly `bitaqati.apk` on
  /// every release, so this never changes between versions.
  static const String downloadUrl =
      'https://github.com/$owner/$repo/releases/latest/download/bitaqati.apk';

  static const String releasePage =
      'https://github.com/$owner/$repo/releases/latest';

  /// How long a remembered answer may stand in for a failed check.
  ///
  /// Every launch asks GitHub, so this is not a rate-limit shield: it is what
  /// keeps the prompt working on a phone that opens the app with no network.
  /// A week survives a holiday and is short enough that a release pulled from
  /// the repo stops being advertised soon after.
  static const Duration _cacheTtl = Duration(days: 7);

  static const String _cacheKey = 'update_cache';
  static const String _cacheAtKey = 'update_cache_at';

  /// Version installed on this device, from the Android manifest.
  Future<String> currentVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String version = info.version.trim();
      if (version.isNotEmpty) {
        return version;
      }
    } catch (error) {
      debugPrint('Could not read the installed version: $error');
    }
    return '0.0.0';
  }

  /// Returns null when the check could not be made at all — offline, rate
  /// limited, or GitHub answering with something unexpected. Callers treat
  /// null as "nothing to show", never as "you are up to date".
  ///
  /// There is no cached fast path. This runs once per launch and once per tap
  /// in Settings, and replaying a stored answer is exactly what used to hide a
  /// freshly published release for hours. The stored copy is now only a
  /// stand-in for a check that could not reach GitHub at all.
  Future<UpdateInfo?> check() async {
    final String current = await currentVersion();
    final UpdateInfo? fetched = await _fetch(current);
    if (fetched != null) {
      _writeCache(fetched);
      return fetched;
    }
    return _readCache(current);
  }

  Future<UpdateInfo?> _fetch(String current) async {
    try {
      final http.Response response = await _client
          .get(
            Uri.parse(latestReleaseApi),
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'bitaqati-updater',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Update check returned ${response.statusCode}.');
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final String tag = _string(decoded['tag_name']);
      if (tag.isEmpty) {
        return null;
      }
      final String latest = normaliseVersion(tag);
      return UpdateInfo(
        hasUpdate: isNewer(latest, current),
        currentVersion: current,
        latestVersion: latest,
        releaseNotes: _releaseNotes(decoded),
        downloadUrl: _assetUrl(decoded) ?? downloadUrl,
        publishedAt: DateTime.tryParse(_string(decoded['published_at'])),
        releaseUrl: _string(decoded['html_url']).isEmpty
            ? null
            : _string(decoded['html_url']),
      );
    } catch (error) {
      // Offline, DNS failure, timeout, malformed JSON: all the same to the
      // caller, and none of them should ever surface as an error to the user.
      debugPrint('Update check failed: $error');
      return null;
    }
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
    final String body = _string(json['body']);
    if (body.isEmpty) {
      return _string(json['name']);
    }
    final String notes = body
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'))
        .where((String block) => !block.toLowerCase().contains('.apk'))
        .join('\n\n')
        .trim();
    return notes.isEmpty ? _string(json['name']) : notes;
  }

  UpdateInfo? _readCache(String current) {
    final int? at = _prefs.getInt(_cacheAtKey);
    if (at == null) {
      return null;
    }
    final DateTime checkedAt = DateTime.fromMillisecondsSinceEpoch(at);
    if (_clock().difference(checkedAt) > _cacheTtl) {
      return null;
    }
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
      return cached;
    } catch (_) {
      return null;
    }
  }

  void _writeCache(UpdateInfo info) {
    try {
      _prefs.setString(_cacheKey, jsonEncode(info.toJson()));
      _prefs.setInt(_cacheAtKey, _clock().millisecondsSinceEpoch);
    } catch (error) {
      debugPrint('Could not cache the update check: $error');
    }
  }

  /// Drops the cached answer, used after the user updates.
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_cacheAtKey);
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
}

String _string(Object? value) => value is String ? value.trim() : '';
