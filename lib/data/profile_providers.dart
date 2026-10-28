import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_providers.dart';
import 'library_providers.dart';
import 'local/database_provider.dart';
import 'profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (Ref ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
    );

/// The name the user typed in Settings, or an empty string when they have
/// never picked one.
///
/// Backed by the local profiles table, so it survives a sign-out and reads
/// instantly on a cold start without waiting for the network.
final StreamProvider<String> chosenDisplayNameProvider = StreamProvider<String>(
  (Ref ref) {
    final String? userId = ref.watch(currentUserProvider).valueOrNull?.id;
    if (userId == null) {
      return Stream<String>.value('');
    }
    return ref.watch(profileRepositoryProvider).watchDisplayName(userId);
  },
);

/// The name to show for the signed-in user.
///
/// A name chosen in Settings always wins; the Google account name is only the
/// fallback. Every screen reads this provider instead of touching
/// userFirstName directly, which is what makes a rename show up in the header,
/// Settings and the library at the same moment.
final NotifierProvider<DisplayNameController, String> displayNameProvider =
    NotifierProvider<DisplayNameController, String>(DisplayNameController.new);

class DisplayNameController extends Notifier<String> {
  @override
  String build() {
    final User? user = ref.watch(currentUserProvider).valueOrNull;
    final String chosen =
        (ref.watch(chosenDisplayNameProvider).valueOrNull ?? '').trim();
    if (chosen.isNotEmpty) {
      return chosen;
    }
    final String? fallback = userFirstName(user);
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    if (user == null && ref.watch(guestModeProvider)) {
      return 'زائر';
    }
    return user == null ? 'بطاقاتي' : 'صديقنا';
  }

  /// Saves [name] locally and pushes it to Supabase. Throws [ProfileFailure]
  /// when the name is unusable or nobody is signed in.
  Future<void> rename(String name) async {
    final User? user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const ProfileFailure('سجّل الدخول أولاً لتغيير الاسم.');
    }
    await ref.read(profileRepositoryProvider).setDisplayName(user.id, name);
    // The library shows this name as the author of every published deck, so
    // drop the cached catalog rather than let the old name linger on screen.
    ref.invalidate(libraryDecksProvider);
  }
}
