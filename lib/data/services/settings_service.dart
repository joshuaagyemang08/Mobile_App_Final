import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/time_utils.dart';
import '../models/user_settings.dart';
import 'backend_api.dart';
import 'database_service.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  String? _lastUnlockError;

  String? get lastUnlockError => _lastUnlockError;

  Future<String?> _token() => _secure.read(key: AppConstants.backendTokenKey);

  Future<void> clearLocalUserStateForAccountSwitch() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(AppConstants.keyIsOnboarded);
    await prefs.remove(AppConstants.keyDailyLimitMinutes);
    await prefs.remove(AppConstants.keyCooldownMinutes);
    await prefs.remove(AppConstants.keyExtraUnlockMinutes);
    await prefs.remove(AppConstants.keyMaxUnlocksPerDay);
    await prefs.remove(AppConstants.keyMonitoredApps);
    await prefs.remove(AppConstants.keyLockScheduleEnabled);
    await prefs.remove(AppConstants.keyScheduleStartHour);
    await prefs.remove(AppConstants.keyScheduleStartMinute);
    await prefs.remove(AppConstants.keyScheduleEndHour);
    await prefs.remove(AppConstants.keyScheduleEndMinute);
    await prefs.remove(AppConstants.keyAccelerometerEnabled);
    await prefs.remove(AppConstants.keyWakeHour);
    await prefs.remove(AppConstants.keyWakeMinute);
    await prefs.remove(AppConstants.keySleepHour);
    await prefs.remove(AppConstants.keySleepMinute);
    await prefs.remove(AppConstants.keyNotificationsEnabled);
    await prefs.remove(AppConstants.keyTodayUnlockCount);
    await prefs.remove(AppConstants.keyLastUnlockDate);
    await prefs.remove(AppConstants.keyLastDailyResetDate);
    await prefs.remove(AppConstants.keyIsLocked);
    await prefs.remove(AppConstants.keyCooldownEndTime);
    await prefs.remove(AppConstants.keyPickupCount);
    await prefs.remove(AppConstants.keyLastPickupDate);
    await prefs.remove(AppConstants.keyUserName);
    await prefs.remove(AppConstants.keyLastFocusIncreaseDate);
    await prefs.remove(AppConstants.keyLastMonitoredReductionDate);

    await _secure.delete(key: AppConstants.keyChallengeCode);
    await _secure.delete(key: AppConstants.securePin);

    await DatabaseService().clearUsageHistory();
  }

  // ── ONBOARDING ──────────────────────────────────────────

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsOnboarded) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsOnboarded, true);
  }

  Future<bool> inferRemoteOnboardingComplete() async {
    final remote = await _loadRemoteSettings();
    if (remote == null) {
      return false;
    }
    return looksLikeOnboardedProfile(remote);
  }

  static bool looksLikeOnboardedProfile(UserSettings settings) {
    final hasName = settings.userName.trim().isNotEmpty;
    final hasSelectedApps = settings.monitoredApps.isNotEmpty;
    return hasName || hasSelectedApps;
  }

  // ── SETTINGS LOAD / SAVE ────────────────────────────────

  Future<UserSettings> loadSettings() async {
    final remote = await _loadRemoteSettings();
    if (remote != null) {
      await _cacheSettings(remote);
      return remote;
    }

    return _loadCachedSettings();
  }

  Future<bool> saveSettings(UserSettings s) async {
    await _cacheSettings(s);

    final token = await _token();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await BackendApi.postJson(
        '/api/settings_save.php',
        s.toJson(),
        token: token,
      );
      await _cacheLockStateFromResponse(response);
      return response['success'] == true;
    } catch (_) {
      // Keep the local cache as the source of truth if the network is unavailable.
      return false;
    }

    return false;
  }

  Future<UserSettings?> _loadRemoteSettings() async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await BackendApi.getJson('/api/settings_get.php', token: token);
      if (response['success'] != true) {
        return null;
      }

      await _cacheLockStateFromResponse(response);

      final settingsJson = response['settings'];
      if (settingsJson is Map<String, dynamic>) {
        final settingsMap = Map<String, dynamic>.from(settingsJson);
        final settings = await _applyLocalFallbackFromCache(UserSettings.fromJson(settingsMap));
        final user = response['user'];
        if (user is Map<String, dynamic> && (user['displayName'] ?? '').toString().trim().isNotEmpty) {
          return settings.copyWith(userName: user['displayName'].toString());
        }
        return settings;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<UserSettings> _applyLocalFallbackFromCache(UserSettings remote) async {
    final prefs = await SharedPreferences.getInstance();

    final cachedScheduleStartMinute = prefs.containsKey(AppConstants.keyScheduleStartMinute)
      ? prefs.getInt(AppConstants.keyScheduleStartMinute)
      : null;
    final cachedScheduleEndMinute = prefs.containsKey(AppConstants.keyScheduleEndMinute)
      ? prefs.getInt(AppConstants.keyScheduleEndMinute)
      : null;
    final cachedWakeMinute = prefs.containsKey(AppConstants.keyWakeMinute)
      ? prefs.getInt(AppConstants.keyWakeMinute)
      : null;
    final cachedSleepMinute = prefs.containsKey(AppConstants.keySleepMinute)
      ? prefs.getInt(AppConstants.keySleepMinute)
      : null;
    final cachedNotificationsEnabled = prefs.containsKey(AppConstants.keyNotificationsEnabled)
      ? prefs.getBool(AppConstants.keyNotificationsEnabled)
      : null;

    return remote.copyWith(
      scheduleStartMinute: cachedScheduleStartMinute ?? remote.scheduleStartMinute,
      scheduleEndMinute: cachedScheduleEndMinute ?? remote.scheduleEndMinute,
      wakeMinute: cachedWakeMinute ?? remote.wakeMinute,
      sleepMinute: cachedSleepMinute ?? remote.sleepMinute,
      notificationsEnabled: cachedNotificationsEnabled ?? remote.notificationsEnabled,
    );
  }

  Future<UserSettings> _loadCachedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final appsJson = prefs.getString(AppConstants.keyMonitoredApps);
    final apps = appsJson != null ? List<String>.from(jsonDecode(appsJson)) : <String>[];

    return UserSettings(
      userName: prefs.getString(AppConstants.keyUserName) ?? '',
      dailyLimitMinutes: prefs.getInt(AppConstants.keyDailyLimitMinutes) ?? AppConstants.defaultDailyLimitMinutes,
      cooldownMinutes: prefs.getInt(AppConstants.keyCooldownMinutes) ?? AppConstants.defaultCooldownMinutes,
      extraUnlockMinutes: prefs.getInt(AppConstants.keyExtraUnlockMinutes) ?? AppConstants.defaultExtraUnlockMinutes,
      maxUnlocksPerDay: prefs.getInt(AppConstants.keyMaxUnlocksPerDay) ?? AppConstants.defaultMaxUnlocksPerDay,
      monitoredApps: apps,
      lockScheduleEnabled: prefs.getBool(AppConstants.keyLockScheduleEnabled) ?? false,
      scheduleStartHour: prefs.getInt(AppConstants.keyScheduleStartHour) ?? 8,
      scheduleStartMinute: prefs.getInt(AppConstants.keyScheduleStartMinute) ?? 0,
      scheduleEndHour: prefs.getInt(AppConstants.keyScheduleEndHour) ?? 22,
      scheduleEndMinute: prefs.getInt(AppConstants.keyScheduleEndMinute) ?? 0,
      accelerometerEnabled: prefs.getBool(AppConstants.keyAccelerometerEnabled) ?? true,
      wakeHour: prefs.getInt(AppConstants.keyWakeHour) ?? 7,
      wakeMinute: prefs.getInt(AppConstants.keyWakeMinute) ?? 0,
      sleepHour: prefs.getInt(AppConstants.keySleepHour) ?? 23,
      sleepMinute: prefs.getInt(AppConstants.keySleepMinute) ?? 0,
      notificationsEnabled: prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true,
    );
  }

  Future<void> syncRemoteLockState() async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final response = await BackendApi.getJson('/api/lock_state_get.php', token: token);
      await _cacheLockStateFromResponse(response);
    } catch (_) {
      // Keep local state when network is unavailable.
    }
  }

  Future<bool> useUnlock() async {
    _lastUnlockError = null;
    final token = await _token();
    if (token == null || token.isEmpty) {
      _lastUnlockError = 'Session missing. Please sign in again.';
      return false;
    }

    await syncRemoteLockState();

    try {
      final response = await BackendApi.postJson('/api/use_unlock.php', const {}, token: token);
      if (response['success'] == true) {
        await _setLockedLocal(false);
        await _cacheLockStateFromResponse(response);
        return true;
      }
      await _cacheLockStateFromResponse(response);
      final message = (response['message'] ?? '').toString().trim();
      _lastUnlockError = message.isNotEmpty
          ? message
          : 'Unlock failed. Please try again.';
      return false;
    } catch (e) {
      if (e is TimeoutException) {
        _lastUnlockError = 'Request timed out. Please check internet and try again.';
        return false;
      }
      _lastUnlockError = 'Network error while consuming unlock. Please try again.';
      return false;
    }
  }

  Future<void> _cacheSettings(UserSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserName, s.userName);
    await prefs.setInt(AppConstants.keyDailyLimitMinutes, s.dailyLimitMinutes);
    await prefs.setInt(AppConstants.keyCooldownMinutes, s.cooldownMinutes);
    await prefs.setInt(AppConstants.keyExtraUnlockMinutes, s.extraUnlockMinutes);
    await prefs.setInt(AppConstants.keyMaxUnlocksPerDay, s.maxUnlocksPerDay);
    await prefs.setString(AppConstants.keyMonitoredApps, jsonEncode(s.monitoredApps));
    await prefs.setBool(AppConstants.keyLockScheduleEnabled, s.lockScheduleEnabled);
    await prefs.setInt(AppConstants.keyScheduleStartHour, s.scheduleStartHour);
    await prefs.setInt(AppConstants.keyScheduleStartMinute, s.scheduleStartMinute);
    await prefs.setInt(AppConstants.keyScheduleEndHour, s.scheduleEndHour);
    await prefs.setInt(AppConstants.keyScheduleEndMinute, s.scheduleEndMinute);
    await prefs.setBool(AppConstants.keyAccelerometerEnabled, s.accelerometerEnabled);
    await prefs.setInt(AppConstants.keyWakeHour, s.wakeHour);
    await prefs.setInt(AppConstants.keyWakeMinute, s.wakeMinute);
    await prefs.setInt(AppConstants.keySleepHour, s.sleepHour);
    await prefs.setInt(AppConstants.keySleepMinute, s.sleepMinute);
    await prefs.setBool(AppConstants.keyNotificationsEnabled, s.notificationsEnabled);
  }

  // ── BEHAVIOUR GUARDRAILS ───────────────────────────────

  Future<DateTime?> getLastFocusIncreaseDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyLastFocusIncreaseDate);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<DateTime?> getLastMonitoredReductionDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyLastMonitoredReductionDate);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markFocusIncreaseUsedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLastFocusIncreaseDate, DateTime.now().toIso8601String());
  }

  Future<void> markMonitoredReductionUsedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLastMonitoredReductionDate, DateTime.now().toIso8601String());
  }

  // ── PIN (secure storage) ────────────────────────────────

  Future<void> savePin(String pin) async {
    final isValidPin = pin.length == AppConstants.pinLength && RegExp(r'^\d+$').hasMatch(pin);
    if (!isValidPin) {
      throw ArgumentError('PIN must be exactly ${AppConstants.pinLength} digits.');
    }
    await _secure.write(key: AppConstants.securePin, value: pin);
  }

  Future<String?> getPin() async {
    return _secure.read(key: AppConstants.securePin);
  }

  Future<bool> verifyPin(String input) async {
    final isValidPin = input.length == AppConstants.pinLength && RegExp(r'^\d+$').hasMatch(input);
    if (!isValidPin) {
      return false;
    }
    final stored = await getPin();
    return stored != null && stored == input;
  }

  // ── LOCK STATE ──────────────────────────────────────────

  Future<void> setLocked(bool locked, {int? cooldownMinutes}) async {
    await _setLockedLocal(locked, cooldownMinutes: cooldownMinutes, preserveExistingCooldown: true);
    await _syncRemoteLockStateOnLockChange(locked);
  }

  Future<void> _setLockedLocal(
    bool locked, {
    int? cooldownMinutes,
    bool preserveExistingCooldown = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsLocked, locked);

    if (locked && cooldownMinutes != null) {
      final existingRaw = prefs.getString(AppConstants.keyCooldownEndTime);
      final existingEnd = existingRaw != null ? DateTime.tryParse(existingRaw) : null;
      final now = DateTime.now();

      if (!preserveExistingCooldown || existingEnd == null || !existingEnd.isAfter(now)) {
        final endTime = now.add(Duration(minutes: cooldownMinutes));
        await prefs.setString(AppConstants.keyCooldownEndTime, endTime.toIso8601String());
      }

      // Generate and store challenge code
      final code = _generateChallengeCode();
      await _secure.write(key: AppConstants.keyChallengeCode, value: code);
    }
    if (!locked) {
      await prefs.remove(AppConstants.keyCooldownEndTime);
      await _secure.delete(key: AppConstants.keyChallengeCode);
    }
  }

  Future<void> _syncRemoteLockStateOnLockChange(bool locked) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final response = await BackendApi.postJson(
        '/api/lock_state_set.php',
        {'locked': locked},
        token: token,
      );
      await _cacheLockStateFromResponse(response);
    } catch (_) {
      // Keep local lock state when network is unavailable.
    }
  }

  Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsLocked) ?? false;
  }

  Future<DateTime?> getCooldownEndTime() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(AppConstants.keyCooldownEndTime);
    return s != null ? DateTime.tryParse(s) : null;
  }

  Future<bool> isCooldownExpired() async {
    final end = await getCooldownEndTime();
    if (end == null) return true;
    return DateTime.now().isAfter(end);
  }

  Future<String?> getChallengeCode() async {
    return _secure.read(key: AppConstants.keyChallengeCode);
  }

  Future<bool> verifyChallengeCode(String input) async {
    final code = await getChallengeCode();
    return code != null && code == input.trim();
  }

  String _generateChallengeCode() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  // ── UNLOCK COUNT (reset daily) ──────────────────────────

  Future<int> getTodayUnlockCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(AppConstants.keyLastUnlockDate) ?? '';
    if (!TimeUtils.isToday(lastDate)) {
      await prefs.setInt(AppConstants.keyTodayUnlockCount, 0);
      await prefs.setString(AppConstants.keyLastUnlockDate, TimeUtils.todayKey());
      return 0;
    }
    return prefs.getInt(AppConstants.keyTodayUnlockCount) ?? 0;
  }

  Future<void> incrementUnlockCount() async {
    final usedRemote = await useUnlock();
    if (usedRemote) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final count = await getTodayUnlockCount();
    await prefs.setInt(AppConstants.keyTodayUnlockCount, count + 1);
    await prefs.setString(AppConstants.keyLastUnlockDate, TimeUtils.todayKey());
  }

  Future<void> _cacheLockStateFromResponse(Map<String, dynamic> response) async {
    final lockState = response['lockState'];
    if (lockState is Map<String, dynamic>) {
      await _cacheLockState(lockState);
      return;
    }
    if (lockState is Map) {
      await _cacheLockState(Map<String, dynamic>.from(lockState));
    }
  }

  Future<void> _cacheLockState(Map<String, dynamic> lockState) async {
    final prefs = await SharedPreferences.getInstance();

    final unlockCount = lockState['todayUnlockCount'];
    if (unlockCount != null) {
      await prefs.setInt(AppConstants.keyTodayUnlockCount, unlockCount is int ? unlockCount : int.tryParse(unlockCount.toString()) ?? 0);
    }

    final unlockDayKey = (lockState['unlockDayKey'] ?? '').toString().trim();
    if (unlockDayKey.isNotEmpty) {
      await prefs.setString(AppConstants.keyLastUnlockDate, unlockDayKey);
    }

    final cooldownEndAt = lockState['cooldownEndAt'];
    if (cooldownEndAt == null || cooldownEndAt.toString().trim().isEmpty) {
      await prefs.remove(AppConstants.keyCooldownEndTime);
    } else {
      await prefs.setString(AppConstants.keyCooldownEndTime, cooldownEndAt.toString());
    }

    final cooldownActive = lockState['cooldownActive'] == true;
    if (cooldownActive) {
      await prefs.setBool(AppConstants.keyIsLocked, true);
    }
  }

  // ── PICKUP COUNT ────────────────────────────────────────

  Future<void> recordPickup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(AppConstants.keyLastPickupDate) ?? '';
    int count = TimeUtils.isToday(lastDate) ? (prefs.getInt(AppConstants.keyPickupCount) ?? 0) : 0;
    await prefs.setInt(AppConstants.keyPickupCount, count + 1);
    await prefs.setString(AppConstants.keyLastPickupDate, TimeUtils.todayKey());
  }

  Future<int> getTodayPickupCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(AppConstants.keyLastPickupDate) ?? '';
    if (!TimeUtils.isToday(lastDate)) return 0;
    return prefs.getInt(AppConstants.keyPickupCount) ?? 0;
  }
}
