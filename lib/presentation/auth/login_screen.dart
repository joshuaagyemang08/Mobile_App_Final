import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/focuslock_brand.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/settings_service.dart';
import 'verify_email_otp_screen.dart';

enum AuthTab { login, register }

class LoginScreen extends StatefulWidget {
  final AuthTab initialTab;

  const LoginScreen({super.key, this.initialTab = AuthTab.login});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  bool _rememberMe = true;
  bool _showPassword = false;
  late AuthTab _tab;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Enter email and password.');
      return;
    }

    if (_tab == AuthTab.register) {
      if (_passwordCtrl.text.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters.');
        return;
      }
      if (_passwordCtrl.text != _confirmCtrl.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    bool ok = false;
    String? emailForOtp = _emailCtrl.text.trim().toLowerCase();
    if (_tab == AuthTab.login) {
      final result = await _auth.login(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (result.requiresOtp) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailOtpScreen(email: emailForOtp),
          ),
        );
        return;
      }

      ok = result.success;

      if (!ok) {
        setState(() => _error = result.message.isNotEmpty ? result.message : 'Wrong credentials. Check email/password.');
        return;
      }
    } else {
      final result = await _auth.register(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (!result.success) {
        setState(() => _error = result.message.isNotEmpty ? result.message : 'Could not create account.');
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailOtpScreen(email: emailForOtp, autoSend: false),
        ),
      );
      return;
    }

    final onboarded = await SettingsService().isOnboarded();
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, onboarded ? '/home' : '/onboarding');
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
                                  _tab == AuthTab.login
                                      ? 'Welcome back to\nFocusLock'
                                      : 'Create your\nFocusLock account',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 36,
                                        height: 1.08,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _tab == AuthTab.login
                                      ? 'Pick up where you left off and keep your screen time intentional.'
                                      : 'Set up your account to start shaping better focus habits.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: const Color(0xFF8990A8)),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B1F2B),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _authTabButton(
                                          title: 'Login',
                                          selected: _tab == AuthTab.login,
                                          onTap: () => setState(() {
                                            _tab = AuthTab.login;
                                            _error = null;
                                          }),
                                        ),
                                      ),
                                      Expanded(
                                        child: _authTabButton(
                                          title: 'Register',
                                          selected: _tab == AuthTab.register,
                                          onTap: () => setState(() {
                                            _tab = AuthTab.register;
                                            _error = null;
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
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
                              children: [
                                TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _passwordCtrl,
                                  obscureText: !_showPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _showPassword = !_showPassword),
                                      icon: Icon(
                                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_tab == AuthTab.register) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _confirmCtrl,
                                    obscureText: !_showPassword,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm Password',
                                      prefixIcon: Icon(Icons.verified_user_outlined),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                    ),
                                    const Text('Remember me'),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Forgot Password?'),
                                    ),
                                  ],
                                ),
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(color: AppTheme.danger),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  onPressed: _loading ? null : _submit,
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
                                      : Text(_tab == AuthTab.login ? 'Login' : 'Create Account'),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        'Or login with',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                                  label: const Text('Google'),
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

  Widget _authTabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? AppTheme.textPrimary : const Color(0xFF9CA3B6),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
