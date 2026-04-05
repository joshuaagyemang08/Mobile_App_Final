import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/social_apps.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/user_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pinVerified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askForPin());
  }

  Future<void> _askForPin() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PinGateDialog(),
    );
    if (result == true) {
      setState(() => _pinVerified = true);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pinVerified) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sp = context.watch<SettingsProvider>();
    final s = sp.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── DAILY LIMITS ──────────────────────────────────
          const _SectionHeader('⏱️ Time Limits'),
          _SliderTile(
            label: 'Daily Social Media Limit',
            valueLabel: '${s.dailyLimitMinutes ~/ 60}h ${s.dailyLimitMinutes % 60}m',
            value: s.dailyLimitMinutes.toDouble(),
            min: 15,
            max: 360,
            divisions: 23,
            onChanged: (v) => sp.update(s.copyWith(dailyLimitMinutes: v.round())),
          ),
          _SliderTile(
            label: 'Cooldown Duration',
            valueLabel: '${s.cooldownMinutes} min',
            value: s.cooldownMinutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            onChanged: (v) => sp.update(s.copyWith(cooldownMinutes: v.round())),
          ),
          _SliderTile(
            label: 'Extra Time Per Unlock',
            valueLabel: '${s.extraUnlockMinutes} min',
            value: s.extraUnlockMinutes.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            onChanged: (v) => sp.update(s.copyWith(extraUnlockMinutes: v.round())),
          ),
          _StepperTile(
            label: 'Max Unlocks Per Day',
            value: s.maxUnlocksPerDay,
            min: 1,
            max: 5,
            onDecrement: () => sp.update(s.copyWith(maxUnlocksPerDay: s.maxUnlocksPerDay - 1)),
            onIncrement: () => sp.update(s.copyWith(maxUnlocksPerDay: s.maxUnlocksPerDay + 1)),
          ),

          // ── MONITORED APPS ────────────────────────────────
          const _SectionHeader('📱 Monitored Apps'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: SocialApps.all.map((app) {
                final selected = s.monitoredApps.contains(app.packageName);
                return SwitchListTile(
                  title: Text('${app.emoji}  ${app.displayName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                  value: selected,
                  onChanged: (v) {
                    final updated = List<String>.from(s.monitoredApps);
                    if (v) {
                      updated.add(app.packageName);
                    } else {
                      updated.remove(app.packageName);
                    }
                    sp.update(s.copyWith(monitoredApps: updated));
                  },
                );
              }).toList(),
            ),
          ),

          // ── LOCK SCHEDULE ─────────────────────────────────
          const _SectionHeader('📅 Lock Schedule'),
          _Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Enable Scheduled Lock',
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text('Only lock during specific hours',
                      style: Theme.of(context).textTheme.bodySmall),
                  value: s.lockScheduleEnabled,
                  onChanged: (v) => sp.update(s.copyWith(lockScheduleEnabled: v)),
                ),
                if (s.lockScheduleEnabled) ...[
                  const Divider(height: 1),
                  _HourPickerTile(
                    label: 'Start Hour',
                    hour: s.scheduleStartHour,
                    onChanged: (h) => sp.update(s.copyWith(scheduleStartHour: h)),
                  ),
                  _HourPickerTile(
                    label: 'End Hour',
                    hour: s.scheduleEndHour,
                    onChanged: (h) => sp.update(s.copyWith(scheduleEndHour: h)),
                  ),
                ],
              ],
            ),
          ),

          // ── SENSORS ───────────────────────────────────────
          const _SectionHeader('📡 Sensors'),
          _Card(
            child: SwitchListTile(
              title: Text('Track Phone Pickups',
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text('Use accelerometer to count how often you pick up your phone',
                  style: Theme.of(context).textTheme.bodySmall),
              value: s.accelerometerEnabled,
              onChanged: (v) => sp.update(s.copyWith(accelerometerEnabled: v)),
            ),
          ),

          // ── SECURITY ──────────────────────────────────────
          const _SectionHeader('🔐 Security'),
          _Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('Change PIN', style: Theme.of(context).textTheme.titleMedium),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showChangePinDialog(context, sp),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text('Update Recovery Questions',
                      style: Theme.of(context).textTheme.titleMedium),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showSecurityQuestionDialog(context, sp, s),
                ),
              ],
            ),
          ),

          // ── DANGER ZONE ───────────────────────────────────
          const _SectionHeader('⚠️ Danger Zone'),
          _Card(
            child: ListTile(
              title: Text('Reset All Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.danger)),
              subtitle: Text('Returns to default limits and clears monitored apps',
                  style: Theme.of(context).textTheme.bodySmall),
              trailing: const Icon(Icons.delete_outline, color: AppTheme.danger),
              onTap: () => _confirmReset(context, sp),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, SettingsProvider sp) {
    showDialog(context: context, builder: (_) => _ChangePinDialog(sp: sp));
  }

  void _showSecurityQuestionDialog(BuildContext context, SettingsProvider sp, UserSettings s) {
    showDialog(context: context, builder: (_) => _SecurityQuestionDialog(sp: sp, settings: s));
  }

  void _confirmReset(BuildContext ctx, SettingsProvider sp) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Reset Settings?'),
        content: const Text('This will reset all limits and clear your app list. Cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await sp.update(UserSettings.defaults().copyWith(
                userName: sp.settings.userName,
                securityQuestion: sp.settings.securityQuestion,
                securityAnswer: sp.settings.securityAnswer,
                securityQuestion2: sp.settings.securityQuestion2,
                securityAnswer2: sp.settings.securityAnswer2,
              ));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Settings reset to defaults.'), backgroundColor: AppTheme.success),
                );
              }
            },
            child: const Text('Reset', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ── WIDGETS ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: child,
      );
}

