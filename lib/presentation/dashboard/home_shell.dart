import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/tracking_service.dart';
import '../../core/widgets/pin_prompt_dialog.dart';
import '../../providers/usage_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _settingsPromptOpen = false;

  final _pages = const [
    DashboardScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (AppConstants.enableTracking) {
      _startMonitoring();
      FlutterForegroundTask.addTaskDataCallback(_handleTaskData);
    }
  }

  Future<void> _startMonitoring() async {
    await TrackingService().start();
  }

  Future<void> _handleTaskData(Object data) async {
    if (!mounted || data is! Map) {
      return;
    }

    if (data['action'] == 'lock') {
      context.read<UsageProvider>().triggerLock();
      return;
    }

    if (data['action'] == 'update') {
      await context.read<UsageProvider>().updateFromBackground(data['totalMinutes'] as int);
    }
  }

  @override
  void dispose() {
    if (AppConstants.enableTracking) {
      FlutterForegroundTask.removeTaskDataCallback(_handleTaskData);
    }
    super.dispose();
  }

  Future<void> _openSettingsWithPin() async {
    if (_settingsPromptOpen) return;
    _settingsPromptOpen = true;

    final ok = await showPinPrompt(
      context,
      title: 'Unlock Settings',
      subtitle: 'Enter your PIN before opening Settings.',
    );

    _settingsPromptOpen = false;
    if (!ok || !mounted) return;
    setState(() => _currentIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1A1B2A).withOpacity(0.94) : Colors.white.withOpacity(0.94);
    final borderColor = isDark ? const Color(0xFF2F3146) : AppTheme.divider;
    final unselected = isDark ? const Color(0xFFA6A8BC) : AppTheme.textMuted;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderColor),
              boxShadow: const [
                BoxShadow(color: AppTheme.shadow, blurRadius: 24, offset: Offset(0, 10)),
              ],
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: AppTheme.primary.withOpacity(0.12),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    color: selected ? AppTheme.primary : unselected,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) {
                  if (i == 2 && _currentIndex != 2) {
                    _openSettingsWithPin();
                    return;
                  }
                  setState(() => _currentIndex = i);
                },
                height: 70,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'History'),
                  NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
