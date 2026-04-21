import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/time_utils.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _tzReady = false;
  static const _keyLastSleepScheduledAt = 'notif_last_sleep_scheduled_at';
  static const _keyLast75AlertDate = 'notif_last_75_alert_date';
  static const _keyLast90AlertDate = 'notif_last_90_alert_date';
  static const _keyLastLimitAlertDate = 'notif_last_limit_alert_date';
  static const _keyLastCooldownCompleteAlertEndTime = 'notif_last_cooldown_complete_end_time';
  static const _alertsChannelId = 'focuslock_alerts_v4';
  static const _bannerNotificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _alertsChannelId,
      'FocusLock Alerts',
      channelDescription: 'Usage limit, sleep reminders, and lock alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      ticker: 'FocusLock alert',
      icon: '@mipmap/ic_launcher',
    ),
  );

  Future<void> init() async {
    if (!_tzReady) {
      tz.initializeTimeZones();
      try {
        final currentTimeZone = await FlutterTimezone.getLocalTimezone();
        if (currentTimeZone.identifier.isNotEmpty) {
          tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
        }
      } catch (_) {
        // Fall back to the timezone package default if the native bridge is unavailable.
      }
      _tzReady = true;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      _alertsChannelId,
      'FocusLock Alerts',
      description: 'Usage limit, sleep reminders, and lock alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Some Android versions or OEM implementations may not expose exact alarm requests.
    }
  }

  Future<void> showApproaching75(int remainingMinutes) async {
    if (!await _automatedNotificationsEnabled()) return;
    await _show(
      id: AppConstants.notifIdApproaching75,
      title: 'Heads up, ${_fmt(remainingMinutes)} left',
      body: 'You\'re 75% through your daily social media limit.',
    );
  }

  Future<void> showApproaching90(int remainingMinutes) async {
    if (!await _automatedNotificationsEnabled()) return;
    await _show(
      id: AppConstants.notifIdApproaching90,
      title: 'Almost there! ${_fmt(remainingMinutes)} left',
      body: 'Your social media apps will be locked very soon.',
    );
  }

  Future<void> showLimitReached() async {
    if (!await _automatedNotificationsEnabled()) return;
    await _show(
      id: AppConstants.notifIdLimitReached,
      title: 'FocusLock activated',
      body: 'Daily limit reached. Social media is now locked. Stay focused!',
    );
  }

  Future<void> showCooldownComplete() async {
    if (!await _automatedNotificationsEnabled()) return;
    await _show(
      id: AppConstants.notifIdCooldownComplete,
      title: 'Cooldown complete',
      body: 'Your cooldown has ended. Open FocusLock to reveal your unlock code.',
    );
  }

  Future<void> showUnlockUsed() async {
    if (!await _automatedNotificationsEnabled()) return;
    await _show(
      id: AppConstants.notifIdUnlockUsed,
      title: 'Unlock used',
      body: 'One unlock was consumed for today.',
    );
  }

  Future<void> maybeShowCooldownComplete({required DateTime? cooldownEndTime}) async {
    if (!await _automatedNotificationsEnabled()) return;
    if (cooldownEndTime == null) return;
    if (!DateTime.now().isAfter(cooldownEndTime)) return;

    final prefs = await SharedPreferences.getInstance();
    final marker = cooldownEndTime.toIso8601String();
    if (prefs.getString(_keyLastCooldownCompleteAlertEndTime) == marker) return;

    await showCooldownComplete();
    await prefs.setString(_keyLastCooldownCompleteAlertEndTime, marker);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> showPreviewNotification({required String title, required String body}) async {
    await _show(id: 7777, title: title, body: body);
  }

  Future<void> scheduleSleepReminder({
    required int sleepHour,
    required int sleepMinute,
  }) async {
    if (!await _automatedNotificationsEnabled()) {
      await _plugin.cancel(8102);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastSleepScheduledAt);
      return;
    }

    await _plugin.cancel(8102);

    final sleepReminder = _nextSleepReminderInstance(
      hour: sleepHour,
      minute: sleepMinute,
    );

    await _scheduleDaily(
      8102,
      'Sleep reminder',
      'You have 1 minute to sleep. Time to put your phone away.',
      sleepReminder,
      _bannerNotificationDetails,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSleepScheduledAt, sleepReminder.toLocal().toIso8601String());
  }

  Future<void> sendTestSleepReminderNow() async {
    await _plugin.show(
      8202,
      'Sleep reminder (test)',
      'This is a test sleep reminder notification.',
      _bannerNotificationDetails,
    );
  }

  Future<Map<String, String>> getNotificationDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationPermission = await Permission.notification.status;
    final pending = await _plugin.pendingNotificationRequests();

    final hasSleep = pending.any((n) => n.id == 8102);
    final sleepAt = prefs.getString(_keyLastSleepScheduledAt) ?? 'Unknown';
    final notificationsEnabled = prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true;

    return {
      'permission': notificationPermission.toString(),
      'appNotificationsEnabled': notificationsEnabled ? 'Yes' : 'No',
      'pendingCount': pending.length.toString(),
      'localTimezone': tz.local.name,
      'sleepScheduled': hasSleep ? 'Yes' : 'No',
      'sleepAt': sleepAt,
    };
  }

  Future<void> maybeShowUsageThresholdNotifications({
    required int totalMinutes,
    required int effectiveLimitMinutes,
  }) async {
    if (!await _automatedNotificationsEnabled()) return;
    if (effectiveLimitMinutes <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final today = TimeUtils.todayKey();
    final remaining = effectiveLimitMinutes - totalMinutes;
    final percentUsed = totalMinutes / effectiveLimitMinutes;

    if (totalMinutes >= effectiveLimitMinutes) {
      if (prefs.getString(_keyLastLimitAlertDate) != today) {
        await showLimitReached();
        await prefs.setString(_keyLastLimitAlertDate, today);
      }
      return;
    }

    if (percentUsed >= 0.90) {
      if (prefs.getString(_keyLast90AlertDate) != today) {
        await showApproaching90(remaining);
        await prefs.setString(_keyLast90AlertDate, today);
      }
      return;
    }

    if (percentUsed >= 0.75) {
      if (prefs.getString(_keyLast75AlertDate) != today) {
        await showApproaching75(remaining);
        await prefs.setString(_keyLast75AlertDate, today);
      }
    }
  }

  Future<void> _scheduleDaily(
    int id,
    String title,
    String body,
    tz.TZDateTime at,
    NotificationDetails details,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  tz.TZDateTime _nextInstance({required int hour, required int minute}) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  tz.TZDateTime _nextSleepReminderInstance({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var sleepTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!sleepTime.isAfter(now)) {
      sleepTime = sleepTime.add(const Duration(days: 1));
    }

    final earlyReminder = sleepTime.subtract(const Duration(minutes: 1));
    if (earlyReminder.isAfter(now)) {
      return earlyReminder;
    }

    return sleepTime;
  }

  Future<void> _show({required int id, required String title, required String body}) async {
    try {
      await _plugin.show(
        id,
        title,
        body,
        _bannerNotificationDetails,
      );
      print('[NotificationService] Sent notification: $title');
    } catch (e) {
      print('[NotificationService] Error showing notification: $e');
    }
  }

  Future<bool> _automatedNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true;
  }

  String _fmt(int minutes) {
    if (minutes <= 0) return 'no time';
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}
