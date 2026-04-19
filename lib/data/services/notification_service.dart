import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _tzReady = false;

  Future<void> init() async {
    if (!_tzReady) {
      tz.initializeTimeZones();
      _tzReady = true;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      'focuslock_channel',
      'FocusLock Alerts',
      description: 'Usage limit and lock notifications',
      importance: Importance.high,
      playSound: true,
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
    await _show(
      id: AppConstants.notifIdApproaching75,
      title: 'Heads up, ${_fmt(remainingMinutes)} left',
      body: 'You\'re 75% through your daily social media limit.',
    );
  }

  Future<void> showApproaching90(int remainingMinutes) async {
    await _show(
      id: AppConstants.notifIdApproaching90,
      title: 'Almost there! ${_fmt(remainingMinutes)} left',
      body: 'Your social media apps will be locked very soon.',
    );
  }

  Future<void> showLimitReached() async {
    await _show(
      id: AppConstants.notifIdLimitReached,
      title: 'FocusLock activated',
      body: 'Daily limit reached. Social media is now locked. Stay focused!',
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> showPreviewNotification({required String title, required String body}) async {
    await _show(id: 7777, title: title, body: body);
  }

  Future<void> scheduleWakeSleepReminders({required int wakeHour, required int sleepHour}) async {
    await _plugin.cancel(8101);
    await _plugin.cancel(8102);

    final wake = _nextInstance(hour: wakeHour);
    final sleep = _nextInstance(hour: sleepHour);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'focuslock_channel',
        'FocusLock Alerts',
        channelDescription: 'Usage limit and lock notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _scheduleDaily(
      8101,
      'Good morning',
      'Start your day with intention, not endless scrolling.',
      wake,
      details,
    );

    await _scheduleDaily(
      8102,
      'Wind down reminder',
      'Your sleep window is near. Time to unplug.',
      sleep,
      details,
    );
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

  tz.TZDateTime _nextInstance({required int hour}) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  Future<void> _show({required int id, required String title, required String body}) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'focuslock_channel',
          'FocusLock Alerts',
          channelDescription: 'Usage limit and lock notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  String _fmt(int minutes) {
    if (minutes <= 0) return 'no time';
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}
