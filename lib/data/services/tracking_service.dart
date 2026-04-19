import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'settings_service.dart';
import 'notification_service.dart';
import 'database_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/time_utils.dart';

// ── TASK HANDLER (runs in a background isolate) ───────────

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}

class TrackingTaskHandler extends TaskHandler {
  final _settings = SettingsService();
  final _notif = NotificationService();
  final _db = DatabaseService();

  bool _sent75 = false;
  bool _sent90 = false;

  bool _isWithinScheduleWindow({
    required DateTime now,
    required int startHour,
    required int endHour,
  }) {
    final hour = now.hour;
    if (startHour == endHour) return true;
    if (startHour < endHour) {
      return hour >= startHour && hour < endHour;
    }
    return hour >= startHour || hour < endHour;
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _notif.init();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();

    // Reset lock and notification flags once per calendar day.
    final today = TimeUtils.todayKey();
    final lastResetDate = prefs.getString(AppConstants.keyLastDailyResetDate);
    if (lastResetDate != today) {
      _sent75 = false;
      _sent90 = false;
      await _settings.setLocked(false);
      await prefs.setString(AppConstants.keyLastDailyResetDate, today);
    }

    final lockScheduleEnabled = prefs.getBool(AppConstants.keyLockScheduleEnabled) ?? false;
    final scheduleStartHour = prefs.getInt(AppConstants.keyScheduleStartHour) ?? 8;
    final scheduleEndHour = prefs.getInt(AppConstants.keyScheduleEndHour) ?? 22;
    final inScheduledWindow = lockScheduleEnabled &&
        _isWithinScheduleWindow(
          now: DateTime.now(),
          startHour: scheduleStartHour,
          endHour: scheduleEndHour,
        );

    var isLocked = await _settings.isLocked();
    if (inScheduledWindow) {
      if (!isLocked) {
        final cooldownMinutes = prefs.getInt(AppConstants.keyCooldownMinutes) ?? AppConstants.defaultCooldownMinutes;
        await _settings.setLocked(true, cooldownMinutes: cooldownMinutes);
        FlutterForegroundTask.sendDataToMain({'action': 'lock'});
      }
      return;
    }

    // Get usage stats for today
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    List<AppUsageInfo> usageList = [];
    try {
      usageList = await AppUsage().getAppUsage(startOfDay, now);
    } catch (_) {
      return; // Usage stats permission not granted yet
    }

    final appsJson = prefs.getString(AppConstants.keyMonitoredApps);
    if (appsJson == null) {
      if (isLocked) {
        await _settings.setLocked(false);
        FlutterForegroundTask.sendDataToMain({'action': 'update', 'totalMinutes': 0});
      }
      return;
    }
    final monitoredApps = List<String>.from(jsonDecode(appsJson));
    if (monitoredApps.isEmpty) {
      if (isLocked) {
        await _settings.setLocked(false);
        FlutterForegroundTask.sendDataToMain({'action': 'update', 'totalMinutes': 0});
      }
      return;
    }

    // Calculate cumulative usage across all monitored apps
    int totalMinutes = 0;
    for (final info in usageList) {
      if (monitoredApps.contains(info.packageName)) {
        final minutes = info.usage.inMinutes;
        totalMinutes += minutes;
        // Persist to DB
        await _db.upsertUsage(info.packageName, info.appName, minutes);
      }
    }

    final limitMinutes = prefs.getInt(AppConstants.keyDailyLimitMinutes) ?? AppConstants.defaultDailyLimitMinutes;
    final extraUnlockMinutes = prefs.getInt(AppConstants.keyExtraUnlockMinutes) ?? AppConstants.defaultExtraUnlockMinutes;
    final unlocksUsed = await _settings.getTodayUnlockCount();
    final effectiveLimitMinutes = limitMinutes + (unlocksUsed * extraUnlockMinutes);
    final remaining = effectiveLimitMinutes - totalMinutes;
    final percentUsed = totalMinutes / (effectiveLimitMinutes <= 0 ? 1 : effectiveLimitMinutes);

    // Send notifications at thresholds
    if (percentUsed >= 0.75 && !_sent75 && percentUsed < 0.90) {
      await _notif.showApproaching75(remaining);
      _sent75 = true;
    }
    if (percentUsed >= 0.90 && !_sent90 && percentUsed < 1.0) {
      await _notif.showApproaching90(remaining);
      _sent90 = true;
    }

    // Trigger lock
    if (totalMinutes >= effectiveLimitMinutes) {
      final cooldownMinutes = prefs.getInt(AppConstants.keyCooldownMinutes) ?? AppConstants.defaultCooldownMinutes;
      await _settings.setLocked(true, cooldownMinutes: cooldownMinutes);
      await _notif.showLimitReached();
      FlutterForegroundTask.sendDataToMain({'action': 'lock'});
    } else {
      if (isLocked) {
        await _settings.setLocked(false);
        isLocked = false;
      }
      // Push usage updates back to the UI isolate.
      FlutterForegroundTask.sendDataToMain({
        'action': 'update',
        'totalMinutes': totalMinutes,
      });
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationDismissed() {}
}

// ── SERVICE MANAGER ────────────────────────────────────────

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  void _configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'focuslock_fg',
        channelName: 'FocusLock Monitor',
        channelDescription: 'Monitors your social media usage in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.repeat(AppConstants.checkIntervalSeconds * 1000),
      ),
    );
  }

  Future<void> start() async {
    _configure();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'FocusLock is active',
      notificationText: 'Monitoring your social media usage.',
      notificationIcon: null,
      callback: startCallback,
    );
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
