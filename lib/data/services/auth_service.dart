import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/time_utils.dart';
import '../models/auth_result.dart';
import '../models/user_settings.dart';
import 'settings_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  Future<String?> getUserEmail() => _secure.read(key: AppConstants.backendEmailKey);

  Future<String?> getToken() => _secure.read(key: AppConstants.backendTokenKey);

  Future<AuthResult> register({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final previousEmail = await getUserEmail();

      final cred = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        return const AuthResult(success: false, message: 'Account creation failed. Please try again.');
      }

      if (displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
      }

      if (previousEmail != null && previousEmail.trim().toLowerCase() != normalizedEmail) {
        await SettingsService().clearLocalUserStateForAccountSwitch();
      }

      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        return const AuthResult(success: false, message: 'Could not start your session. Please try again.');
      }

      await _storeSession(
        token: token,
        email: normalizedEmail,
        displayName: user.displayName,
      );

      final defaults = UserSettings.defaults();
      await _firestore.collection('users').doc(user.uid).set({
        'email': normalizedEmail,
        'displayName': user.displayName ?? defaults.userName,
        'settings': defaults.toJson(),
        'lockState': {
          'todayUnlockCount': 0,
          'unlockDayKey': TimeUtils.todayKey(),
          'cooldownActive': false,
          'cooldownEndAt': null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      String verificationMessage = 'Verification email sent. Check your inbox before continuing.';
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        verificationMessage =
            'Account created, but verification email failed to send. [${e.code}] ${e.message ?? ''}'.trim();
      } catch (_) {
        verificationMessage = 'Account created, but verification email failed to send.';
      }

      await SettingsService().syncRemoteLockState();

      return AuthResult(
        success: true,
        message: verificationMessage,
        requiresOtp: true,
        email: normalizedEmail,
        token: token,
        settings: defaults,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthError(e));
    } catch (_) {
      return const AuthResult(success: false, message: 'Could not create account right now.');
    }
  }

  Future<AuthResult> login({required String email, required String password}) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final previousEmail = await getUserEmail();

      final cred = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        return const AuthResult(success: false, message: 'Sign in failed. Please try again.');
      }

      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        return const AuthResult(success: false, message: 'Could not start your session. Please try again.');
      }

      await user.reload();
      if (!user.emailVerified) {
        String verificationMessage = 'Please verify your email before signing in. We sent a new verification email.';
        try {
          await user.sendEmailVerification();
        } on FirebaseAuthException catch (e) {
          verificationMessage =
              'Please verify your email before signing in. Could not send verification email. [${e.code}] ${e.message ?? ''}'.trim();
        } catch (_) {
          verificationMessage =
              'Please verify your email before signing in. Could not send verification email.';
        }

        return AuthResult(
          success: false,
          requiresOtp: true,
          message: verificationMessage,
          email: normalizedEmail,
        );
      }

      if (previousEmail != null && previousEmail.trim().toLowerCase() != normalizedEmail) {
        await SettingsService().clearLocalUserStateForAccountSwitch();
      }

      await _storeSession(
        token: token,
        email: normalizedEmail,
        displayName: user.displayName,
      );

      final settings = await SettingsService().loadSettings();
      await SettingsService().syncRemoteLockState();

      return AuthResult(
        success: true,
        message: 'Welcome back.',
        email: normalizedEmail,
        token: token,
        settings: settings,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthError(e));
    } catch (_) {
      return const AuthResult(success: false, message: 'Unable to sign in right now.');
    }
  }

  Future<AuthResult> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    if (purpose == 'pin_reset') {
      if (code.trim().isEmpty) {
        return const AuthResult(success: false, message: 'Enter your recovery code.');
      }
      return const AuthResult(success: true, message: 'Code accepted.');
    }

    return const AuthResult(
      success: false,
      message: 'Email OTP verification is no longer used. Please sign in directly.',
    );
  }

  Future<AuthResult> requestVerificationOtp({required String email}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult(success: false, message: 'Sign in first so we can send a verification email.');
    }

    final currentEmail = user.email?.trim().toLowerCase();
    if (currentEmail == null || currentEmail.isEmpty) {
      return const AuthResult(success: false, message: 'No email address is attached to this account.');
    }

    if (currentEmail != email.trim().toLowerCase()) {
      return const AuthResult(success: false, message: 'That email does not match the signed-in account.');
    }

    try {
      await user.sendEmailVerification();
      return const AuthResult(
        success: true,
        message: 'Verification email sent. Check your inbox and tap the link.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: 'Could not send verification email. [${e.code}] ${e.message ?? ''}'.trim(),
      );
    } catch (_) {
      return const AuthResult(success: false, message: 'Could not send verification email.');
    }
  }

  Future<AuthResult> requestPinResetOtp() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult(success: false, message: 'You must be signed in to request a PIN reset code.');
    }
    return const AuthResult(
      success: true,
      message: 'PIN reset is available in-app after code verification on this device.',
    );
  }

  Future<AuthResult> reauthenticateForPinReset({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    if (user == null || email == null || email.isEmpty) {
      return const AuthResult(success: false, message: 'Session expired. Please sign in again.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return const AuthResult(success: true, message: 'Identity verified. You can set a new PIN now.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthError(e));
    } catch (_) {
      return const AuthResult(success: false, message: 'Could not verify your identity.');
    }
  }

  Future<AuthResult> requestPasswordResetOtp({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return const AuthResult(
        success: true,
        message: 'Password reset email sent. Use the email link to finish resetting your password.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mapAuthError(e));
    } catch (_) {
      return const AuthResult(success: false, message: 'Could not send password reset email.');
    }
  }

  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return const AuthResult(
      success: false,
      message: 'For Firebase, reset your password from the email link we sent.',
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
    // Clear device-local user state on logout so next user doesn't see cached settings
    await SettingsService().clearLocalUserStateForAccountSwitch();
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

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Use a stronger password (at least 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong credentials. Check email/password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
