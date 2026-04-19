import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/focuslock_brand.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _auth = AuthService();

  bool _sending = false;
  bool _verifying = false;
  bool _resetting = false;
  bool _otpVerified = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String? _extractOtpCode(String rawInput) {
    final raw = rawInput.trim();
    if (raw.isEmpty) {
      return null;
    }

    if (RegExp(r'^\d{4,8}$').hasMatch(raw)) {
      return raw;
    }

    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final fromQuery = uri.queryParameters['code'];
      if (fromQuery != null && RegExp(r'^\d{4,8}$').hasMatch(fromQuery.trim())) {
        return fromQuery.trim();
      }
    }

    final codeMatch = RegExp(r'\b\d{4,8}\b').firstMatch(raw);
    return codeMatch?.group(0);
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your account email first.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _info = null;
      _otpVerified = false;
    });

    final result = await _auth.requestPasswordResetOtp(email: email);
    if (!mounted) return;

    setState(() {
      _sending = false;
      if (result.success) {
        _info = result.message.isNotEmpty ? result.message : 'A reset code was sent to your email.';
      } else {
        _error = result.message.isNotEmpty ? result.message : 'Could not send reset code.';
      }
    });
  }

  Future<void> _verifyCode() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final code = _extractOtpCode(_otpCtrl.text);

    if (email.isEmpty) {
      setState(() => _error = 'Enter your account email first.');
      return;
    }
    if (code == null) {
      setState(() => _error = 'Enter the code from your email, or paste the full link.');
      return;
    }

    setState(() {
      _verifying = false;
      _otpVerified = true;
      _info = 'Code captured. Set your new password below and tap Reset Password.';
      _error = null;
    });
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final code = _extractOtpCode(_otpCtrl.text);

    if (!_otpVerified) {
      setState(() => _error = 'Verify your code first.');
      return;
    }
    if (email.isEmpty || code == null) {
      setState(() => _error = 'Email and code are required.');
      return;
    }
    if (_newPasswordCtrl.text.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters.');
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _resetting = true;
      _error = null;
      _info = null;
    });

    final result = await _auth.resetPasswordWithOtp(
      email: email,
      code: code,
      newPassword: _newPasswordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _resetting = false);

    if (!result.success) {
      setState(() => _error = result.message.isNotEmpty ? result.message : 'Could not reset password.');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset successful. You can now log in.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FocusLockMark(size: 36),
                        const SizedBox(width: 10),
                        Text(
                          'FocusLock',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: isDark ? Colors.white : AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F131D).withOpacity(0.94),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _otpVerified ? 'Set new\npassword' : 'Recover\npassword',
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                        color: Colors.white,
                                        fontSize: 36,
                                        height: 1.08,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _otpVerified
                                      ? 'Code verified. Choose a strong new password.'
                                      : 'Enter your email to receive a password reset code.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: const Color(0xFF8990A8)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Account email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _otpCtrl,
                                  keyboardType: TextInputType.text,
                                  autofillHints: const [AutofillHints.oneTimeCode],
                                  decoration: const InputDecoration(
                                    labelText: 'Reset code or link',
                                    hintText: 'e.g. 123456',
                                    prefixIcon: Icon(Icons.mark_email_read_outlined),
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFECEB),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _error!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                                    ),
                                  ),
                                ],
                                if (_info != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFFAF3),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _info!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.success),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _verifying ? null : _verifyCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF79A58D),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 54),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  ),
                                  child: _verifying
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Verify Reset Code'),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _sending ? null : _sendCode,
                                  child: _sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Send or resend code'),
                                ),
                                if (_otpVerified) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _newPasswordCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'New password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _confirmPasswordCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm password',
                                      prefixIcon: Icon(Icons.verified_user_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _resetting ? null : _resetPassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF79A58D),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 54),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                    ),
                                    child: _resetting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Reset Password'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
