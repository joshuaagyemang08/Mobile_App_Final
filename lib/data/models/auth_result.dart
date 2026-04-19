import 'user_settings.dart';

class AuthResult {
  final bool success;
  final String message;
  final bool requiresOtp;
  final String? email;
  final String? token;
  final UserSettings? settings;

  const AuthResult({
    required this.success,
    required this.message,
    this.requiresOtp = false,
    this.email,
    this.token,
    this.settings,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      requiresOtp: json['requiresOtp'] == true,
      email: json['email']?.toString(),
      token: json['token']?.toString(),
      settings: json['settings'] is Map<String, dynamic>
          ? UserSettings.fromJson(Map<String, dynamic>.from(json['settings'] as Map))
          : null,
    );
  }
}
