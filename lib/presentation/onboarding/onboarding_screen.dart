import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/social_apps.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_settings.dart';
import '../../data/services/settings_service.dart';
import '../../providers/settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 6;

  // Survey answers
  final _nameController = TextEditingController();
  int _wakeHour = 7;
  int _sleepHour = 23;
  final Set<String> _selectedApps = {};
  int _dailyLimitMinutes = 60;
  int _cooldownMinutes = 30;
  int _extraUnlockMinutes = 15;
  int _maxUnlocks = 1;
  int _selectedQuestion = 0;
  final _answerController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  bool _pinVisible = false;
  String? _pinError;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _answerController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  void _next() {
    if (!_validateCurrentPage()) return;
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return true;
      case 1:
        if (_nameController.text.trim().isEmpty) {
          _showError('Please enter your name.');
          return false;
        }
        return true;
      case 2:
        if (_selectedApps.isEmpty) {
          _showError('Please select at least one app to monitor.');
          return false;
        }
        return true;
      case 3:
        return true;
      case 4:
        if (_pinController.text.length < 4) {
          setState(() => _pinError = 'PIN must be at least 4 digits.');
          return false;
        }
        if (_pinController.text != _pinConfirmController.text) {
          setState(() => _pinError = 'PINs do not match.');
          return false;
        }
        if (_answerController.text.trim().isEmpty) {
          _showError('Please answer the security question.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    final settingsService = SettingsService();
    final settings = UserSettings(
      userName: _nameController.text.trim(),
      dailyLimitMinutes: _dailyLimitMinutes,
      cooldownMinutes: _cooldownMinutes,
      extraUnlockMinutes: _extraUnlockMinutes,
      maxUnlocksPerDay: _maxUnlocks,
      monitoredApps: _selectedApps.toList(),
      securityQuestion: AppConstants.securityQuestions[_selectedQuestion],
      securityAnswer: _answerController.text.trim().toLowerCase(),
      lockScheduleEnabled: false,
      scheduleStartHour: _wakeHour,
      scheduleEndHour: _sleepHour,
      accelerometerEnabled: true,
      wakeHour: _wakeHour,
      sleepHour: _sleepHour,
    );
    await settingsService.saveSettings(settings);
    await settingsService.savePin(_pinController.text);
    await settingsService.completeOnboarding();

    if (mounted) {
      await context.read<SettingsProvider>().load();
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildProfilePage(),
                  _buildAppsPage(),
                  _buildLimitsPage(),
                  _buildSecurityPage(),
                  _buildDonePage(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${_currentPage + 1} of $_totalPages',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('${((_currentPage + 1) / _totalPages * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _totalPages,
              backgroundColor: AppTheme.bgCardLight,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                child: const Text('Back'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _next,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentPage == _totalPages - 1 ? 'Get Started 🚀' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGES ────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    return _PageWrapper(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔒', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          Text('Welcome to\nFocusLock',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.primary,
                    height: 1.2,
                  )),
          const SizedBox(height: 16),
          Text(
            'Take back control of your time.\nWe\'ll help you set up smart limits\nthat actually work.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _featureChip('📊 Track all apps at once'),
          _featureChip('🔐 Smart challenge unlock'),
          _featureChip('🔔 Smart notifications'),
          _featureChip('📈 Usage history'),
        ],
      ),
    );
  }

  Widget _featureChip(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _buildProfilePage() {
    return _PageWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle('👋 Tell us about you'),
          const SizedBox(height: 8),
          Text('This helps personalise your experience.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Your name', prefixText: '  '),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 32),
          Text('What time do you usually wake up?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _timeSlider('Wake up', _wakeHour, 4, 12, (v) => setState(() => _wakeHour = v.round())),
          const SizedBox(height: 24),
          Text('What time do you usually sleep?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _timeSlider('Sleep', _sleepHour, 18, 26, (v) {
            setState(() => _sleepHour = v.round() > 23 ? v.round() - 24 : v.round());
          }),
        ],
      ),
    );
  }

  Widget _timeSlider(String label, int hour, double min, double max, ValueChanged<double> onChanged) {
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return Column(
      children: [
        Text('$displayHour:00 $period',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primary)),
        Slider(value: hour.toDouble().clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _buildAppsPage() {
    return _PageWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle('📱 Which apps should we monitor?'),
          const SizedBox(height: 8),
          Text('Select all your social media apps.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: SocialApps.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final app = SocialApps.all[i];
                final selected = _selectedApps.contains(app.packageName);
                return _AppTile(
                  app: app,
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedApps.remove(app.packageName);
                    } else {
                      _selectedApps.add(app.packageName);
                    }
                  }),
                );
              },
            ),
          ),
          if (_selectedApps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${_selectedApps.length} app(s) selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.success)),
            ),
        ],
      ),
    );
  }

  Widget _buildLimitsPage() {
    return _PageWrapper(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageTitle('⏱️ Set your limits'),
            const SizedBox(height: 8),
            Text('These can be changed anytime in Settings.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            _sectionLabel('Daily limit'),
            Text(
              _dailyLimitMinutes < 60
                  ? '$_dailyLimitMinutes minutes'
                  : '${_dailyLimitMinutes ~/ 60}h ${_dailyLimitMinutes % 60}m',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppTheme.primary),
            ),
            Slider(
                value: _dailyLimitMinutes.toDouble(),
                min: 15,
                max: 360,
                divisions: 23,
                onChanged: (v) => setState(() => _dailyLimitMinutes = v.round())),
            const SizedBox(height: 16),
            _sectionLabel('Cooldown before unlock'),
            Text('$_cooldownMinutes minutes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.accent)),
            Slider(
                value: _cooldownMinutes.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                onChanged: (v) => setState(() => _cooldownMinutes = v.round())),
            const SizedBox(height: 16),
            _sectionLabel('Extra time per unlock'),
            Text('$_extraUnlockMinutes minutes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.warning)),
            Slider(
                value: _extraUnlockMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                onChanged: (v) => setState(() => _extraUnlockMinutes = v.round())),
            const SizedBox(height: 16),
            _sectionLabel('Max unlocks per day'),
            Row(
              children: [
                IconButton(
                    onPressed: _maxUnlocks > 1 ? () => setState(() => _maxUnlocks--) : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$_maxUnlocks',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppTheme.primary)),
                IconButton(
                    onPressed: _maxUnlocks < 5 ? () => setState(() => _maxUnlocks++) : null,
                    icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPage() {
    return _PageWrapper(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageTitle('🔐 Set your PIN'),
            const SizedBox(height: 8),
            Text('Used to access Settings. If you forget it, your security question will help you recover it.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              obscureText: !_pinVisible,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: 'Create PIN (4-8 digits)',
                errorText: _pinError,
                suffixIcon: IconButton(
                  icon: Icon(_pinVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _pinVisible = !_pinVisible),
                ),
              ),
              onChanged: (_) => setState(() => _pinError = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinConfirmController,
              obscureText: !_pinVisible,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Security question (for PIN recovery)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedQuestion,
              dropdownColor: AppTheme.bgCard,
              decoration: const InputDecoration(labelText: 'Choose a question'),
              items: AppConstants.securityQuestions.asMap().entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (v) => setState(() => _selectedQuestion = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(labelText: 'Your answer'),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remember your answer exactly — it\'s case-insensitive but spelling matters.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonePage() {
    return _PageWrapper(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          Text("You're all set!",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppTheme.primary)),
          const SizedBox(height: 16),
          Text(
            'FocusLock will now monitor your social media usage and lock apps when you hit your limit.\n\nYou\'ve got this. 💪',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _summaryChip('🕐 Daily limit: ${_dailyLimitMinutes ~/ 60}h ${_dailyLimitMinutes % 60}m'),
          _summaryChip('🔒 Cooldown: $_cooldownMinutes min'),
          _summaryChip('📱 Monitoring: ${_selectedApps.length} apps'),
          _summaryChip('🔑 Max unlocks: $_maxUnlocks/day'),
        ],
      ),
    );
  }

  Widget _summaryChip(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );

  Widget _pageTitle(String text) => Text(text, style: Theme.of(context).textTheme.displayMedium);
  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: Theme.of(context).textTheme.bodySmall),
      );
}

// ── HELPERS ───────────────────────────────────────────────

class _PageWrapper extends StatelessWidget {
  final Widget child;
  const _PageWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: child,
    );
  }
}

class _AppTile extends StatelessWidget {
  final SocialApp app;
  final bool selected;
  final VoidCallback onTap;

  const _AppTile({required this.app, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.15) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(app.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(app.displayName, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 22)
            else
              const Icon(Icons.radio_button_unchecked, color: AppTheme.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
