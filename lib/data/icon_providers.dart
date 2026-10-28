import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dynamic_icon.dart';
import '../core/providers.dart';

/// Whether this device lets the launcher icon change at all.
final FutureProvider<bool> dynamicIconSupportProvider = FutureProvider<bool>(
  (Ref ref) => DynamicIconService.supported,
);

/// The launcher icon this install is wearing.
///
/// One source of truth for three readers: the splash screen, the login screen
/// and the picker in Settings. They used to disagree — the picker kept the
/// choice in its own State, so the splash and the login screen went on drawing
/// the default artwork while the home screen showed the blue one.
///
/// The value is the *intent*: what the user picked, remembered on disk. The
/// platform is asked to match it on every launch by [ActiveIconController.sync].
final NotifierProvider<ActiveIconController, AppIconOption> activeIconProvider =
    NotifierProvider<ActiveIconController, AppIconOption>(
      ActiveIconController.new,
    );

class ActiveIconController extends Notifier<AppIconOption> {
  @override
  AppIconOption build() {
    return AppIconOption.byAlias(
      DynamicIconService.remembered(ref.watch(sharedPreferencesProvider)),
    );
  }

  /// Switches the launcher icon. Returns false when the platform refused, in
  /// which case the UI must not pretend the icon changed.
  Future<bool> choose(AppIconOption option) async {
    if (option.alias == state.alias) {
      return true;
    }
    final AppIconOption previous = state;
    // Written before the platform call on purpose. Disabling the alias this
    // task was launched from can finish the task, and a preference saved after
    // that call would never be written: the next launch would read the old
    // alias, decide the launcher had drifted, and put the old icon back. That
    // is the "it restarts and nothing changes" report, exactly.
    await DynamicIconService.remember(
      ref.read(sharedPreferencesProvider),
      option.alias,
    );
    state = option;
    final bool applied = await DynamicIconService.apply(option.alias);
    if (!applied) {
      await DynamicIconService.remember(
        ref.read(sharedPreferencesProvider),
        previous.alias,
      );
      state = previous;
      return false;
    }
    return true;
  }

  /// Puts the launcher back on the remembered icon when it drifted away.
  ///
  /// The enabled activity-alias survives an app update, so a phone that once
  /// picked the blue icon keeps it after the APK is replaced. Called once per
  /// launch; a no-op when the two already agree.
  Future<void> sync() async {
    final bool changed = await DynamicIconService.reconcile(
      ref.read(sharedPreferencesProvider),
    );
    if (!changed) {
      return;
    }
    state = AppIconOption.byAlias(
      DynamicIconService.remembered(ref.read(sharedPreferencesProvider)),
    );
  }
}
