import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/pin_prompt_dialog.dart';
import '../../core/widgets/scene_background.dart';
import '../../core/widgets/focuslock_brand.dart';
import '../../providers/usage_provider.dart';
import '../../providers/settings_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _cooldownExpired = false;
  bool _codeRevealed = false;
  int _revealCountdown = 10;
  Timer? _revealTimer;
  String? _challengeCode;

  final _codeController = TextEditingController();
  String? _codeError;
  bool _isVerifying = false;
  bool _codeVerified = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initCooldown();
  }

  Future<void> _initCooldown() async {
    final endTime = await _getCooldownEnd();

    if (endTime == null || DateTime.now().isAfter(endTime)) {
      setState(() => _cooldownExpired = true);
      return;
    }

    setState(() {
      _secondsRemaining = endTime.difference(DateTime.now()).inSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        t.cancel();
        setState(() => _cooldownExpired = true);
      }
    });
  }

  Future<DateTime?> _getCooldownEnd() async {
    return context.read<UsageProvider>().cooldownEndTime;
  }

  Future<void> _revealCode() async {
    _challengeCode = await context.read<UsageProvider>().getChallengeCode();
    if (!mounted) return;
    setState(() {
      _codeRevealed = true;
      _revealCountdown = 10;
    });
    _revealTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _revealCountdown--);
      if (_revealCountdown <= 0) {
        t.cancel();
        setState(() {
          _codeRevealed = false;
          _challengeCode = null;
        });
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_codeVerified) return;

    if (_codeController.text.isEmpty) {
      setState(() => _codeError = 'Please enter the code');
      return;
    }
    setState(() { _isVerifying = true; _codeError = null; });

    final usage = context.read<UsageProvider>();

    final valid = await usage.verifyChallengeCode(_codeController.text.trim());
    if (!mounted) return;

    if (valid) {
      setState(() {
        _isVerifying = false;
        _codeVerified = true;
      });
    } else {
      setState(() {
        _isVerifying = false;
        _codeError = 'Incorrect code. Try again.';
        _codeController.clear();
      });
    }
  }

  Future<void> _useUnlockNow() async {
    final result = await showPinPrompt(
      context,
      title: 'Unlock Protected',
      subtitle: 'Enter your PIN before spending an unlock.',
    );
    if (!mounted) return;
    if (result == PinPromptResult.forgot) {
      Navigator.pushNamed(context, '/forgot-pin');
      return;
    }
    if (result != PinPromptResult.success) return;

    setState(() {
      _isVerifying = true;
      _codeError = null;
    });

    final usage = context.read<UsageProvider>();

    final unlocked = await usage.unlock();
    if (!mounted) return;
    if (!unlocked) {
      setState(() {
        _isVerifying = false;
        _codeError = usage.lastUnlockError ?? 'Unlock failed. Please try again.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _revealTimer?.cancel();
    _pulseController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final usage = context.watch<UsageProvider>();

    return SceneBackground(
      dark: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
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
                          Row(
                            children: [
                              const FocusLockMark(size: 36),
                              const SizedBox(width: 10),
                              Text(
                                'FocusLock',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Center(child: _buildLockIcon()),
                          const SizedBox(height: 18),
                          Text(
                            'FocusLock\nactivated',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontSize: 36,
                                  height: 1.08,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'You reached your daily social media limit of ${TimeUtils.formatMinutes(settings.dailyLimitMinutes)}.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF8990A8)),
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
                        boxShadow: const [
                          BoxShadow(color: AppTheme.shadow, blurRadius: 24, offset: Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_cooldownExpired) _buildCooldownSection() else _buildUnlockSection(usage, settings),
                          const SizedBox(height: 18),
                          _buildMotivationalFooter(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.danger, AppTheme.accent],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 2),
          boxShadow: [
            BoxShadow(color: AppTheme.danger.withOpacity(0.28), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: const Center(
            child: Icon(Icons.lock_rounded, size: 44, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCooldownSection() {
    return Column(
      children: [
        Text('Cooldown Period', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Text(
            TimeUtils.formatSeconds(_secondsRemaining),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppTheme.warning,
                  fontSize: 40,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'After the cooldown, you\'ll get a challenge code to enter for access.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildUnlockSection(UsageProvider usage, settings) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cooldown complete! Reveal your unlock code below.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!_codeRevealed)
          ElevatedButton.icon(
            onPressed: _revealCode,
            icon: const Icon(Icons.visibility),
            label: const Text('Reveal Unlock Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.black,
            ),
          )
        else
          Column(
            children: [
              Text(
                'Your code (disappears in ${_revealCountdown}s):',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.warning),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.warning, width: 2),
                ),
                child: Text(
                  _challengeCode ?? '------',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppTheme.warning,
                        letterSpacing: 12,
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        if (!_codeVerified) ...[
          Text(
            'Revealing and verifying code does not consume an unlock.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(letterSpacing: 8, fontSize: 22),
            decoration: InputDecoration(
              labelText: 'Enter code here',
              errorText: _codeError,
              counterText: '',
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isVerifying ? null : _verifyCode,
            child: _isVerifying
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Verify Code'),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Code verified. Tap "Use Unlock" only when you want to spend one unlock.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isVerifying ? null : _useUnlockNow,
            icon: _isVerifying
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open),
            label: Text(_isVerifying ? 'Processing...' : 'Use 1 Unlock (+${settings.extraUnlockMinutes}m)'),
          ),
          if (_codeError != null) ...[
            const SizedBox(height: 10),
            Text(
              _codeError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
            ),
          ],
        ],
        const SizedBox(height: 12),
        FutureBuilder<int>(
          future: usage.getTodayUnlockCount(),
          builder: (ctx, snap) {
            final used = snap.data ?? 0;
            final max = settings.maxUnlocksPerDay;
            final left = (max - used).clamp(0, max);
            return Text(
              'Unlocks used: $used / $max   •   Left: $left',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: used >= max ? AppTheme.danger : AppTheme.textMuted,
                  ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMotivationalFooter() {
    const quotes = [
      '"The real you is not on social media."',
      '"Discipline is freedom."',
      '"Attention is the new gold. Protect it."',
      '"Your focus is your superpower."',
    ];
    final q = quotes[DateTime.now().hour % quotes.length];
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(q,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMuted,
                )),
      ],
    );
  }
}
