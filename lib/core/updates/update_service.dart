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

  /// The GitHub release body, exactly as the maintainer wrote it.
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
  UpdateService({
    required SharedPreferences prefs,
    http.Client? client,
    DateTime Function()? clock,
  }) : _prefs = prefs,
       _client = client ?? http.Client(),
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

  /// A launch check reuses a result younger than this. GitHub allows 60
  /// unauthenticated requests an hour per address, and an app that is opened
  /// often would burn through that for nothing.
  static const Duration _cacheTtl = Duration(hours: 3);

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
  /// [force] skips the cache; the Settings row uses it so a tap always asks
  /// GitHub rather than replaying a three-hour-old answer.
  Future<UpdateInfo?> check({bool force = false}) async {
    final String current = await currentVersion();
    if (!force) {
      final UpdateInfo? cached = _readCache(current);
      if (cached != null) {
        return cached;
      }
    }
    final UpdateInfo? fetched = await _fetch(current);
    if (fetched != null) {
      _writeCache(fetched);
    }
    return fetched;
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
        releaseNotes: _string(decoded['body']),
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
