import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focuslock_brand.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/settings_service.dart';

class VerifyEmailOtpScreen extends StatefulWidget {
  final String email;
  final String purpose;
  final bool autoSend;

  const VerifyEmailOtpScreen({
    super.key,
    required this.email,
    this.purpose = 'signup',
    this.autoSend = true,
  });

  @override
  State<VerifyEmailOtpScreen> createState() => _VerifyEmailOtpScreenState();
}

class _VerifyEmailOtpScreenState extends State<VerifyEmailOtpScreen> {
  static const _permissionsChannel = MethodChannel('com.focuslock.app/permissions');
  final _codeCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _sending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    if (!widget.autoSend) {
      _info = 'A verification code was sent during account creation.';
    }
    if (widget.autoSend) {
      _sendCode();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<bool> _hasBlockingPermissions() async {
    try {
      final usage = await _permissionsChannel.invokeMethod<bool>('checkUsageStatsPermission') ?? false;
      final overlay = await _permissionsChannel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      final accessibility = await _permissionsChannel.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
      return usage && overlay && accessibility;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });

    final result = await _auth.requestVerificationOtp(email: widget.email);

    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.success) {
        _info = result.message.isNotEmpty ? result.message : 'Verification code sent.';
        _error = null;
      } else {
        _error = result.message.isNotEmpty ? result.message : 'Could not send verification code.';
        _info = null;
      }
    });
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
    if (codeMatch != null) {
      return codeMatch.group(0);
    }

    return null;
  }

  Future<void> _verify() async {
    final code = _extractOtpCode(_codeCtrl.text);
    if (code == null) {
      setState(() => _error = 'Enter your code, or paste the verification link and try again.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _auth.verifyOtp(
      email: widget.email,
      code: code,
      purpose: widget.purpose,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.message.isNotEmpty ? result.message : 'Verification failed.');
      return;
    }

    final onboarded = await SettingsService().isOnboarded();
    if (!mounted) return;

    if (AppConstants.enableTracking && !(await _hasBlockingPermissions())) {
      Navigator.pushNamedAndRemoveUntil(context, '/permissions', (route) => false);
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, onboarded ? '/home' : '/onboarding', (route) => false);
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
                                  'Verify your\nemail',
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                        color: Colors.white,
                                        fontSize: 36,
                                        height: 1.08,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'A one-time code was sent to ${widget.email}. Paste the code or full verification link below.',
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
                                Text(
                                  'Enter verification code',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This confirms your account before you continue.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _codeCtrl,
                                  keyboardType: TextInputType.text,
                                  autofillHints: const [AutofillHints.oneTimeCode],
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _verify(),
                                  decoration: const InputDecoration(
                                    labelText: 'Verification code or link',
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
                                  onPressed: _loading ? null : _verify,
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
                                      : const Text('Verify Email'),
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
                                      : const Text('Did not get it? Resend code'),
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
