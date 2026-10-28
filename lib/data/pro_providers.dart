import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/arabic_date.dart';
import '../core/auth/auth_providers.dart';
import '../core/config/app_config.dart';
import '../core/providers.dart';
import '../domain/freemium.dart';
import 'local/app_database.dart';
import 'profile_providers.dart';
import 'profile_repository.dart';

/// A stable fingerprint of this phone.
///
/// Free-tier limits are counted per device, so this has to survive a sign-out,
/// a reinstall of the account and a second Google login on the same phone.
/// Android's own `Settings.Secure.ANDROID_ID` is the anchor; the model and
/// brand are mixed in because the id is reset on a factory reset and shared by
/// nothing else, while the pair makes a collision between two different
/// phones practically impossible.
///
/// The result is a hash, not the raw id: nothing identifying leaves the
/// device, and the server only ever needs "same phone or not".
final FutureProvider<String> deviceIdProvider = FutureProvider<String>((
  Ref ref,
) async {
  final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
  final String? saved = prefs.getString(_deviceKey);
  if (saved != null && saved.isNotEmpty) {
    return saved;
  }
  String deviceId;
  try {
    final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
    final String seed = <String>[
      info.id,
      info.model,
      info.manufacturer,
      info.device,
      info.fingerprint,
    ].join('|');
    deviceId = 'and_${_fnv1a(seed)}';
  } catch (_) {
    // Not Android, or the platform channel refused. A random id still gives
    // the account a stable device, it just cannot detect a reinstall.
    final String fresh = const Uuid().v4().replaceAll('-', '');
    deviceId = 'dev_${fresh.substring(0, 20)}';
  }
  await prefs.setString(_deviceKey, deviceId);
  return deviceId;
});

const String _deviceKey = 'device_id';

/// FNV-1a, 64-bit, in base 36.
///
/// A full cryptographic digest would need another dependency for no benefit:
/// this only has to be stable and well spread across a handful of phones.
String _fnv1a(String input) {
  int hash = 0xcbf29ce484222325;
  for (final int unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  const String alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  final StringBuffer out = StringBuffer();
  int value = hash;
  while (value > 0) {
    out.write(alphabet[value % 36]);
    value ~/= 36;
  }
  return out.isEmpty ? '0' : out.toString();
}

/// Whose profile row this device is looking at.
///
/// Guests get their own row so a free guest still has a device id and an
/// entitlement to read, and so signing in does not inherit a guest's limits.
final Provider<String> profileScopeProvider = Provider<String>((Ref ref) {
  final User? user = ref.watch(currentUserProvider).valueOrNull;
  return user?.id ?? 'guest';
});

/// The live entitlement, read from the local profile row.
///
/// Local first on purpose: the paywall, the deck list and the icon picker all
/// read this, and none of them may show a spinner while the network answers.
/// [ProService.refresh] is what keeps the row honest.
final StreamProvider<ProStatus> proStatusProvider = StreamProvider<ProStatus>((
  Ref ref,
) {
  final String scope = ref.watch(profileScopeProvider);
  return ref
      .watch(profileRepositoryProvider)
      .watchProfile(scope)
      .map(
        (ProfileRow? row) =>
            ProStatus(isPro: row?.isPro ?? false, expiry: row?.proExpiryDate),
      );
});

/// The entitlement, read synchronously, for guards that run inside a tap.
///
/// It is a notifier rather than a plain provider because a subscription ends on
/// a clock, not on a database write: without something that re-reads itself at
/// the moment the date passes, a phone that has been open all day keeps showing
/// Pro until the next launch. The timer fires at the expiry (and at most hourly
/// while waiting), and asks the server once so the stored flag agrees with what
/// the user is being shown.
final NotifierProvider<ProNowNotifier, ProStatus> proNowProvider =
    NotifierProvider<ProNowNotifier, ProStatus>(ProNowNotifier.new);

class ProNowNotifier extends Notifier<ProStatus> {
  Timer? _timer;

  @override
  ProStatus build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    final ProStatus status =
        ref.watch(proStatusProvider).valueOrNull ?? const ProStatus();
    _arm(status);
    return status;
  }

  /// Wakes up when the paid period ends, so the UI flips to free on its own.
  void _arm(ProStatus status) {
    _timer?.cancel();
    _timer = null;
    final DateTime? until = status.expiry;
    if (!status.isPro || until == null) {
      return;
    }
    final Duration left = until.difference(DateTime.now());
    if (left.isNegative) {
      // Already over on paper: settle it with the server once, then let the
      // stream carry the answer.
      unawaited(
        Future<void>.microtask(() => ref.read(proServiceProvider).refresh()),
      );
      return;
    }
    final Duration wait = left > const Duration(hours: 1)
        ? const Duration(hours: 1)
        : left;
    _timer = Timer(wait, () {
      // A new instance notifies every listener even when the values are equal,
      // which is the point: `active` is computed from the clock, so the rebuild
      // is what turns Pro off.
      state = ProStatus(isPro: status.isPro, expiry: until);
      _arm(state);
      // Fired at the real end of the period, so the server is asked now.
      if (left <= wait) {
        unawaited(ref.read(proServiceProvider).refresh());
      }
    });
  }
}

/// What the activation call produced.
@immutable
class ActivationResult {
  const ActivationResult._({
    required this.ok,
    required this.message,
    this.plan,
    this.expiry,
  });

