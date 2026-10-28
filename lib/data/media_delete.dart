import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/config/imagekit_config.dart';

/// Removes card media from the cloud once the card or deck that owned it is
/// gone.
///
/// The work happens in the delete-media Edge Function, which holds the ImageKit
/// private key and refuses any path outside the caller's own folder. This class
/// is only the transport, and it is deliberately forgiving: deleting a deck
/// must never fail because a picture could not be removed, so nothing here
/// throws and nothing is awaited by the UI.
class MediaDeleteService {
  const MediaDeleteService();

  /// The function accepts 400 targets. A deck purge is chunked far below that
  /// so one oversized request cannot sink the whole batch.
  static const int _batchSize = 100;

  /// Starts a deletion without waiting for it.
  ///
  /// Every caller is a repository write that has already committed: the row is
  /// gone, the user has seen the deck disappear, and blocking that animation on
  /// a CDN round trip would buy nothing.
  void schedule(Iterable<String> urls) {
    unawaited(deleteAll(urls));
  }

  /// Deletes every entry of [urls] that lives in our own storage.
  ///
  /// Local 'file://' paths and foreign hosts are dropped before the request:
  /// the function would refuse them anyway, and sending them would turn a
  /// harmless no-op into a long failure list in the logs.
  Future<void> deleteAll(Iterable<String> urls) async {
    final List<String> targets = <String>{
      for (final String url in urls)
        if (_isOurs(url)) url.trim(),
    }.toList(growable: false);
    if (targets.isEmpty || !AppConfig.hasSupabase) {
      return;
    }
    final String? token =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      return;
    }
    for (int start = 0; start < targets.length; start += _batchSize) {
      final int end = start + _batchSize;
      await _send(
        targets.sublist(start, end > targets.length ? targets.length : end),
        token,
      );
    }
  }

  /// True for a URL the delete-media function is allowed to touch: ImageKit
  /// media, plus the Supabase bucket that held audio before the move.
  static bool _isOurs(String url) {
    final String value = url.trim();
    if (value.startsWith(imageKitUrlEndpoint)) {
      return true;
    }
    return value.contains('/storage/v1/object/') &&
        value.contains('/card-media/');
  }

  Future<void> _send(List<String> urls, String token) async {
    try {
      await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/delete-media'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'apikey': AppConfig.supabasePublishableKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{'urls': urls}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      // Orphaned files cost a little storage. A failed delete must never reach
      // the learner, who has already moved on.
      debugPrint('delete-media failed: $error');
    }
  }
}
