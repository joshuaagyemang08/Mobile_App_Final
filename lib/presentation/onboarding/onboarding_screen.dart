import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/social_apps.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focuslock_brand.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/models/user_settings.dart';
import '../../data/services/notification_service.dart';
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
  int _selectedQuestion2 = 1;
  final _answerController = TextEditingController();
  final _answerController2 = TextEditingController();
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
    _answerController2.dispose();
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
        if (!RegExp(r'^\d{6}$').hasMatch(_pinController.text)) {
          setState(() => _pinError = 'PIN must be exactly ${AppConstants.pinLength} digits.');
          return false;
        }
        if (_pinController.text != _pinConfirmController.text) {
          setState(() => _pinError = 'PINs do not match.');
          return false;
        }
        if (_answerController.text.trim().isEmpty) {
          _showError('Please answer the first security question.');
          return false;
        }
        if (_selectedQuestion2 == _selectedQuestion) {
          _showError('Please choose two different security questions.');
          return false;
        }
        if (_answerController2.text.trim().isEmpty) {
          _showError('Please answer the second security question.');
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
      securityQuestion2: AppConstants.securityQuestions[_selectedQuestion2],
      securityAnswer2: _answerController2.text.trim().toLowerCase(),
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
    await NotificationService().scheduleWakeSleepReminders(
      wakeHour: _wakeHour,
      sleepHour: _sleepHour,
    );

    if (mounted) {
      await context.read<SettingsProvider>().load();
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.8)),
          boxShadow: const [
            BoxShadow(color: AppTheme.shadow, blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Step ${_currentPage + 1} of $_totalPages',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('${((_currentPage + 1) / _totalPages * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _totalPages,
                backgroundColor: AppTheme.bgCardLight,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.72),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
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
                  : Text(_currentPage == _totalPages - 1 ? 'Get Started' : 'Continue'),
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
          const FocusLockMark(size: 84),
          const SizedBox(height: 20),
          Text('FocusLock',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.primary,
                    height: 1.0,
                    letterSpacing: -0.8,
                  )),
          const SizedBox(height: 6),
          Text('Take back your attention.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 16),
          Text(
            'We will set your rhythm, limits, and reminders\nso FocusLock supports your day without friction.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _featureChip(Icons.query_stats_rounded, 'Track all apps at once'),
          _featureChip(Icons.lock_reset_rounded, 'Smart challenge unlock'),
          _featureChip(Icons.notifications_none_rounded, 'Smart notifications'),
          _featureChip(Icons.insights_rounded, 'Usage history'),
        ],
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.divider),
          boxShadow: const [
            BoxShadow(color: AppTheme.shadow, blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    return _PageWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle('Tell us about you'),
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
          _timePickerCard(
            label: 'Wake up',
            hour: _wakeHour,
            onTap: () => _pickHour(
              initialHour: _wakeHour,
              onPicked: (h) => setState(() => _wakeHour = h),
            ),
          ),
          const SizedBox(height: 24),
          Text('What time do you usually sleep?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _timePickerCard(
            label: 'Sleep',
            hour: _sleepHour,
            onTap: () => _pickHour(
              initialHour: _sleepHour,
              onPicked: (h) => setState(() => _sleepHour = h),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We will set a wake-up alarm and a sleep reminder at these times.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickHour({
    required int initialHour,
    required ValueChanged<int> onPicked,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: 0),
      initialEntryMode: TimePickerEntryMode.dial,
    );

    if (selected == null) return;
    onPicked(selected.hour);
  }

  Future<void> _pickMinutes({
    required String title,
    required int initialValue,
    required int min,
    required int max,
    required ValueChanged<int> onPicked,
  }) async {
    final clampedInitial = initialValue.clamp(min, max);
    final wheelController = FixedExtentScrollController(initialItem: clampedInitial - min);

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        int draft = clampedInitial;
        return StatefulBuilder(
          builder: (ctx2, setLocal) => SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.divider),
                boxShadow: const [
                  BoxShadow(color: AppTheme.shadow, blurRadius: 20, offset: Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Choose a value from $min to $max minutes',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _minuteQuickPicks(min, max).map((pick) {
                      final selectedPick = draft == pick;
                      return ChoiceChip(
                        label: Text(_formatDurationShort(pick)),
                        selected: selectedPick,
                        onSelected: (_) {
                          setLocal(() => draft = pick);
                          wheelController.animateToItem(
                            pick - min,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                          );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 170,
                    child: CupertinoPicker(
                      scrollController: wheelController,
                      itemExtent: 42,
                      magnification: 1.08,
                      useMagnifier: true,
                      onSelectedItemChanged: (index) => setLocal(() => draft = min + index),
                      children: List.generate(
                        max - min + 1,
                        (index) => Center(
                          child: Text(
                            _formatDurationLong(min + index),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, draft),
                          child: const Text('Set Limit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    wheelController.dispose();
    if (selected == null) return;
    onPicked(selected);
  }

  List<int> _minuteQuickPicks(int min, int max) {
    const picks = [10, 15, 20, 30, 45, 60, 90, 120, 180, 240];
    return picks.where((m) => m >= min && m <= max).toList();
  }

  String _formatDurationShort(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatDurationLong(int minutes) {
    if (minutes < 60) return '${minutes} min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h 0m (${minutes} min)' : '${h}h ${m}m (${minutes} min)';
  }

  Widget _timePickerCard({
    required String label,
    required int hour,
    required VoidCallback onTap,
  }) {
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '$displayHour:00 $period',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.schedule_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _minutesPickerCard({
    required String label,
    required String valueLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.tune_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsPage() {
    return _PageWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            _pageTitle('Which apps should we monitor?'),
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
            _pageTitle('Set your limits'),
            const SizedBox(height: 8),
            Text('These can be changed anytime in Settings.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            _sectionLabel('Daily limit'),
            Text(
              'Total time allowed on monitored apps each day before FocusLock blocks them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            _minutesPickerCard(
              label: 'Daily limit',
              valueLabel: _formatDurationLong(_dailyLimitMinutes),
              onTap: () => _pickMinutes(
                title: 'Set daily limit',
                initialValue: _dailyLimitMinutes,
                min: 2,
                max: 360,
                onPicked: (v) => setState(() => _dailyLimitMinutes = v),
              ),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Cooldown before unlock'),
            Text(
              'How long you must wait after hitting your limit before you can unlock again.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            _minutesPickerCard(
              label: 'Cooldown',
              valueLabel: _formatDurationLong(_cooldownMinutes),
              onTap: () => _pickMinutes(
                title: 'Set cooldown',
                initialValue: _cooldownMinutes,
                min: 5,
                max: 120,
                onPicked: (v) => setState(() => _cooldownMinutes = v),
              ),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Extra time per unlock'),
            Text(
              'Extra usage time granted each time you successfully unlock.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            _minutesPickerCard(
              label: 'Extra unlock time',
              valueLabel: _formatDurationLong(_extraUnlockMinutes),
              onTap: () => _pickMinutes(
                title: 'Set extra unlock time',
                initialValue: _extraUnlockMinutes,
                min: 5,
                max: 60,
                onPicked: (v) => setState(() => _extraUnlockMinutes = v),
              ),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Max unlocks per day'),
            Text(
              'Maximum number of unlock attempts allowed in a single day.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
            _pageTitle('Set your PIN'),
            const SizedBox(height: 8),
            Text('Used to access Settings. If you forget it, your security questions will help you recover it.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              obscureText: !_pinVisible,
              keyboardType: TextInputType.number,
              maxLength: AppConstants.pinLength,
              decoration: InputDecoration(
                labelText: 'Create PIN (${AppConstants.pinLength} digits)',
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
              maxLength: AppConstants.pinLength,
              decoration: InputDecoration(labelText: 'Confirm PIN (${AppConstants.pinLength} digits)'),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Security question 1 (for PIN recovery)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedQuestion,
              dropdownColor: AppTheme.bgCard,
              decoration: const InputDecoration(labelText: 'Choose question 1'),
              items: AppConstants.securityQuestions.asMap().entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (v) => setState(() => _selectedQuestion = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(labelText: 'Answer 1'),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 20),
            _sectionLabel('Second security question (for PIN recovery)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedQuestion2,
              dropdownColor: AppTheme.bgCard,
              decoration: const InputDecoration(labelText: 'Choose a second question'),
              items: AppConstants.securityQuestions.asMap().entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (v) => setState(() => _selectedQuestion2 = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController2,
              decoration: const InputDecoration(labelText: 'Second answer'),
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
                      'Remember both answers exactly — they are case-insensitive but spelling matters.',
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
          const Icon(Icons.verified_rounded, size: 80, color: AppTheme.primary),
          const SizedBox(height: 24),
          Text("You're all set!",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppTheme.primary)),
          const SizedBox(height: 16),
          Text(
            'FocusLock will now monitor your social media usage and lock apps when you hit your limit.\n\nYou\'re set.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _summaryChip('Daily limit: ${_dailyLimitMinutes ~/ 60}h ${_dailyLimitMinutes % 60}m'),
          _summaryChip('Cooldown: $_cooldownMinutes min'),
          _summaryChip('Monitoring: ${_selectedApps.length} apps'),
          _summaryChip('Max unlocks: $_maxUnlocks/day'),
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
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            boxShadow: const [
              BoxShadow(color: AppTheme.shadow, blurRadius: 10, offset: Offset(0, 4)),
            ],
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.8)),
          boxShadow: const [
            BoxShadow(color: AppTheme.shadow, blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        child: child,
      ),
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
          color: selected ? AppTheme.primary.withOpacity(0.12) : Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: AppTheme.shadow, blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(app.icon, color: AppTheme.primary, size: 19),
            ),
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