class _SliderTile extends StatelessWidget {
  final String label, valueLabel;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(valueLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary)),
              ],
            ),
            Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
          ],
        ),
      );
}

class _StepperTile extends StatelessWidget {
  final String label;
  final int value, min, max;
  final VoidCallback onDecrement, onIncrement;

  const _StepperTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            IconButton(
                onPressed: value > min ? onDecrement : null,
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.accent)),
            Text('$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primary)),
            IconButton(
                onPressed: value < max ? onIncrement : null,
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary)),
          ],
        ),
      );
}

class _HourPickerTile extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  const _HourPickerTile({required this.label, required this.hour, required this.onChanged});

  String _fmt(int h) {
    final display = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final period = h >= 12 ? 'PM' : 'AM';
    return '$display:00 $period';
  }

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        trailing: DropdownButton<int>(
          value: hour,
          dropdownColor: AppTheme.bgCard,
          underline: const SizedBox(),
          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(_fmt(i)))),
          onChanged: (v) => onChanged(v!),
        ),
      );
}

// ── DIALOGS ───────────────────────────────────────────────

class _PinGateDialog extends StatefulWidget {
  const _PinGateDialog();

  @override
  State<_PinGateDialog> createState() => _PinGateDialogState();
}

class _PinGateDialogState extends State<_PinGateDialog> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _showRecovery = false;
  int _attempts = 0;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final sp = context.read<SettingsProvider>();
    final ok = await sp.verifyPin(_pinCtrl.text);
    if (ok) {
      if (mounted) Navigator.pop(context, true);
    } else {
      _attempts++;
      setState(() {
        _error = 'Incorrect PIN.';
        _pinCtrl.clear();
        if (_attempts >= 3) _showRecovery = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Enter PIN to access Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: AppConstants.pinLength,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'PIN (6 digits)',
                errorText: _error,
                counterText: '',
              ),
              onSubmitted: (_) => _verify(),
            ),
            if (_showRecovery) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                  Future.microtask(() => Navigator.pushNamed(context, '/forgot-pin'));
                },
                child: const Text('Forgot PIN? Recover via security questions',
                    style: TextStyle(color: AppTheme.warning, fontSize: 12)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: _verify,
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              child: const Text('Unlock')),
        ],
      );
}

