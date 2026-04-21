import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../data/services/settings_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/database_service.dart';
import '../data/services/tracking_service.dart';
import '../data/models/app_usage_model.dart';
import '../data/models/user_settings.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/social_apps.dart';
import '../core/utils/time_utils.dart';

class UsageProvider extends ChangeNotifier {
  final _settingsService = SettingsService();
  final _db = DatabaseService();

  int _totalMinutesToday = 0;
  int _limitMinutes = 60;
  int _effectiveLimitMinutes = 60;
  int _todayPickupCount = 0;
  bool _isLocked = false;
  bool _isCooldownExpired = false;
  String? _lastUnlockError;
  DateTime? _cooldownEndTime;
  List<AppUsageEntry> _todayEntries = [];
  bool _isLoading = true;

  int get totalMinutesToday => _totalMinutesToday;
  int get limitMinutes => _effectiveLimitMinutes;
  int get remainingMinutes => (_effectiveLimitMinutes - _totalMinutesToday).clamp(0, _effectiveLimitMinutes);
  double get usagePercent => (_totalMinutesToday / (_effectiveLimitMinutes <= 0 ? 1 : _effectiveLimitMinutes)).clamp(0.0, 1.0);
  int get todayPickupCount => _todayPickupCount;
  bool get isLocked => _isLocked;
  bool get isCooldownExpired => _isCooldownExpired;
  String? get lastUnlockError => _lastUnlockError;
  DateTime? get cooldownEndTime => _cooldownEndTime;
  List<AppUsageEntry> get todayEntries => _todayEntries;
  bool get isLoading => _isLoading;

