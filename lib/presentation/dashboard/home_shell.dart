import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/pickup_detector.dart';
import '../../data/services/tracking_service.dart';
import '../../core/widgets/pin_prompt_dialog.dart';
import '../../providers/settings_provider.dart';
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
  bool _accessibilityEnabled = true;
  Timer? _accessibilityCheckTimer;
  final GlobalKey<SettingsScreenState> _settingsScreenKey = GlobalKey<SettingsScreenState>();

  static const _platform = MethodChannel('com.focuslock.app/permissions');
  static const String _keyAccessibilityStatus = 'flutter.accessibility_enabled';

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    PickupDetector().setOnPickupCallback(_handlePickupDetected);
    _pages = [
      const DashboardScreen(),
      const HistoryScreen(),
      SettingsScreen(key: _settingsScreenKey),
    ];
    final settings = context.read<SettingsProvider>().settings;
    if (AppConstants.enableTracking && settings.accelerometerEnabled) {
      PickupDetector().start();
    }
    _checkAccessibilityStatus();
    _accessibilityCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkAccessibilityStatus(),
    );
    if (AppConstants.enableTracking) {
      _startMonitoring();
      FlutterForegroundTask.addTaskDataCallback(_handleTaskData);
    }
  }

  Future<void> _checkAccessibilityStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = await _platform.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
      await prefs.setBool(_keyAccessibilityStatus, enabled);
      if (mounted) {
        setState(() {
          _accessibilityEnabled = enabled;
        });
      }
    } catch (e) {
      print('Error checking accessibility: $e');
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
    _accessibilityCheckTimer?.cancel();
    PickupDetector().setOnPickupCallback(null);
    if (AppConstants.enableTracking) {
      FlutterForegroundTask.removeTaskDataCallback(_handleTaskData);
    }
    super.dispose();
  }

  void _handlePickupDetected() {
    if (!mounted) return;
    context.read<UsageProvider>().refreshPickupCount();
  }

  Future<void> _openSettingsWithPin() async {
    if (_settingsPromptOpen) return;
    _settingsPromptOpen = true;

    final result = await showPinPrompt(
      context,
      title: 'Unlock Settings',
      subtitle: 'Enter your PIN before opening Settings.',
    );

    _settingsPromptOpen = false;
    if (!mounted) return;
    if (result == PinPromptResult.forgot) {
      Navigator.pushNamed(context, '/forgot-pin');
      return;
    }
    if (result != PinPromptResult.success) return;
    setState(() => _currentIndex = 2);
  }

  Future<void> _onDestinationSelected(int i) async {
    if (i == _currentIndex) {
      return;
    }

    if (i == 2) {
      await _openSettingsWithPin();
      return;
    }

    if (_currentIndex == 2) {
      final settingsState = _settingsScreenKey.currentState;
      if (settingsState != null) {
        final canLeave = await settingsState.confirmExitIfNeeded();
        if (!canLeave) {
          return;
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1A1B2A).withOpacity(0.94) : Colors.white.withOpacity(0.94);
    final borderColor = isDark ? const Color(0xFF2F3146) : AppTheme.divider;
    final unselected = isDark ? const Color(0xFFA6A8BC) : AppTheme.textMuted;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          if (!_accessibilityEnabled)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  color: AppTheme.danger.withOpacity(0.1),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accessibility disabled',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.danger,
                                  ),
                            ),
                            Text(
                              'App blocking won\'t work. Re-enable in Settings.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _platform.invokeMethod('openAccessibilitySettings'),
                        child: const Text('Fix'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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
                onDestinationSelected: _onDestinationSelected,
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
