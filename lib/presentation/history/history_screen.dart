import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _db.getLast7Days();
    if (mounted) setState(() => _summaries = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usage History')),
      body: _summaries == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildBarChart(),
                const SizedBox(height: 20),
                _buildDaySelector(),
                const SizedBox(height: 16),
                _buildDayBreakdown(),
              ],
            ),
    );
  }

  Widget _buildBarChart() {
    if (_summaries == null || _summaries!.isEmpty) return const SizedBox();
    final maxVal = _summaries!.map((s) => s.totalMinutes).fold(0, (a, b) => a > b ? a : b).toDouble();
    final safeMax = maxVal < 60 ? 60.0 : maxVal + 20;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 Days', style: Theme.of(context).textTheme.titleMedium),
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
                color: isSelected ? AppTheme.primary : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
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

    if (selected.entries.isEmpty) {
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
        const SizedBox(height: 12),
        ...selected.entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.appName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                  Text(TimeUtils.formatMinutes(e.durationMinutes),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary)),
                ],
              ),
            )),
      ],
    );
  }
}
