import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_providers.dart';
import 'widgets/app_message.dart';

/// Global guard for actions that need a real account.
///
/// Guest mode is local-only and read-only: decks, cards, library installs and
/// publishing all require a signed-in account. Returns `true` when the action
/// may continue; otherwise it shows a friendly sign-in prompt.
bool ensureSignedIn(
  BuildContext context,
  WidgetRef ref, {
  String message =
      'هذه الميزة تحتاج حساباً. سجّل الدخول من الإعدادات بحساب Google.',
}) {
  if (ref.read(authServiceProvider).currentUser != null) {
    return true;
  }
  showAppMessage(context, message, kind: AppMessageKind.info);
  return false;
}

/// Guard for content creation.
bool ensureCanCreate(BuildContext context, WidgetRef ref) {
  return ensureSignedIn(
    context,
    ref,
    message:
        'إنشاء المجموعات والبطاقات متاح للحسابات. '
        'سجّل الدخول من الإعدادات بحساب Google لحفظ بطاقاتك ومزامنتها.',
  );
}
