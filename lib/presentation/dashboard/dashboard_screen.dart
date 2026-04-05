import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/constants/social_apps.dart';
import '../../providers/settings_provider.dart';
import '../../providers/usage_provider.dart';
import '../lock/lock_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>().settings;
    await context.read<UsageProvider>().refresh(
          settings.monitoredApps,
          settings.dailyLimitMinutes,
        );
    // Navigate to lock if locked
    if (mounted && context.read<UsageProvider>().isLocked) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LockScreen()));
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('FocusLock'),
            Text('Hey, ${settings.userName} 👋',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _UsageRingCard(usage: usage, settings: settings),
            const SizedBox(height: 16),
            _StatsRow(usage: usage),
            const SizedBox(height: 16),
            if (usage.todayEntries.isNotEmpty) ...[
              const _SectionHeader('App Breakdown'),
              const SizedBox(height: 8),
              ...usage.todayEntries.map((e) {
                final percent = usage.totalMinutesToday > 0 ? e.durationMinutes / usage.totalMinutesToday : 0.0;
                final app = SocialApps.fromPackage(e.packageName);
                return _AppBar(
                  emoji: app?.emoji ?? '📱',
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
    );
  }
}

class _UsageRingCard extends StatelessWidget {
  final UsageProvider usage;
  final settings;
  const _UsageRingCard({required this.usage, required this.settings});

  @override
  Widget build(BuildContext context) {
    final color = usage.usagePercent < 0.75
        ? AppTheme.success
        : usage.usagePercent < 0.90
            ? AppTheme.warning
            : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
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
  const _StatsRow({required this.usage});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: usage.getTodayPickupCount(),
      builder: (ctx, snap) {
        final pickups = snap.data ?? 0;
        return Row(
          children: [
            _StatCard(
              emoji: '📲',
              label: 'Phone Pickups',
              value: '$pickups',
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            FutureBuilder<int>(
              future: usage.getTodayUnlockCount(),
              builder: (ctx2, snap2) => _StatCard(
                emoji: '🔓',
                label: 'Unlocks Used',
                value: snap2.data?.toString() ?? '0',
                color: AppTheme.accent,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _StatCard({required this.emoji, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.displayMedium?.copyWith(color: color, fontSize: 24)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
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
  final String emoji, name;
  final int minutes;
  final double percent;

  const _AppBar({required this.emoji, required this.name, required this.minutes, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 40)),
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
    final tip = percent < 0.5
        ? ('💪', 'Great job! You\'re well within your limit.')
        : percent < 0.75
            ? ('👀', 'Over halfway there. Pace yourself!')
            : percent < 0.90
                ? ('⚠️', 'Getting close to your limit. Wrap up soon.')
                : ('🚨', 'Almost at your limit! Time to put the phone down.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Text(tip.$1, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tip.$2, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
