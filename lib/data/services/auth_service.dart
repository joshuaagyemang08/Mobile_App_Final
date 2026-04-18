import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyUserEmail);
  }

  Future<bool> hasAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(AppConstants.keyUserEmail);
    final password = prefs.getString(AppConstants.keyUserPassword);
    return email != null && email.isNotEmpty && password != null && password.isNotEmpty;
  }

  Future<void> signUp({required String email, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserEmail, email.trim().toLowerCase());
    await prefs.setString(AppConstants.keyUserPassword, password);
    await prefs.setBool(AppConstants.keyIsLoggedIn, true);
  }

  Future<bool> login({required String email, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(AppConstants.keyUserEmail);
    final savedPassword = prefs.getString(AppConstants.keyUserPassword);
    final ok =
        savedEmail == email.trim().toLowerCase() && savedPassword == password;

    if (ok) {
      await prefs.setBool(AppConstants.keyIsLoggedIn, true);
    }

    return ok;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsLoggedIn, false);
  }
}
