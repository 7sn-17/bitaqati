import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_providers.dart';
import 'widgets/app_message.dart';

/// Global guard for content creation.
///
/// Guest mode is local-only and read-only: decks, sub-decks, and cards can
/// only be created from a signed-in account. Every "create" or "add" entry
/// point calls this before opening an editor, so no screen can bypass it.
///
/// Returns `true` when the action may continue. Otherwise it shows a friendly
/// sign-in prompt and returns `false`.
bool ensureCanCreate(BuildContext context, WidgetRef ref) {
  if (ref.read(authServiceProvider).currentUser != null) {
    return true;
  }
  showAppMessage(
    context,
    'إنشاء المجموعات والبطاقات متاح للحسابات. '
    'سجّل الدخول من الإعدادات بحساب Google لحفظ بطاقاتك ومزامنتها.',
    kind: AppMessageKind.info,
  );
  return false;
}
