import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/settings_service.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _otpCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  String? _email;
  String? _error;
  String? _info;
  bool _loading = false;
  bool _sending = false;
  bool _step2 = false;

  @override
  void initState() {
    super.initState();
    _loadContextAndSendCode();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContextAndSendCode() async {
    final email = await _auth.getUserEmail();
    if (!mounted) return;

    setState(() => _email = email);
    if (email == null || email.isEmpty) {
      setState(() => _error = 'You need to sign in again before resetting your PIN.');
      return;
    }

    await _sendCode();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });

    final result = await _auth.requestPinResetOtp();
    if (!mounted) return;

    setState(() {
      _sending = false;
      _info = result.message.isNotEmpty ? result.message : 'A PIN reset code has been sent to your email.';
      if (!result.success) {
        _error = result.message.isNotEmpty ? result.message : 'Could not send a PIN reset code.';
      }
    });
  }

  Future<void> _verifyCode() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      setState(() => _error = 'Missing signed-in email.');
      return;
    }

    if (_otpCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter the code sent to your email.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _auth.verifyOtp(
      email: email,
      code: _otpCtrl.text.trim(),
      purpose: 'pin_reset',
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.message.isNotEmpty ? result.message : 'Incorrect code.');
      return;
    }

    setState(() => _step2 = true);
  }

  Future<void> _setNewPin() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_newPinCtrl.text)) {
      setState(() => _error = 'PIN must be exactly ${AppConstants.pinLength} digits.');
      return;
    }
    if (_newPinCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    await SettingsService().savePin(_newPinCtrl.text);
    if (!mounted) return;

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN reset successfully!'), backgroundColor: AppTheme.success),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Recover PIN')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.75)),
                  boxShadow: const [
                    BoxShadow(color: AppTheme.shadow, blurRadius: 24, offset: Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppTheme.warning, AppTheme.accent]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.key_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PIN Recovery', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                _step2
                                    ? 'Code verified. Set your new PIN below.'
                                    : 'Enter the one-time code sent to your email to reset your PIN.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_email != null) ...[
                      Text('Recovery email', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_email!, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.danger.withOpacity(0.25)),
                        ),
                        child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.danger)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_info != null) ...[
                      Text(_info!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                    ],
                    if (!_step2) ...[
                      TextField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Email OTP',
                          hintText: 'Enter the code you received',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _sending ? null : _sendCode,
                            child: _sending
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Resend code'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _loading ? null : _verifyCode,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Verify code'),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: _newPinCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: AppConstants.pinLength,
                        decoration: const InputDecoration(labelText: 'New PIN (6 digits)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: AppConstants.pinLength,
                        decoration: const InputDecoration(labelText: 'Confirm new PIN (6 digits)'),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _setNewPin,
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Set New PIN'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
