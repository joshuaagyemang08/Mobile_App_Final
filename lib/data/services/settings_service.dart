import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/time_utils.dart';
import '../models/user_settings.dart';
import 'backend_api.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> _token() => _secure.read(key: AppConstants.backendTokenKey);

  // ── ONBOARDING ──────────────────────────────────────────

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsOnboarded) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsOnboarded, true);
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

  Future<void> saveSettings(UserSettings s) async {
    await _cacheSettings(s);

    final token = await _token();
    if (token != null && token.isNotEmpty) {
      try {
        await BackendApi.postJson(
          '/api/settings_save.php',
          s.toJson(),
          token: token,
        );
      } catch (_) {
        // Keep the local cache as the source of truth if the network is unavailable.
      }
    }
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

      final settingsJson = response['settings'];
      if (settingsJson is Map<String, dynamic>) {
        final settings = UserSettings.fromJson(Map<String, dynamic>.from(settingsJson));
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
      scheduleEndHour: prefs.getInt(AppConstants.keyScheduleEndHour) ?? 22,
      accelerometerEnabled: prefs.getBool(AppConstants.keyAccelerometerEnabled) ?? true,
      wakeHour: prefs.getInt(AppConstants.keyWakeHour) ?? 7,
      sleepHour: prefs.getInt(AppConstants.keySleepHour) ?? 23,
    );
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
    await prefs.setInt(AppConstants.keyScheduleEndHour, s.scheduleEndHour);
    await prefs.setBool(AppConstants.keyAccelerometerEnabled, s.accelerometerEnabled);
    await prefs.setInt(AppConstants.keyWakeHour, s.wakeHour);
    await prefs.setInt(AppConstants.keySleepHour, s.sleepHour);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsLocked, locked);
    if (locked && cooldownMinutes != null) {
      final endTime = DateTime.now().add(Duration(minutes: cooldownMinutes));
      await prefs.setString(AppConstants.keyCooldownEndTime, endTime.toIso8601String());
      // Generate and store challenge code
      final code = _generateChallengeCode();
      await _secure.write(key: AppConstants.keyChallengeCode, value: code);
    }
    if (!locked) {
      await prefs.remove(AppConstants.keyCooldownEndTime);
      await _secure.delete(key: AppConstants.keyChallengeCode);
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
    final prefs = await SharedPreferences.getInstance();
    final count = await getTodayUnlockCount();
    await prefs.setInt(AppConstants.keyTodayUnlockCount, count + 1);
    await prefs.setString(AppConstants.keyLastUnlockDate, TimeUtils.todayKey());
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
