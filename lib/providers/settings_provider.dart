import 'package:flutter/material.dart';
import '../data/models/user_settings.dart';
import '../data/services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final _service = SettingsService();

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

  Future<void> savePin(String pin) => _service.savePin(pin);
  Future<bool> verifyPin(String pin) => _service.verifyPin(pin);
  Future<bool> verifySecurityAnswer(String answer) => _service.verifySecurityAnswer(answer);
  Future<bool> verifySecurityAnswer2(String answer) => _service.verifySecurityAnswer2(answer);
}
