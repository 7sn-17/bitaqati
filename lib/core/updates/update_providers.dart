import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'update_service.dart';

/// The updater, wired to the app's preferences so a check can be cached.
final Provider<UpdateService> updateServiceProvider = Provider<UpdateService>(
  (Ref ref) => UpdateService(ref.watch(sharedPreferencesProvider)),
);

/// The newest release, or null when the check could not be made.
///
/// Kept in a provider so the launch prompt and the Settings row share one
/// answer instead of asking GitHub twice.
final FutureProvider<UpdateInfo?> updateInfoProvider =
    FutureProvider<UpdateInfo?>(
      (Ref ref) => ref.watch(updateServiceProvider).check(),
    );

/// The installed version, read from the Android manifest rather than from a
/// constant, so the number in the UI can never drift from the APK.
final FutureProvider<String> appVersionProvider = FutureProvider<String>(
  (Ref ref) => ref.watch(updateServiceProvider).currentVersion(),
);

/// The release the user already said "later" to.
///
/// One version only: a newer release shows the prompt again, and the same one
/// never nags twice.
class UpdateDismissedNotifier extends Notifier<String?> {
  static const String _key = 'update_dismissed_version';

  @override
  String? build() {
    return ref.watch(sharedPreferencesProvider).getString(_key);
  }

  Future<void> dismiss(String version) async {
    state = version;
    await ref.read(sharedPreferencesProvider).setString(_key, version);
  }
}

final NotifierProvider<UpdateDismissedNotifier, String?>
updateDismissedProvider = NotifierProvider<UpdateDismissedNotifier, String?>(
  UpdateDismissedNotifier.new,
);
