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
  final _auth = AuthService();

  bool _sending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
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
    });

    final result = await _auth.requestPasswordResetOtp(email: email);
    if (!mounted) return;

    setState(() {
      _sending = false;
      if (result.success) {
        _info = result.message.isNotEmpty
            ? result.message
            : 'Password reset email sent. Open the link in your inbox to finish.';
      } else {
        _error = result.message.isNotEmpty ? result.message : 'Could not send password reset email.';
      }
    });
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
                                  'Recover\npassword',
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                        color: Colors.white,
                                        fontSize: 36,
                                        height: 1.08,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Enter your email and we will send a secure password reset link.',
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
                                  onPressed: _sending ? null : _sendCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF79A58D),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 54),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  ),
                                  child: _sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Send Password Reset Email'),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Back to Login'),
                                ),
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
