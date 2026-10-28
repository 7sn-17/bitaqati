import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Whether the system will actually let a reminder reach the user.
enum ReminderAccess {
  /// Notifications are allowed.
  granted,

  /// Never asked, or asked and dismissed once. Asking again shows the dialog.
  denied,

  /// The user said no for good, or a device policy forbids it. Only the system
  /// settings screen can change this.
  blocked,

  /// No notification support on this platform.
  unsupported,
}

/// Daily study reminders.
///
/// One instance for the process: the plugin keeps a method channel open and
/// the tap callback has to survive whatever screen is on top, so a per-screen
/// service would lose notifications.
///
/// Scheduling rules:
///  * at most six a day, at 8, 11, 14, 17, 20 and 22 local time;
///  * fewer when little is due, so a single card never earns six nudges;
///  * none at all when nothing is due — every pending reminder is cancelled;
///  * exact alarms when the system allows them, inexact-but-while-idle when it
///    does not, so a dozing phone still gets the reminder eventually.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const String channelId = 'review_reminders';
  static const String channelName = 'تذكير المراجعة';
  static const String channelDescription =
      'تنبيهات لطيفة عندما تكون لديك بطاقات مستحقة.';

  /// The wall-clock hours a reminder may fire at, in order.
  static const List<int> slots = <int>[8, 11, 14, 17, 20, 22];

  /// Ids are `base + slot index` so a slot can be cancelled on its own.
  static const int _baseId = 4100;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _booting;
  bool _timezonesLoaded = false;
  String? _pendingDeckId;

  /// Called when a reminder is tapped while the app is running.
  void Function(String deckId)? onOpenDeck;

  /// Loads the timezone database, wires the plugin and remembers a tap that
  /// launched the app. Safe to call more than once; every failure is swallowed
  /// because a broken notification stack must never stop the app from opening.
  Future<void> init() => _booting ??= _boot();

  Future<void> _boot() async {
    if (!_timezonesLoaded) {
      tzdata.initializeTimeZones();
      _timezonesLoaded = true;
    }
    await _useDeviceTimezone();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          // A dedicated monochrome mask, not the launcher icon. Android draws
          // the small notification icon as a silhouette in the status bar, so
          // a coloured square came out as a white blob.
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
      final NotificationAppLaunchDetails? launch = await _plugin
          .getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        _pendingDeckId = launch.notificationResponse?.payload;
      }
    } catch (error) {
      debugPrint('Notifications unavailable: $error');
    }
  }

  /// Points the scheduler at the device's real zone.
  ///
  /// The plugin repeats a notification at a wall-clock time, so a device left
  /// on UTC would fire at the wrong hour. If the platform reports a name the
  /// database does not know, the default location is kept and the reminder
  /// still fires — just possibly at the wrong hour until the next launch, when
  /// this runs again.
  Future<void> _useDeviceTimezone() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      debugPrint('Timezone lookup failed, using the default location: $error');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// How many of the six slots a day's workload earns.
  static int slotsFor(int dueCount) {
    if (dueCount <= 0) {
      return 0;
    }
    if (dueCount >= 30) {
      return slots.length;
    }
    if (dueCount >= 10) {
      return 4;
    }
    return 2;
  }

  /// Replaces every pending reminder with a fresh set for [dueCount].
  ///
  /// Passing a count of zero cancels everything and schedules nothing, which
  /// is what happens the moment the last card of the day is answered.
  Future<void> schedule({
    required int dueCount,
    String? deckId,
    String? deckTitle,
  }) async {
    await init();
    try {
      await _plugin.cancelAll();
      final int count = slotsFor(dueCount);
      if (count == 0) {
        return;
      }
      if (await access() != ReminderAccess.granted) {
        return;
      }
      final AndroidScheduleMode mode = await _scheduleMode();
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      for (int index = 0; index < count; index++) {
        tz.TZDateTime when = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          slots[index],
        );
        if (!when.isAfter(now)) {
          // Rebuilt from the calendar rather than adding 24 hours, so a slot
          // that crosses a daylight-saving change still lands on the wall
          // clock the user expects.
          when = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + 1,
            slots[index],
          );
        }
        await _plugin.zonedSchedule(
          id: _baseId + index,
          title: 'حان وقت المراجعة',
          body: bodyFor(dueCount, deckTitle),
          scheduledDate: when,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: channelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: deckId ?? '',
        );
      }
    } catch (error) {
      debugPrint('Could not schedule reminders: $error');
    }
  }

  /// Cancels every pending reminder without scheduling new ones.
  Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not cancel reminders: $error');
    }
  }

  /// Exact alarms are blocked on Android 14+ until the user allows them, and a
  /// blocked request must not stop the reminder: an inexact alarm that wakes
  /// the device from doze still arrives within the hour.
  Future<AndroidScheduleMode> _scheduleMode() async {
    final bool exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Whether reminders can be posted right now, without asking.
  Future<ReminderAccess> access() async {
    if (kIsWeb) {
      return ReminderAccess.unsupported;
    }
    try {
      final PermissionStatus status = await Permission.notification.status;
      if (status.isGranted || status.isLimited || status.isProvisional) {
        return ReminderAccess.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return ReminderAccess.blocked;
      }
      return ReminderAccess.denied;
    } catch (error) {
      debugPrint('Notification permission check failed: $error');
      return ReminderAccess.unsupported;
    }
  }

  /// Shows the system permission dialog. Used right after onboarding, with a
  /// rationale of our own in front of it.
  Future<ReminderAccess> request() async {
    await init();
    try {
      final PermissionStatus status = await Permission.notification.request();
      if (status.isGranted || status.isLimited || status.isProvisional) {
        return ReminderAccess.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return ReminderAccess.blocked;
      }
      return ReminderAccess.denied;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return ReminderAccess.unsupported;
    }
  }

  /// Asks the system to let reminders fire at an exact minute instead of
  /// "sometime in the hour". Only offered from Settings, because it opens a
  /// second system screen.
  Future<bool> requestExactAlarms() async {
    await init();
    try {
      if (await _android?.canScheduleExactNotifications() ?? false) {
        return true;
      }
      final PermissionStatus status = await Permission.scheduleExactAlarm
          .request();
      return status.isGranted;
    } catch (error) {
      debugPrint('Exact alarm request failed: $error');
      return false;
    }
  }

  /// True when reminders can fire at the exact minute.
  Future<bool> hasExactAlarms() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (error) {
      return false;
    }
  }

  /// Opens this app's notification settings. The only way back from
  /// [ReminderAccess.blocked].
  Future<bool> openSystemSettings() async {
    try {
      return await openAppSettings();
    } catch (error) {
      debugPrint('Could not open app settings: $error');
      return false;
    }
  }

  /// Deck a cold start was launched for, if the app was opened from a
  /// reminder. Cleared once read so the navigation happens exactly once.
  String? takePendingDeck() {
    final String? deckId = _pendingDeckId;
    _pendingDeckId = null;
    return deckId;
  }

  void _handleResponse(NotificationResponse response) {
    final String? deckId = response.payload;
    if (deckId == null || deckId.isEmpty) {
      return;
    }
    final void Function(String)? handler = onOpenDeck;
    if (handler == null) {
      _pendingDeckId = deckId;
      return;
    }
    handler(deckId);
  }

  /// Arabic body copy. Plurals are spelled out because Arabic counts differ
  /// for one, two, a few and many.
  static String bodyFor(int dueCount, String? deckTitle) {
    final String deck = deckTitle == null || deckTitle.trim().isEmpty
        ? 'مجموعاتك'
        : '«${deckTitle.trim()}»';
    if (dueCount == 1) {
      return 'بطاقة واحدة تنتظرك في $deck';
    }
    if (dueCount == 2) {
      return 'بطاقتان تنتظرانك في $deck';
    }
    if (dueCount <= 10) {
      return '$dueCount بطاقات تنتظرك في $deck';
    }
    return '$dueCount بطاقة تنتظرك في $deck';
  }
}
