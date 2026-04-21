import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/social_apps.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focuslock_brand.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/pickup_detector.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../data/models/user_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  String _email = '';
  Future<GuardrailStatus>? _guardrailFuture;
  UserSettings? _draftSettings;
  UserSettings? _savedSettings;
  bool _isApplyingChanges = false;

  Future<void> _pickHour({
    required TimeOfDay currentTime,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: currentTime,
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (selected == null) return;
    onPicked(selected);
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).dividerColor),
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
                      color: Theme.of(context).dividerColor,
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

  bool _sameSettings(UserSettings a, UserSettings b) {
    if (a.userName != b.userName ||
        a.dailyLimitMinutes != b.dailyLimitMinutes ||
        a.cooldownMinutes != b.cooldownMinutes ||
        a.extraUnlockMinutes != b.extraUnlockMinutes ||
        a.maxUnlocksPerDay != b.maxUnlocksPerDay ||
        a.lockScheduleEnabled != b.lockScheduleEnabled ||
        a.scheduleStartHour != b.scheduleStartHour ||
        a.scheduleStartMinute != b.scheduleStartMinute ||
        a.scheduleEndHour != b.scheduleEndHour ||
        a.scheduleEndMinute != b.scheduleEndMinute ||
        a.accelerometerEnabled != b.accelerometerEnabled ||
        a.wakeHour != b.wakeHour ||
        a.wakeMinute != b.wakeMinute ||
        a.sleepHour != b.sleepHour ||
        a.sleepMinute != b.sleepMinute ||
        a.notificationsEnabled != b.notificationsEnabled) {
      return false;
    }

    if (a.monitoredApps.length != b.monitoredApps.length) {
      return false;
    }
    final aApps = List<String>.from(a.monitoredApps)..sort();
    final bApps = List<String>.from(b.monitoredApps)..sort();
    for (var i = 0; i < aApps.length; i++) {
      if (aApps[i] != bApps[i]) {
        return false;
      }
    }
    return true;
  }

  bool _hasPendingChanges() {
    final draft = _draftSettings;
    final saved = _savedSettings;
    if (draft == null || saved == null) {
      return false;
    }
    return !_sameSettings(draft, saved);
  }

  void _updateDraft(UserSettings updated) {
    setState(() {
      _draftSettings = updated;
    });
  }

  Future<bool> _applyDraftChanges(SettingsProvider sp) async {
    final draft = _draftSettings;
    final previous = _savedSettings;
    if (draft == null || previous == null) {
      return true;
    }
    if (_sameSettings(draft, previous)) {
      return true;
    }

    setState(() => _isApplyingChanges = true);
    final result = await sp.updateWithGuardrails(draft);
    if (!mounted) {
      return false;
    }
    setState(() {
      _isApplyingChanges = false;
      _savedSettings = sp.settings;
      _draftSettings = sp.settings;
      _guardrailFuture = sp.getGuardrailStatus();
    });

    if (result.message != null && result.message!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message!),
          backgroundColor: result.applied ? AppTheme.success : AppTheme.warning,
        ),
      );
    }

    if (!result.applied) {
      return false;
    }

    if (previous.accelerometerEnabled != draft.accelerometerEnabled) {
      if (draft.accelerometerEnabled) {
        PickupDetector().start();
      } else {
        PickupDetector().stop();
      }
    }

    return true;
  }

  Future<bool> _confirmExitWithApply(SettingsProvider sp) async {
    if (!_hasPendingChanges()) {
      return true;
    }

    final decision = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave settings?'),
        content: const Text(
          'You made changes. If you confirm, changes will be applied now. Focus Lock increases and monitored-app reductions will be locked for 30 days from this moment. If you cancel, your pending edits will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Cancel Changes'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'apply'),
            child: const Text('Confirm & Apply'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return false;
    }

    if (decision == 'discard') {
      setState(() {
        _draftSettings = _savedSettings;
      });
      return true;
    }
    if (decision != 'apply') {
      return false;
    }

    return _applyDraftChanges(sp);
  }

  Future<bool> confirmExitIfNeeded() async {
    final sp = context.read<SettingsProvider>();
    return _confirmExitWithApply(sp);
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$mm/$dd/${date.year}';
  }

  @override
  void initState() {
    super.initState();
    final sp = context.read<SettingsProvider>();
    _guardrailFuture = sp.getGuardrailStatus();
    _savedSettings = sp.settings;
    _draftSettings = sp.settings;
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final email = await AuthService().getUserEmail();
    if (!mounted) return;
    setState(() => _email = email ?? 'focuslock.user@example.com');
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    if (_savedSettings == null) {
      _savedSettings = sp.settings;
      _draftSettings = sp.settings;
    }
    if (!_hasPendingChanges() && !_sameSettings(sp.settings, _savedSettings!)) {
      _savedSettings = sp.settings;
      _draftSettings = sp.settings;
    }

    final s = _draftSettings ?? sp.settings;
    final themeProvider = context.watch<ThemeProvider>();
    final guardrailFuture = _guardrailFuture ?? sp.getGuardrailStatus();

    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await _confirmExitWithApply(sp);
        return shouldExit;
      },
      child: SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profile & Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _isApplyingChanges
                ? null
                : () async {
                    final shouldExit = await _confirmExitWithApply(sp);
                    if (shouldExit && mounted) {
                      Navigator.pop(context);
                    }
                  },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            _ProfileHeroCard(
              userName: s.userName.isEmpty ? 'FocusLock User' : s.userName,
              email: _email,
              limitLabel: s.dailyLimitMinutes < 60
                  ? '${s.dailyLimitMinutes} min/day'
                  : '${s.dailyLimitMinutes ~/ 60}h ${s.dailyLimitMinutes % 60}m/day',
              trackedCount: s.monitoredApps.length,
            ),

            _SectionBlock(
              icon: Icons.tune_rounded,
              title: 'Focus Lock',
              subtitle: 'Set daily boundaries and unlock behaviour',
              initiallyExpanded: true,
              child: Column(
                children: [
                  FutureBuilder<GuardrailStatus>(
                    future: guardrailFuture,
                    builder: (context, snap) {
                      final data = snap.data;
                      final text = data == null
                          ? 'Increasing Focus Lock values is allowed once every 30 days. Decreases are always allowed.'
                          : data.focusIncreaseDaysLeft <= 0
                              ? 'You can increase Focus Lock values now. Decreases are always allowed.'
                              : 'Next Focus Lock increase allowed on ${_formatDate(data.focusIncreaseNextAllowedAt!)} (${data.focusIncreaseDaysLeft} day${data.focusIncreaseDaysLeft == 1 ? '' : 's'} left). Decreases are always allowed.';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                        ),
                      );
                    },
                  ),
                  _PickerTile(
                    label: 'Daily Social Media Limit',
                    valueLabel: _formatDurationLong(s.dailyLimitMinutes),
                    onTap: () => _pickMinutes(
                      title: 'Set daily limit',
                      initialValue: s.dailyLimitMinutes,
                      min: 2,
                      max: 360,
                      onPicked: (v) => _updateDraft(s.copyWith(dailyLimitMinutes: v)),
                    ),
                  ),
                  _PickerTile(
                    label: 'Cooldown Duration',
                    valueLabel: _formatDurationLong(s.cooldownMinutes),
                    onTap: () => _pickMinutes(
                      title: 'Set cooldown',
                      initialValue: s.cooldownMinutes,
                      min: 5,
                      max: 120,
                      onPicked: (v) => _updateDraft(s.copyWith(cooldownMinutes: v)),
                    ),
                  ),
                  _PickerTile(
                    label: 'Extra Time Per Unlock',
                    valueLabel: _formatDurationLong(s.extraUnlockMinutes),
                    onTap: () => _pickMinutes(
                      title: 'Set extra unlock time',
                      initialValue: s.extraUnlockMinutes,
                      min: 5,
                      max: 60,
                      onPicked: (v) => _updateDraft(s.copyWith(extraUnlockMinutes: v)),
                    ),
                  ),
                  _StepperTile(
                    label: 'Max Unlocks Per Day',
                    value: s.maxUnlocksPerDay,
                    min: 1,
                    max: 5,
                    onDecrement: () => _updateDraft(s.copyWith(maxUnlocksPerDay: s.maxUnlocksPerDay - 1)),
                    onIncrement: () => _updateDraft(s.copyWith(maxUnlocksPerDay: s.maxUnlocksPerDay + 1)),
                  ),
                ],
              ),
            ),

            _SectionBlock(
              icon: Icons.apps_rounded,
              title: 'Monitored Apps',
              subtitle: 'Choose which apps count toward your limit',
              child: Column(
                children: [
                  FutureBuilder<GuardrailStatus>(
                    future: guardrailFuture,
                    builder: (context, snap) {
                      final data = snap.data;
                      final text = data == null
                          ? 'Reducing monitored apps is allowed once every 30 days. Adding more apps is always allowed.'
                          : data.monitoredReductionDaysLeft <= 0
                              ? 'You can reduce monitored apps now. Adding more apps is always allowed.'
                              : 'Next monitored-app reduction allowed on ${_formatDate(data.monitoredReductionNextAllowedAt!)} (${data.monitoredReductionDaysLeft} day${data.monitoredReductionDaysLeft == 1 ? '' : 's'} left). Adding more apps is always allowed.';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                        ),
                      );
                    },
                  ),
                  _Card(
                    child: Column(
                      children: SocialApps.all.map((app) {
                        final selected = s.monitoredApps.contains(app.packageName);
                        return SwitchListTile(
                          secondary: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(app.icon, size: 16, color: AppTheme.primary),
                          ),
                          title: Text(app.displayName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                          value: selected,
                          onChanged: (v) {
                            final updated = List<String>.from(s.monitoredApps);
                            if (v) {
                              updated.add(app.packageName);
                            } else {
                              updated.remove(app.packageName);
                            }
                            _updateDraft(s.copyWith(monitoredApps: updated));
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            _SectionBlock(
              icon: Icons.schedule_rounded,
              title: 'Automation',
              subtitle: 'Manage scheduled lock windows',
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final active = _isWithinScheduleWindow(s, now);
                      final label = s.lockScheduleEnabled
                          ? (active ? 'Inside scheduled lock window' : 'Outside scheduled lock window')
                          : 'Scheduled lock is off';
                      final color = s.lockScheduleEnabled
                          ? (active ? AppTheme.danger : AppTheme.success)
                          : AppTheme.textMuted;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: color.withOpacity(0.18)),
                            ),
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text('Enable Scheduled Lock',
                              style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text('Only lock during specific hours',
                              style: Theme.of(context).textTheme.bodySmall),
                          value: s.lockScheduleEnabled,
                          onChanged: (v) => _updateDraft(s.copyWith(lockScheduleEnabled: v)),
                        ),
                        if (s.lockScheduleEnabled) ...[
                          const Divider(height: 1),
                          ListTile(
                            title: Text('Start Time', style: Theme.of(context).textTheme.bodyMedium),
                            subtitle: Text(_fmtHour(s.scheduleStartHour, s.scheduleStartMinute), style: Theme.of(context).textTheme.bodySmall),
                            trailing: const Icon(Icons.schedule_rounded),
                            onTap: () => _pickHour(
                              currentTime: TimeOfDay(hour: s.scheduleStartHour, minute: s.scheduleStartMinute),
                              onPicked: (t) => _updateDraft(s.copyWith(
                                scheduleStartHour: t.hour,
                                scheduleStartMinute: t.minute,
                              )),
                            ),
                          ),
                          ListTile(
                            title: Text('End Time', style: Theme.of(context).textTheme.bodyMedium),
                            subtitle: Text(_fmtHour(s.scheduleEndHour, s.scheduleEndMinute), style: Theme.of(context).textTheme.bodySmall),
                            trailing: const Icon(Icons.schedule_rounded),
                            onTap: () => _pickHour(
                              currentTime: TimeOfDay(hour: s.scheduleEndHour, minute: s.scheduleEndMinute),
                              onPicked: (t) => _updateDraft(s.copyWith(
                                scheduleEndHour: t.hour,
                                scheduleEndMinute: t.minute,
                              )),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _SectionBlock(
              icon: Icons.manage_accounts_rounded,
              title: 'Account & Preferences',
              subtitle: 'Security, notifications, feedback, and sign out',
              child: Column(
                children: [
                  _Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('Change PIN', style: Theme.of(context).textTheme.titleMedium),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _showChangePinDialog(context, sp),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text('Dark Theme', style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text(
                            'Apply dark appearance across the app',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          value: themeProvider.isDarkMode,
                          onChanged: (v) => themeProvider.setDarkMode(v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text('Track Phone Pickups', style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text(
                            'Use accelerometer to count how often you pick up your phone',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          value: s.accelerometerEnabled,
                          onChanged: (v) => _updateDraft(s.copyWith(accelerometerEnabled: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _SectionBlock(
              icon: Icons.warning_amber_rounded,
              title: 'Danger Zone',
              subtitle: 'Reset your app state when needed',
              child: _Card(
                child: ListTile(
                  title: Text('Reset All Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.danger)),
                  subtitle: Text('Returns to default limits and clears monitored apps',
                      style: Theme.of(context).textTheme.bodySmall),
                  trailing: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  onTap: () => _confirmReset(context, sp),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _isApplyingChanges
                  ? null
                  : () async {
                final shouldExit = await _confirmExitWithApply(sp);
                if (!shouldExit || !mounted) {
                  return;
                }
                await AuthService().logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2235),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, SettingsProvider sp) {
    showDialog(context: context, builder: (_) => _ChangePinDialog(sp: sp));
  }

  String _fmtHour(int h, int m) {
    final display = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final period = h >= 12 ? 'PM' : 'AM';
    final mm = m.toString().padLeft(2, '0');
    return '$display:$mm $period';
  }

  bool _isWithinScheduleWindow(UserSettings settings, DateTime now) {
    if (!settings.lockScheduleEnabled) return false;
    final nowMinutes = (now.hour * 60) + now.minute;
    final startMinutes = (settings.scheduleStartHour * 60) + settings.scheduleStartMinute;
    final endMinutes = (settings.scheduleEndHour * 60) + settings.scheduleEndMinute;

    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  void _confirmReset(BuildContext ctx, SettingsProvider sp) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: const Text('Reset Settings?'),
        content: const Text('This will reset all limits and clear your app list. Cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await sp.update(UserSettings.defaults().copyWith(
                userName: sp.settings.userName,
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
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
}

class _ProfileHeroCard extends StatelessWidget {
  final String userName;
  final String email;
  final String limitLabel;
  final int trackedCount;

  const _ProfileHeroCard({
    required this.userName,
    required this.email,
    required this.limitLabel,
    required this.trackedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121A2A), Color(0xFF1A2235)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const FocusLockMark(size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFA8B1C4),
                            height: 1.15,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Protected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroStatChip(
                  label: 'Daily limit',
                  value: limitLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStatChip(
                  label: 'Tracked apps',
                  value: '$trackedCount selected',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFA8B1C4),
                  fontSize: 11,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  const _SectionBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends State<_SectionBlock> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = Theme.of(context).textTheme.titleMedium?.color ?? AppTheme.textPrimary;
    final subtitleColor = isDark ? const Color(0xFFA8B1C4) : AppTheme.textSecondary;
    final iconBg = isDark ? Colors.white.withOpacity(0.08) : AppTheme.primary.withOpacity(0.14);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, size: 18, color: titleColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                              ),
                        ),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: subtitleColor,
                                height: 1.12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: subtitleColor, size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: widget.child,
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: child,
      );
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String valueLabel;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.valueLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Icon(Icons.tune_rounded, size: 18, color: Theme.of(context).textTheme.bodySmall?.color),
            ],
          ),
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
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
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

// ── DIALOGS ───────────────────────────────────────────────

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
      backgroundColor: Theme.of(context).cardColor,
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/forgot-pin');
                },
                child: const Text('Forgot PIN? Reset with OTP'),
              ),
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

