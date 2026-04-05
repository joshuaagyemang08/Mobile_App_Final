import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_settings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/time_utils.dart';
import 'dart:math';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

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
      securityQuestion: prefs.getString(AppConstants.keySecurityQuestion) ?? '',
      securityAnswer: prefs.getString(AppConstants.keySecurityAnswer) ?? '',
      securityQuestion2: prefs.getString(AppConstants.keySecurityQuestion2) ?? '',
      securityAnswer2: prefs.getString(AppConstants.keySecurityAnswer2) ?? '',
      lockScheduleEnabled: prefs.getBool(AppConstants.keyLockScheduleEnabled) ?? false,
      scheduleStartHour: prefs.getInt(AppConstants.keyScheduleStartHour) ?? 8,
      scheduleEndHour: prefs.getInt(AppConstants.keyScheduleEndHour) ?? 22,
      accelerometerEnabled: prefs.getBool(AppConstants.keyAccelerometerEnabled) ?? true,
      wakeHour: prefs.getInt(AppConstants.keyWakeHour) ?? 7,
      sleepHour: prefs.getInt(AppConstants.keySleepHour) ?? 23,
    );
  }

  Future<void> saveSettings(UserSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserName, s.userName);
    await prefs.setInt(AppConstants.keyDailyLimitMinutes, s.dailyLimitMinutes);
    await prefs.setInt(AppConstants.keyCooldownMinutes, s.cooldownMinutes);
    await prefs.setInt(AppConstants.keyExtraUnlockMinutes, s.extraUnlockMinutes);
    await prefs.setInt(AppConstants.keyMaxUnlocksPerDay, s.maxUnlocksPerDay);
    await prefs.setString(AppConstants.keyMonitoredApps, jsonEncode(s.monitoredApps));
    await prefs.setString(AppConstants.keySecurityQuestion, s.securityQuestion);
    await prefs.setString(AppConstants.keySecurityAnswer, s.securityAnswer.toLowerCase().trim());
    await prefs.setString(AppConstants.keySecurityQuestion2, s.securityQuestion2);
    await prefs.setString(AppConstants.keySecurityAnswer2, s.securityAnswer2.toLowerCase().trim());
    await prefs.setBool(AppConstants.keyLockScheduleEnabled, s.lockScheduleEnabled);
    await prefs.setInt(AppConstants.keyScheduleStartHour, s.scheduleStartHour);
    await prefs.setInt(AppConstants.keyScheduleEndHour, s.scheduleEndHour);
    await prefs.setBool(AppConstants.keyAccelerometerEnabled, s.accelerometerEnabled);
    await prefs.setInt(AppConstants.keyWakeHour, s.wakeHour);
    await prefs.setInt(AppConstants.keySleepHour, s.sleepHour);
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

  Future<bool> verifySecurityAnswer(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(AppConstants.keySecurityAnswer) ?? '';
    return stored == input.toLowerCase().trim();
  }

  Future<bool> verifySecurityAnswer2(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(AppConstants.keySecurityAnswer2) ?? '';
    return stored == input.toLowerCase().trim();
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
