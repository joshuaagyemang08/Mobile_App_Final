import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/database_service.dart';
import '../../data/models/app_usage_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseService();
  List<DailyUsageSummary>? _summaries;
  int _selectedDayIndex = 6; // default to today
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _db.getLast7Days();
    if (mounted) {
      setState(() {
        _summaries = data;
        if (_selectedDayIndex >= data.length) {
          _selectedDayIndex = data.isEmpty ? 0 : data.length - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Usage History')),
        body: _summaries == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _buildInsightStrip(),
                    const SizedBox(height: 16),
                    _buildBarChart(),
                    const SizedBox(height: 20),
                    _buildDaySelector(),
                    const SizedBox(height: 16),
                    _buildDayBreakdown(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInsightStrip() {
    if (_summaries == null || _summaries!.isEmpty) return const SizedBox();

    final totals = _summaries!.map((s) => s.totalMinutes).toList();
    final totalWeekMinutes = totals.fold<int>(0, (sum, value) => sum + value);
    final averageMinutes = (totalWeekMinutes / _summaries!.length).round();
    final peakDay = _summaries!.reduce((a, b) => a.totalMinutes >= b.totalMinutes ? a : b);
    final quietDay = _summaries!.reduce((a, b) => a.totalMinutes <= b.totalMinutes ? a : b);

    final allEntries = _summaries!.expand((summary) => summary.entries);
    final grouped = <String, int>{};
    for (final entry in allEntries) {
      grouped[entry.appName] = (grouped[entry.appName] ?? 0) + entry.durationMinutes;
    }

    final topApp = grouped.entries.isEmpty
        ? null
        : grouped.entries.reduce((a, b) => a.value >= b.value ? a : b);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.insights_rounded,
                label: 'Week total',
                value: TimeUtils.formatMinutes(totalWeekMinutes),
                hint: 'Across the last 7 days',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightCard(
                icon: Icons.bolt_rounded,
                label: 'Daily average',
                value: TimeUtils.formatMinutes(averageMinutes),
                hint: 'Per day this week',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.trending_up_rounded,
                label: 'Peak day',
                value: TimeUtils.formatMinutes(peakDay.totalMinutes),
                hint: TimeUtils.friendlyDate(DateTime.parse(peakDay.date)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightCard(
                icon: Icons.nightlight_round,
                label: 'Quiet day',
                value: TimeUtils.formatMinutes(quietDay.totalMinutes),
                hint: TimeUtils.friendlyDate(DateTime.parse(quietDay.date)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _WideInsightCard(
          icon: Icons.smartphone_rounded,
          title: topApp == null ? 'Top app' : 'Most used app',
          value: topApp == null ? 'No usage yet' : topApp.key,
          subtitle: topApp == null ? 'Open an app to start collecting insights.' : '${TimeUtils.formatMinutes(topApp.value)} this week',
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    if (_summaries == null || _summaries!.isEmpty) return const SizedBox();
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    final maxVal = _summaries!.map((s) => s.totalMinutes).fold(0, (a, b) => a > b ? a : b).toDouble();
    final safeMax = maxVal < 60 ? 60.0 : maxVal + 20;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 Days', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap a bar or day to inspect where your time is going.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: safeMax,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      TimeUtils.formatMinutes(rod.toY.round()),
                      const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  touchCallback: (e, resp) {
                    if (resp?.spot != null) {
                      setState(() => _selectedDayIndex = resp!.spot!.touchedBarGroupIndex);
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.round();
                        if (idx < 0 || idx >= _summaries!.length) return const SizedBox();
                        final date = DateTime.parse(_summaries![idx].date);
                        final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(labels[date.weekday - 1],
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _summaries!.asMap().entries.map((e) {
                  final isSelected = e.key == _selectedDayIndex;
                  final mins = e.value.totalMinutes;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: mins.toDouble(),
                        color: isSelected ? AppTheme.primary : AppTheme.primary.withOpacity(0.4),
                        width: 24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    if (_summaries == null) return const SizedBox();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _summaries!.asMap().entries.map((e) {
          final isSelected = e.key == _selectedDayIndex;
          final date = DateTime.parse(e.value.date);
          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isSelected ? AppTheme.primary : Theme.of(context).dividerColor),
              ),
              child: Text(
                TimeUtils.friendlyDate(date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayBreakdown() {
    if (_summaries == null) return const SizedBox();
    final selected = _summaries![_selectedDayIndex];
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;

    if (selected.entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(color: AppTheme.shadow, blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            Text('No data for this day.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(TimeUtils.friendlyDate(DateTime.parse(selected.date)),
                style: Theme.of(context).textTheme.titleMedium),
            Text('Total: ${TimeUtils.formatMinutes(selected.totalMinutes)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 8),
        _DaySummaryLine(
          totalMinutes: selected.totalMinutes,
          appCount: selected.entries.length,
          topApp: selected.entries.isEmpty
              ? 'No apps'
              : selected.entries.reduce((a, b) => a.durationMinutes >= b.durationMinutes ? a : b).appName,
        ),
        const SizedBox(height: 12),
        ...selected.entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: const [
                  BoxShadow(color: AppTheme.shadow, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.appName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        TimeUtils.formatMinutes(e.durationMinutes),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: selected.totalMinutes <= 0 ? 0 : e.durationMinutes / selected.totalMinutes,
                      backgroundColor: AppTheme.primary.withOpacity(0.10),
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;

  const _InsightCard({required this.icon, required this.label, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(hint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _WideInsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _WideInsightCard({required this.icon, required this.title, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadow, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySummaryLine extends StatelessWidget {
  final int totalMinutes;
  final int appCount;
  final String topApp;

  const _DaySummaryLine({required this.totalMinutes, required this.appCount, required this.topApp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.14)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _ChipInfo(label: 'Total', value: TimeUtils.formatMinutes(totalMinutes)),
          _ChipInfo(label: 'Apps', value: '$appCount'),
          _ChipInfo(label: 'Top app', value: topApp),
        ],
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final String label;
  final String value;

  const _ChipInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