  const ActivationResult.success({
    required String message,
    ProPlan? plan,
    DateTime? expiry,
  }) : this._(ok: true, message: message, plan: plan, expiry: expiry);

  const ActivationResult.failure(String message)
    : this._(ok: false, message: message);

  final bool ok;
  final String message;
  final ProPlan? plan;
  final DateTime? expiry;
}

/// Talks to the `activate-code` Edge Function and keeps the local cache warm.
///
/// The code itself is never checked on the device: a client that can decide
/// whether a code is valid is a client that can be patched to always say yes.
/// The server owns the table, the expiry date and the "already used" flag.
class ProService {
  ProService(this._ref);

  final Ref _ref;

  /// Makes sure the profile row carries this device's id, then pulls the
  /// entitlement the server has.
  ///
  /// Safe to call on every launch and after every sign-in: it is one read and
  /// at most one write.
  Future<void> bootstrap() async {
    final String scope = _ref.read(profileScopeProvider);
    final String deviceId = await _ref.read(deviceIdProvider.future);
    final ProfileRepository repository = _ref.read(profileRepositoryProvider);
    await repository.setDeviceId(scope, deviceId);
    if (scope == 'guest' || !AppConfig.hasSupabase) {
      return;
    }
    await repository.pushToCloud(scope);
    await refresh();
  }

  /// Reads `is_pro` and `pro_expiry_date` from Supabase into the local row.
  Future<void> refresh() async {
    final String scope = _ref.read(profileScopeProvider);
    if (scope == 'guest' || !AppConfig.hasSupabase) {
      return;
    }
    try {
      final List<Map<String, dynamic>> rows = await Supabase.instance.client
          .from('profiles')
          .select('is_pro,pro_expiry_date')
          .eq('id', scope)
          .limit(1);
      if (rows.isEmpty) {
        return;
      }
      final Map<String, dynamic> row = rows.first;
      final Object? rawExpiry = row['pro_expiry_date'];
      final DateTime? expiry = rawExpiry is String
          ? DateTime.tryParse(rawExpiry)?.toLocal()
          : null;
      // The row can still say Pro after its date has passed: the flag is what
      // the server wrote when the code was redeemed, not a live clock. Cache
      // the honest answer, but keep the date, because "has ever paid" is what
      // grants the freeze bonus once the subscription lapses.
      final bool paid = row['is_pro'] == true;
      final bool live =
          paid && (expiry == null || expiry.isAfter(DateTime.now()));
      await _ref
          .read(profileRepositoryProvider)
          .cachePro(scope, isPro: live, expiry: expiry);
    } catch (_) {
      // Offline, or the row is not visible yet. The cached value stands.
    }
  }

  /// Redeems [code]. The server marks it used and returns the new expiry.
  Future<ActivationResult> activate(String code) async {
    final String scope = _ref.read(profileScopeProvider);
    final String clean = code.trim().toUpperCase();
    if (clean.length < 4) {
      return const ActivationResult.failure('أدخل الكود كما وصل إليك.');
    }
    if (!AppConfig.hasSupabase) {
      return const ActivationResult.failure(
        'التحقق من الأكواد يحتاج اتصالاً بالإنترنت.',
      );
    }
    final String? token =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      return const ActivationResult.failure(
        'سجّل الدخول بحساب Google أولاً، ثم أدخل الكود.',
      );
    }
    final String deviceId = await _ref.read(deviceIdProvider.future);
    try {
      final http.Response response = await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/activate-code'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'apikey': AppConfig.supabasePublishableKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'code': clean,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final Object? decoded = response.body.isEmpty
          ? null
          : jsonDecode(response.body);
      final Map<String, dynamic> body = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      if (response.statusCode != 200 || body['ok'] != true) {
        // Only trust the message when the function itself wrote it. The
        // gateway answers a rejected or expired session with its own English
        // payload, and showing "Invalid JWT" to an Arabic reader is worse than
        // the generic sentence below.
        final Object? message = body['message'];
        final bool fromFunction = body['ok'] == false;
        return ActivationResult.failure(
          fromFunction && message is String && message.isNotEmpty
              ? message
              : 'تعذّر التحقق من الكود. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
      final Object? rawExpiry = body['expiry_date'];
      final DateTime? expiry = rawExpiry is String
          ? DateTime.tryParse(rawExpiry)?.toLocal()
          : null;
      await _ref
          .read(profileRepositoryProvider)
          .cachePro(scope, isPro: true, expiry: expiry);
      // Naming the date answers the only question the reader has after a code
      // works: how long is this for.
      final String until = expiry == null
          ? ''
          : ' حتى ${formatArabicDate(expiry)}';
      return ActivationResult.success(
        message: 'تم تفعيل Pro على هذا الحساب$until.',
        plan: ProPlanInfo.fromCloud('${body['plan_type'] ?? ''}'),
        expiry: expiry,
      );
    } on TimeoutException {
      return const ActivationResult.failure(
        'لم يصل رد من الخادم. تحقق من اتصالك وحاول مرة أخرى.',
      );
    } catch (_) {
      return const ActivationResult.failure(
        'تعذّر التحقق من الكود. تحقق من اتصالك وحاول مرة أخرى.',
      );
    }
  }
}

final Provider<ProService> proServiceProvider = Provider<ProService>(
  (Ref ref) => ProService(ref),
);