class _ChangePinDialog extends StatefulWidget {
  final SettingsProvider sp;
  const _ChangePinDialog({required this.sp});

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final oldOk = await widget.sp.verifyPin(_oldCtrl.text);
    if (!oldOk) { setState(() => _error = 'Current PIN is incorrect.'); return; }
    if (!RegExp(r'^\d{6}$').hasMatch(_newCtrl.text)) {
      setState(() => _error = 'New PIN must be exactly ${AppConstants.pinLength} digits.');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) { setState(() => _error = 'PINs do not match.'); return; }
    await widget.sp.savePin(_newCtrl.text);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated!'), backgroundColor: AppTheme.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _oldCtrl, obscureText: true, keyboardType: TextInputType.number,
                maxLength: AppConstants.pinLength,
                decoration: const InputDecoration(labelText: 'Current PIN (6 digits)', counterText: '')),
            const SizedBox(height: 8),
            TextField(controller: _newCtrl, obscureText: true, keyboardType: TextInputType.number,
                maxLength: AppConstants.pinLength,
                decoration: const InputDecoration(labelText: 'New PIN (6 digits)', counterText: '')),
            const SizedBox(height: 8),
            TextField(controller: _confirmCtrl, obscureText: true, keyboardType: TextInputType.number,
                maxLength: AppConstants.pinLength,
                decoration: InputDecoration(labelText: 'Confirm New PIN (6 digits)', errorText: _error, counterText: '')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              child: const Text('Save')),
        ],
      );
}

class _SecurityQuestionDialog extends StatefulWidget {
  final SettingsProvider sp;
  final UserSettings settings;
  const _SecurityQuestionDialog({required this.sp, required this.settings});

  @override
  State<_SecurityQuestionDialog> createState() => _SecurityQuestionDialogState();
}

class _SecurityQuestionDialogState extends State<_SecurityQuestionDialog> {
  late int _selectedQ;
  late int _selectedQ2;
  final _answerCtrl = TextEditingController();
  final _answerCtrl2 = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedQ = AppConstants.securityQuestions
        .indexOf(widget.settings.securityQuestion)
        .clamp(0, AppConstants.securityQuestions.length - 1);
    _selectedQ2 = AppConstants.securityQuestions
        .indexOf(widget.settings.securityQuestion2)
        .clamp(0, AppConstants.securityQuestions.length - 1);
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _answerCtrl2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedQ == _selectedQ2) {
      setState(() => _error = 'Choose two different security questions.');
      return;
    }
    if (_answerCtrl.text.trim().isEmpty || _answerCtrl2.text.trim().isEmpty) {
      setState(() => _error = 'Please provide both answers.');
      return;
    }
    await widget.sp.update(widget.settings.copyWith(
      securityQuestion: AppConstants.securityQuestions[_selectedQ],
      securityAnswer: _answerCtrl.text.trim().toLowerCase(),
      securityQuestion2: AppConstants.securityQuestions[_selectedQ2],
      securityAnswer2: _answerCtrl2.text.trim().toLowerCase(),
    ));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery questions updated!'), backgroundColor: AppTheme.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Update Recovery Questions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedQ,
              dropdownColor: AppTheme.bgCard,
              decoration: const InputDecoration(labelText: 'Question 1'),
              items: AppConstants.securityQuestions.asMap().entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedQ = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerCtrl,
              decoration: InputDecoration(labelText: 'Answer 1', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedQ2,
              dropdownColor: AppTheme.bgCard,
              decoration: const InputDecoration(labelText: 'Question 2'),
              items: AppConstants.securityQuestions.asMap().entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedQ2 = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerCtrl2,
              decoration: InputDecoration(labelText: 'Answer 2', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              child: const Text('Save')),
        ],
      );
}
