import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/constants/social_apps.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/models/user_settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/usage_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh({bool showFeedback = false}) async {
    if (!mounted || _isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      final settings = context.read<SettingsProvider>().settings;
      await context.read<UsageProvider>().refresh(
            settings.monitoredApps,
            settings.dailyLimitMinutes,
          );

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard refreshed.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh right now. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    final settings = context.watch<SettingsProvider>().settings;

    if (usage.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FocusLock'),
              Text('Good to see you, ${settings.userName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
            ],
          ),
          actions: [
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              onPressed: _isRefreshing ? null : () => _refresh(showFeedback: true),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _refresh(),
          color: AppTheme.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _HeaderCard(usage: usage, settings: settings),
              const SizedBox(height: 16),
              _UsageRingCard(usage: usage, settings: settings),
              const SizedBox(height: 16),
              _StatsRow(usage: usage, settings: settings),
              const SizedBox(height: 16),
              if (usage.todayEntries.isNotEmpty) ...[
                const _SectionHeader('App Breakdown'),
                const SizedBox(height: 8),
                ...usage.todayEntries.map((e) {
                  final percent = usage.totalMinutesToday > 0 ? e.durationMinutes / usage.totalMinutesToday : 0.0;
                  final app = SocialApps.fromPackage(e.packageName);
                  return _AppBar(
                    icon: app?.icon ?? Icons.apps_rounded,
                    name: e.appName,
                    minutes: e.durationMinutes,
                    percent: percent,
                  );
                }),
              ] else
                _EmptyApps(),
              const SizedBox(height: 16),
              _TipsCard(percent: usage.usagePercent),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UsageProvider usage;
  final UserSettings settings;

  const _HeaderCard({required this.usage, required this.settings});

  @override
  Widget build(BuildContext context) {
    final progress = usage.usagePercent.clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    final gradient = isDark
      ? const [Color(0xFF1A1B2A), Color(0xFF202236)]
      : const [Colors.white, Color(0xFFF9F6FF)];
    final colour = progress < 0.75
        ? AppTheme.success
        : progress < 0.9
            ? AppTheme.warning
            : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.insights_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today at a glance', style: Theme.of(context).textTheme.bodySmall),
                    Text('Focus is holding steady.', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colour.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colour, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            TimeUtils.formatMinutes(usage.totalMinutesToday),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).textTheme.displayLarge?.color,
                  letterSpacing: -1.2,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'used out of ${TimeUtils.formatMinutes(settings.dailyLimitMinutes)} today',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniMetric(label: 'Remaining', value: TimeUtils.formatMinutes(usage.remainingMinutes)),
              const SizedBox(width: 12),
              _MiniMetric(label: 'Apps tracked', value: '${usage.todayEntries.length}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _UsageRingCard extends StatelessWidget {
  final UsageProvider usage;
  final UserSettings settings;
  const _UsageRingCard({required this.usage, required this.settings});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    final color = usage.usagePercent < 0.75
        ? AppTheme.success
        : usage.usagePercent < 0.90
            ? AppTheme.warning
            : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Text('Today\'s Usage', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: 65,
                    sections: [
                      PieChartSectionData(
                        value: usage.usagePercent,
                        color: color,
                        radius: 18,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 1 - usage.usagePercent,
                        color: AppTheme.bgCardLight,
                        radius: 14,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TimeUtils.formatMinutes(usage.totalMinutesToday),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(color: color, fontSize: 28),
                    ),
                    Text('used', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ringLabel(context, 'Limit', TimeUtils.formatMinutes(usage.limitMinutes), AppTheme.textMuted),
              _ringLabel(context, 'Remaining', TimeUtils.formatMinutes(usage.remainingMinutes), color),
              _ringLabel(context, 'Progress', '${(usage.usagePercent * 100).round()}%', color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ringLabel(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UsageProvider usage;
  final UserSettings settings;
  const _StatsRow({required this.usage, required this.settings});

  @override
  Widget build(BuildContext context) {
    final cooldownEnd = usage.cooldownEndTime;
    final inCooldown = usage.isLocked && cooldownEnd != null && cooldownEnd.isAfter(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              icon: Icons.smartphone_rounded,
              label: 'Phone Pickups',
              value: '${usage.todayPickupCount}',
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            FutureBuilder<int>(
              future: usage.getTodayUnlockCount(),
              builder: (ctx2, snap2) {
                final used = snap2.data ?? 0;
                final left = (settings.maxUnlocksPerDay - used).clamp(0, settings.maxUnlocksPerDay);
                return _StatCard(
                  icon: Icons.lock_open_rounded,
                  label: 'Unlocks Left',
                  value: '$left',
                  color: left > 0 ? AppTheme.accent : AppTheme.danger,
                );
              },
            ),
          ],
        ),
        if (inCooldown) ...[
          const SizedBox(height: 12),
          _CooldownCard(endTime: cooldownEnd),
        ],
      ],
    );
  }
}

class _CooldownCard extends StatelessWidget {
  final DateTime endTime;

  const _CooldownCard({required this.endTime});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;

    return StreamBuilder<int>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => endTime.difference(DateTime.now()).inSeconds,
      ),
      initialData: endTime.difference(DateTime.now()).inSeconds,
      builder: (context, snap) {
        final raw = snap.data ?? 0;
        final seconds = raw < 0 ? 0 : raw;
        final label = seconds > 0 ? TimeUtils.formatSeconds(seconds) : '00:00';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.timer_rounded, color: AppTheme.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cooldown Active', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                    Text('Remaining: $label', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.warning)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.displayMedium?.copyWith(color: color, fontSize: 24)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: OutlinedButton(
                  onPressed: onActionTap,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
                  ),
                  child: Text(
                    actionLabel!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _AppBar extends StatelessWidget {
  final IconData icon;
  final String name;
  final int minutes;
  final double percent;

  const _AppBar({required this.icon, required this.name, required this.minutes, required this.percent});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                    Text(TimeUtils.formatMinutes(minutes),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: AppTheme.bgCardLight,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyApps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text('No usage data yet today.', style: Theme.of(context).textTheme.bodyMedium),
          Text('Open your social apps and come back!',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final double percent;
  const _TipsCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    final tip = percent < 0.5
      ? (Icons.check_circle_outline, 'Great job! You\'re well within your limit.')
      : percent < 0.75
        ? (Icons.visibility_outlined, 'Over halfway there. Pace yourself!')
        : percent < 0.90
          ? (Icons.warning_amber_rounded, 'Getting close to your limit. Wrap up soon.')
          : (Icons.dangerous_outlined, 'Almost at your limit! Time to put the phone down.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Icon(tip.$1, size: 28, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tip.$2, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
