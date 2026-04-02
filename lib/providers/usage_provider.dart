import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import '../data/services/settings_service.dart';
import '../data/services/database_service.dart';
import '../data/models/app_usage_model.dart';
import '../core/constants/social_apps.dart';
import '../core/utils/time_utils.dart';

class UsageProvider extends ChangeNotifier {
  final _settingsService = SettingsService();
  final _db = DatabaseService();

  int _totalMinutesToday = 0;
  int _limitMinutes = 60;
  bool _isLocked = false;
  bool _isCooldownExpired = false;
  DateTime? _cooldownEndTime;
  List<AppUsageEntry> _todayEntries = [];
  bool _isLoading = true;

  int get totalMinutesToday => _totalMinutesToday;
  int get limitMinutes => _limitMinutes;
  int get remainingMinutes => (_limitMinutes - _totalMinutesToday).clamp(0, _limitMinutes);
  double get usagePercent => (_totalMinutesToday / _limitMinutes).clamp(0.0, 1.0);
  bool get isLocked => _isLocked;
  bool get isCooldownExpired => _isCooldownExpired;
  DateTime? get cooldownEndTime => _cooldownEndTime;
  List<AppUsageEntry> get todayEntries => _todayEntries;
  bool get isLoading => _isLoading;

  Future<void> refresh(List<String> monitoredApps, int limitMinutes) async {
    _limitMinutes = limitMinutes;
    _isLocked = await _settingsService.isLocked();
    _cooldownEndTime = await _settingsService.getCooldownEndTime();
    _isCooldownExpired = await _settingsService.isCooldownExpired();

    // Pull from DB (already written by background service)
    _todayEntries = await _db.getUsageForDate(TimeUtils.todayKey());
    _totalMinutesToday = _todayEntries.fold(0, (s, e) => s + e.durationMinutes);

    // If DB empty (service not started yet), query directly
    if (_todayEntries.isEmpty && monitoredApps.isNotEmpty) {
      await _fetchDirect(monitoredApps);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchDirect(List<String> monitoredApps) async {
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
          entries.add(AppUsageEntry(
            date: TimeUtils.todayKey(),
            packageName: info.packageName,
            appName: socialApp?.displayName ?? info.appName,
            durationMinutes: minutes,
          ));
        }
      }
      _totalMinutesToday = total;
      _todayEntries = entries..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
    } catch (_) {}
  }

  Future<void> unlock() async {
    await _settingsService.setLocked(false);
    await _settingsService.incrementUnlockCount();
    _isLocked = false;
    _cooldownEndTime = null;
    _isCooldownExpired = false;
    notifyListeners();
  }

  Future<String?> getChallengeCode() => _settingsService.getChallengeCode();
  Future<bool> verifyChallengeCode(String input) => _settingsService.verifyChallengeCode(input);
  Future<int> getTodayUnlockCount() => _settingsService.getTodayUnlockCount();
  Future<int> getTodayPickupCount() => _settingsService.getTodayPickupCount();

  void updateFromBackground(int totalMinutes) {
    _totalMinutesToday = totalMinutes;
    notifyListeners();
  }

  void triggerLock() {
    _isLocked = true;
    notifyListeners();
  }
}
