import 'package:supabase_flutter/supabase_flutter.dart';

/// Helpers for showing a Supabase user in the UI.
///
/// Google populates different metadata keys depending on the platform, so the
/// lookups are deliberately tolerant and always fall back to a safe value.

String? userMeta(User? user, String key) {
  final Object? value = user?.userMetadata?[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

/// The user's given name, else the first word of their full name, else the
/// local part of their email.
String? userFirstName(User? user) {
  final String? given = userMeta(user, 'given_name');
  if (given != null) {
    return given;
  }
  final String? full = userMeta(user, 'full_name') ?? userMeta(user, 'name');
  if (full != null) {
    return full.split(RegExp(r'\s+')).first;
  }
  final String? email = user?.email;
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }
  return null;
}

String? userAvatarUrl(User? user) {
  return userMeta(user, 'avatar_url') ?? userMeta(user, 'picture');
}

/// One-letter fallback shown when no avatar is available.
String userInitial(User? user) {
  final String? name = userFirstName(user);
  if (name == null || name.isEmpty) {
    return 'ب';
  }
  return name.substring(0, 1);
}
