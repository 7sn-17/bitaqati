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
/// answer instead of asking GitHub twice. It is deliberately not auto-disposed
/// and not cached to disk with a time window: the shell evaluates it once per
/// cold start, which is what makes a release published an hour ago show up on
/// the next launch instead of after a timer expires.
final FutureProvider<UpdateInfo?> updateInfoProvider =
    FutureProvider<UpdateInfo?>(
      (Ref ref) => ref.watch(updateServiceProvider).check(),
    );

/// The installed version, read from the Android manifest rather than from a
/// constant, so the number in the UI can never drift from the APK.
final FutureProvider<String> appVersionProvider = FutureProvider<String>(
  (Ref ref) => ref.watch(updateServiceProvider).currentVersion(),
);

/// The release the user said "later" to, for this run of the app only.
///
/// Nothing is written to disk. That is the whole point: "later" used to mean
/// "never again" because the dismissed version was persisted, so a user who
/// tapped it once stopped being told about that release for good. Holding it
/// in memory gives the behaviour the button promises — quiet for the rest of
/// this session, offered again the next time the app is opened.
class UpdateDismissedNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void dismiss(String version) => state = version;
}

final NotifierProvider<UpdateDismissedNotifier, String?>
updateDismissedProvider = NotifierProvider<UpdateDismissedNotifier, String?>(
  UpdateDismissedNotifier.new,
);
