import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/constants/app_constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
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
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showApproaching75(int remainingMinutes) async {
    await _show(
      id: AppConstants.notifIdApproaching75,
      title: '⚠️ Heads up, ${_fmt(remainingMinutes)} left',
      body: 'You\'re 75% through your daily social media limit.',
    );
  }

  Future<void> showApproaching90(int remainingMinutes) async {
    await _show(
      id: AppConstants.notifIdApproaching90,
      title: '🔴 Almost there! ${_fmt(remainingMinutes)} left',
      body: 'Your social media apps will be locked very soon.',
    );
  }

  Future<void> showLimitReached() async {
    await _show(
      id: AppConstants.notifIdLimitReached,
      title: '🔒 FocusLock activated',
      body: 'Daily limit reached. Social media is now locked. Stay focused!',
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
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
