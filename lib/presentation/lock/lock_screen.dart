import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
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
    final usage = context.read<UsageProvider>();
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
    if (_codeController.text.isEmpty) {
      setState(() => _codeError = 'Please enter the code');
      return;
    }
    setState(() { _isVerifying = true; _codeError = null; });

    final usage = context.read<UsageProvider>();
    final settings = context.read<SettingsProvider>().settings;

    // Check if max unlocks exceeded
    final unlockCount = await usage.getTodayUnlockCount();
    if (unlockCount >= settings.maxUnlocksPerDay) {
      setState(() {
        _isVerifying = false;
        _codeError = 'You\'ve used all your unlocks for today (${settings.maxUnlocksPerDay} max).';
      });
      return;
    }

    final valid = await usage.verifyChallengeCode(_codeController.text.trim());
    if (!mounted) return;

    if (valid) {
      await usage.unlock();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _isVerifying = false;
        _codeError = 'Incorrect code. Try again.';
        _codeController.clear();
      });
    }
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

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              _buildLockIcon(),
              const SizedBox(height: 24),
              Text(
                '🔒 FocusLock Activated',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.danger,
                      fontSize: 22,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ve reached your daily social media limit of ${TimeUtils.formatMinutes(settings.dailyLimitMinutes)}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (!_cooldownExpired) _buildCooldownSection() else _buildUnlockSection(usage, settings),
              const Spacer(),
              _buildMotivationalFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.danger.withOpacity(0.4), width: 2),
        ),
        child: const Center(
          child: Text('🔒', style: TextStyle(fontSize: 48)),
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
            borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(12),
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
              : const Text('Unlock'),
        ),
        const SizedBox(height: 12),
        FutureBuilder<int>(
          future: usage.getTodayUnlockCount(),
          builder: (ctx, snap) {
            final used = snap.data ?? 0;
            final max = settings.maxUnlocksPerDay;
            return Text(
              'Unlocks used today: $used / $max',
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
