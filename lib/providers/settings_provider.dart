import 'package:flutter/material.dart';
import '../data/models/user_settings.dart';
import '../data/services/settings_service.dart';

class SettingsUpdateResult {
  final bool applied;
  final String? message;

  const SettingsUpdateResult({required this.applied, this.message});
}

class GuardrailStatus {
  final int focusIncreaseDaysLeft;
  final DateTime? focusIncreaseNextAllowedAt;
  final int monitoredReductionDaysLeft;
  final DateTime? monitoredReductionNextAllowedAt;

  const GuardrailStatus({
    required this.focusIncreaseDaysLeft,
    required this.focusIncreaseNextAllowedAt,
    required this.monitoredReductionDaysLeft,
    required this.monitoredReductionNextAllowedAt,
  });
}

class SettingsProvider extends ChangeNotifier {
  final _service = SettingsService();
  static const int _guardrailDays = 30;

  UserSettings _settings = UserSettings.defaults();
  bool _isLoading = true;

  UserSettings get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _settings = await _service.loadSettings();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> update(UserSettings updated) async {
    await _service.saveSettings(updated);
    _settings = updated;
    notifyListeners();
  }

  Future<GuardrailStatus> getGuardrailStatus() async {
    final now = DateTime.now();

    final lastFocusIncrease = await _service.getLastFocusIncreaseDate();
    int focusLeft = 0;
    DateTime? focusNext;
    if (lastFocusIncrease != null) {
      final daysSince = now.difference(lastFocusIncrease).inDays;
      if (daysSince < _guardrailDays) {
        focusLeft = _guardrailDays - daysSince;
        focusNext = lastFocusIncrease.add(const Duration(days: _guardrailDays));
      }
    }

    final lastMonitoredReduction = await _service.getLastMonitoredReductionDate();
    int monitoredLeft = 0;
    DateTime? monitoredNext;
    if (lastMonitoredReduction != null) {
      final daysSince = now.difference(lastMonitoredReduction).inDays;
      if (daysSince < _guardrailDays) {
        monitoredLeft = _guardrailDays - daysSince;
        monitoredNext = lastMonitoredReduction.add(const Duration(days: _guardrailDays));
      }
    }

    return GuardrailStatus(
      focusIncreaseDaysLeft: focusLeft,
      focusIncreaseNextAllowedAt: focusNext,
      monitoredReductionDaysLeft: monitoredLeft,
      monitoredReductionNextAllowedAt: monitoredNext,
    );
  }

  Future<SettingsUpdateResult> updateWithGuardrails(UserSettings updated) async {
    final current = _settings;

    final isFocusIncrease = updated.dailyLimitMinutes > current.dailyLimitMinutes ||
        updated.cooldownMinutes > current.cooldownMinutes ||
        updated.extraUnlockMinutes > current.extraUnlockMinutes ||
        updated.maxUnlocksPerDay > current.maxUnlocksPerDay;

    if (isFocusIncrease) {
      final lastUsed = await _service.getLastFocusIncreaseDate();
      if (lastUsed != null) {
        final daysSince = DateTime.now().difference(lastUsed).inDays;
        if (daysSince < _guardrailDays) {
          final left = _guardrailDays - daysSince;
          return SettingsUpdateResult(
            applied: false,
            message: 'Focus Lock increases are allowed once every $_guardrailDays days. Try again in $left day${left == 1 ? '' : 's'}.',
          );
        }
      }
    }

    final isMonitoredReduction = updated.monitoredApps.length < current.monitoredApps.length;
    if (isMonitoredReduction) {
      final lastUsed = await _service.getLastMonitoredReductionDate();
      if (lastUsed != null) {
        final daysSince = DateTime.now().difference(lastUsed).inDays;
        if (daysSince < _guardrailDays) {
          final left = _guardrailDays - daysSince;
          return SettingsUpdateResult(
            applied: false,
            message: 'Reducing monitored apps is allowed once every $_guardrailDays days. Try again in $left day${left == 1 ? '' : 's'}.',
          );
        }
      }
    }

    await _service.saveSettings(updated);
    _settings = updated;
    notifyListeners();

    if (isFocusIncrease) {
      await _service.markFocusIncreaseUsedNow();
    }
    if (isMonitoredReduction) {
      await _service.markMonitoredReductionUsedNow();
    }

    String? info;
    if (isFocusIncrease && isMonitoredReduction) {
      info = 'Focus Lock increase and monitored-app reduction saved. Both 30-day guardrails are now active.';
    } else if (isFocusIncrease) {
      info = 'Focus Lock increase saved. You can increase Focus Lock values again after 30 days.';
    } else if (isMonitoredReduction) {
      info = 'Monitored-app reduction saved. You can reduce monitored apps again after 30 days.';
    }

    return SettingsUpdateResult(applied: true, message: info);
  }

  Future<void> savePin(String pin) => _service.savePin(pin);
  Future<bool> verifyPin(String pin) => _service.verifyPin(pin);
}