  bool _isWithinScheduleWindow(UserSettings settings, DateTime now) {
    if (!settings.lockScheduleEnabled) return false;
    final nowMinutes = (now.hour * 60) + now.minute;
    final startMinutes = (settings.scheduleStartHour * 60) + settings.scheduleStartMinute;
    final endMinutes = (settings.scheduleEndHour * 60) + settings.scheduleEndMinute;

    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  Future<void> _syncScheduledLock(UserSettings settings) async {
    final inScheduledWindow = _isWithinScheduleWindow(settings, DateTime.now());

    if (inScheduledWindow) {
      if (!_isLocked) {
        await _settingsService.setLocked(true, cooldownMinutes: settings.cooldownMinutes);
        _isLocked = true;
        _cooldownEndTime = await _settingsService.getCooldownEndTime();
        _isCooldownExpired = await _settingsService.isCooldownExpired();
      }
      return;
    }

    if (!_isLocked) return;

    final unlocksUsed = await _settingsService.getTodayUnlockCount();
    final effectiveLimit = settings.dailyLimitMinutes + (unlocksUsed * settings.extraUnlockMinutes);
    final shouldStayLocked = effectiveLimit > 0 && _totalMinutesToday >= effectiveLimit;

    if (!shouldStayLocked) {
      await _settingsService.setLocked(false);
      _isLocked = false;
      _cooldownEndTime = null;
      _isCooldownExpired = true;
    }
  }

  Future<void> refresh(List<String> monitoredApps, int limitMinutes) async {
    _limitMinutes = limitMinutes;
    await _settingsService.syncRemoteLockState();
    final settings = await _settingsService.loadSettings();

    if (AppConstants.enableTracking && !await FlutterForegroundTask.isRunningService) {
      await TrackingService().start();
    }

    if (!AppConstants.enableTracking) {
      _isLocked = await _settingsService.isLocked();
      _cooldownEndTime = await _settingsService.getCooldownEndTime();
      _isCooldownExpired = await _settingsService.isCooldownExpired();
      _todayEntries = _buildDesignEntries(monitoredApps);
      _totalMinutesToday = _todayEntries.fold(0, (s, e) => s + e.durationMinutes);
      _effectiveLimitMinutes = _limitMinutes;
      _todayPickupCount = await _settingsService.getTodayPickupCount();
      await _syncScheduledLock(settings);
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLocked = await _settingsService.isLocked();
    _cooldownEndTime = await _settingsService.getCooldownEndTime();
    _isCooldownExpired = await _settingsService.isCooldownExpired();

    // Pull from DB first so we always have something to show.
    _todayEntries = await _db.getUsageForDate(TimeUtils.todayKey());
    _totalMinutesToday = _todayEntries.fold(0, (s, e) => s + e.durationMinutes);
    _todayPickupCount = await _settingsService.getTodayPickupCount();

    // Always try a live pull so the UI stays current even if the foreground
    // service misses a cycle or restarts late.
    if (monitoredApps.isNotEmpty) {
      await _fetchDirect(monitoredApps);
    }

    await _refreshEffectiveLimit();
    final inScheduledWindow = _isWithinScheduleWindow(settings, DateTime.now());
    if (!inScheduledWindow) {
      await NotificationService().maybeShowUsageThresholdNotifications(
        totalMinutes: _totalMinutesToday,
        effectiveLimitMinutes: _effectiveLimitMinutes,
      );
    }
    await _syncScheduledLock(settings);
    await _applyLockIfLimitReached();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _fetchDirect(List<String> monitoredApps) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final usageList = await AppUsage().getAppUsage(start, now);
      int total = 0;
      final entries = <AppUsageEntry>[];
      for (final info in usageList) {
        if (monitoredApps.contains(info.packageName)) {
          final minutes = info.usage.inMinutes;
          total += minutes;
          final socialApp = SocialApps.fromPackage(info.packageName);
          final appName = socialApp?.displayName ?? info.appName;
          entries.add(AppUsageEntry(
            date: TimeUtils.todayKey(),
            packageName: info.packageName,
            appName: appName,
            durationMinutes: minutes,
          ));

          // Keep History in sync even when foreground direct polling is used.
          await _db.upsertUsage(info.packageName, appName, minutes);
        }
      }
      _totalMinutesToday = total;
      _todayEntries = entries..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
      return true;
    } catch (_) {}
    return false;
  }

  Future<bool> unlock() async {
    _lastUnlockError = null;
    final consumed = await _settingsService.useUnlock();
    if (!consumed) {
      _lastUnlockError = _settingsService.lastUnlockError ?? 'Unlock failed. Please try again.';
      notifyListeners();
      return false;
    }

    await _settingsService.setLocked(false);
    _isLocked = false;
    _cooldownEndTime = null;
    _isCooldownExpired = true;
    await _refreshEffectiveLimit();
    notifyListeners();
    return true;
  }

  Future<String?> getChallengeCode() => _settingsService.getChallengeCode();
  Future<bool> verifyChallengeCode(String input) => _settingsService.verifyChallengeCode(input);
  Future<int> getTodayUnlockCount() => _settingsService.getTodayUnlockCount();
  Future<int> getTodayPickupCount() => _settingsService.getTodayPickupCount();

  Future<void> updateFromBackground(int totalMinutes) async {
    if (!AppConstants.enableTracking) return;
    _totalMinutesToday = totalMinutes;
    _todayPickupCount = await _settingsService.getTodayPickupCount();
    await _refreshEffectiveLimit();
    final settings = await _settingsService.loadSettings();
    final inScheduledWindow = _isWithinScheduleWindow(settings, DateTime.now());
    if (!inScheduledWindow) {
      await NotificationService().maybeShowUsageThresholdNotifications(
        totalMinutes: _totalMinutesToday,
        effectiveLimitMinutes: _effectiveLimitMinutes,
      );
    }
    await _applyLockIfLimitReached();
    notifyListeners();
  }

  Future<void> refreshPickupCount() async {
    _todayPickupCount = await _settingsService.getTodayPickupCount();
    notifyListeners();
  }

  void triggerLock() {
    _isLocked = true;
    notifyListeners();
  }

  Future<void> _applyLockIfLimitReached() async {
    if (_isLocked || _effectiveLimitMinutes <= 0 || _totalMinutesToday < _effectiveLimitMinutes) {
      return;
    }

    final settings = await _settingsService.loadSettings();
    await _settingsService.setLocked(true, cooldownMinutes: settings.cooldownMinutes);
    _isLocked = true;
    _cooldownEndTime = await _settingsService.getCooldownEndTime();
    _isCooldownExpired = await _settingsService.isCooldownExpired();
  }

  Future<void> _refreshEffectiveLimit() async {
    final settings = await _settingsService.loadSettings();
    final usedUnlocks = await _settingsService.getTodayUnlockCount();
    _effectiveLimitMinutes = _limitMinutes + (usedUnlocks * settings.extraUnlockMinutes);
  }

  List<AppUsageEntry> _buildDesignEntries(List<String> monitoredApps) {
    final now = TimeUtils.todayKey();
    final seedPackages = monitoredApps.isNotEmpty
        ? monitoredApps
        : SocialApps.all.take(4).map((e) => e.packageName).toList();

    final designMinutes = <int>[40, 35, 17, 11, 9, 7];
    final entries = <AppUsageEntry>[];

    for (int i = 0; i < seedPackages.length && i < designMinutes.length; i++) {
      final pkg = seedPackages[i];
      final app = SocialApps.fromPackage(pkg);
      entries.add(
        AppUsageEntry(
          date: now,
          packageName: pkg,
          appName: app?.displayName ?? 'App ${i + 1}',
          durationMinutes: designMinutes[i],
        ),
      );
    }

    return entries;
  }
}
