import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focuslock_brand.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/settings_service.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _passwordCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  String? _email;
  String? _error;
  String? _info;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final email = await _auth.getUserEmail();
    if (!mounted) return;

    setState(() => _email = email);
    if (email == null || email.isEmpty) {
      setState(() => _error = 'You need to sign in again before resetting your PIN.');
    } else {
      setState(() {
        _info =
            'For Firebase security, enter your account password to verify your identity, then set a new PIN.';
      });
    }
  }

  Future<void> _setNewPin() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      setState(() => _error = 'Missing signed-in email. Please sign in again.');
      return;
    }

    if (_passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Enter your account password to continue.');
      return;
    }

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

    final verify = await _auth.reauthenticateForPinReset(password: _passwordCtrl.text);
    if (!verify.success) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = verify.message.isNotEmpty ? verify.message : 'Could not verify your identity.';
      });
      return;
    }

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
                                  'Recover your\nPIN',
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                        color: Colors.white,
                                        fontSize: 36,
                                        height: 1.08,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'For Firebase security, confirm your account password, then set a new 6-digit PIN.',
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
                                if (_email != null) ...[
                                  Text('Recovery email', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(_email!, style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(height: 12),
                                ],
                                if (_error != null) ...[
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
                                  const SizedBox(height: 10),
                                ],
                                if (_info != null) ...[
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
                                  const SizedBox(height: 12),
                                ],
                                TextField(
                                  controller: _passwordCtrl,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Account password',
                                    prefixIcon: Icon(Icons.password_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _newPinCtrl,
                                  obscureText: true,
                                  keyboardType: TextInputType.number,
                                  maxLength: AppConstants.pinLength,
                                  decoration: const InputDecoration(
                                    labelText: 'New PIN (6 digits)',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _confirmCtrl,
                                  obscureText: true,
                                  keyboardType: TextInputType.number,
                                  maxLength: AppConstants.pinLength,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm new PIN',
                                    prefixIcon: Icon(Icons.verified_user_outlined),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loading ? null : _setNewPin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF79A58D),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 54),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Verify Account & Set New PIN'),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                  child: const Text('Forgot account password? Reset it first'),
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
