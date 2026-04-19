import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../models/auth_result.dart';
import 'backend_api.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isLoggedIn() async {
    final token = await _secure.read(key: AppConstants.backendTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getUserEmail() => _secure.read(key: AppConstants.backendEmailKey);

  Future<String?> getToken() => _secure.read(key: AppConstants.backendTokenKey);

  Future<AuthResult> register({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    final response = await BackendApi.postJson('/api/auth_register.php', {
      'email': email,
      'password': password,
      'displayName': displayName,
    });

    return AuthResult.fromJson(response);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await BackendApi.postJson('/api/auth_login.php', {
      'email': email,
      'password': password,
    });

    final result = AuthResult.fromJson(response);
    if (result.success && result.token != null) {
      await _storeSession(
        token: result.token!,
        email: result.email ?? email.trim().toLowerCase(),
        displayName: result.settings?.userName,
      );
    }
    return result;
  }

  Future<AuthResult> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    final response = await BackendApi.postJson('/api/verify_otp.php', {
      'email': email,
      'code': code,
      'purpose': purpose,
    });

    final result = AuthResult.fromJson(response);
    if (result.success && result.token != null) {
      await _storeSession(
        token: result.token!,
        email: result.email ?? email.trim().toLowerCase(),
        displayName: result.settings?.userName,
      );
    }
    return result;
  }

  Future<AuthResult> requestVerificationOtp({required String email}) async {
    final response = await BackendApi.postJson('/api/request_verification_otp.php', {
      'email': email,
    });
    return AuthResult.fromJson(response);
  }

  Future<AuthResult> requestPinResetOtp() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return const AuthResult(success: false, message: 'You must be signed in to request a PIN reset code.');
    }

    final response = await BackendApi.postJson(
      '/api/request_pin_reset_otp.php',
      const {},
      token: token,
    );
    return AuthResult.fromJson(response);
  }

  Future<AuthResult> requestPasswordResetOtp({required String email}) async {
    final response = await BackendApi.postJson('/api/request_password_reset_otp.php', {
      'email': email,
    });
    return AuthResult.fromJson(response);
  }

  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await BackendApi.postJson('/api/reset_password.php', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
    return AuthResult.fromJson(response);
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await BackendApi.postJson('/api/logout.php', const {}, token: token);
      } catch (_) {
        // Ignore network errors during sign out; the local session is still cleared.
      }
    }
    await _clearSession();
  }

  Future<void> _storeSession({
    required String token,
    required String email,
    String? displayName,
  }) async {
    await _secure.write(key: AppConstants.backendTokenKey, value: token);
    await _secure.write(key: AppConstants.backendEmailKey, value: email);
    if (displayName != null && displayName.trim().isNotEmpty) {
      await _secure.write(key: AppConstants.backendDisplayNameKey, value: displayName.trim());
    }
  }

  Future<void> _clearSession() async {
    await _secure.delete(key: AppConstants.backendTokenKey);
    await _secure.delete(key: AppConstants.backendEmailKey);
    await _secure.delete(key: AppConstants.backendDisplayNameKey);
  }
}
