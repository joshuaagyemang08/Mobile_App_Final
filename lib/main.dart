import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/theme/app_theme.dart';
import 'data/services/settings_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/pickup_detector.dart';
import 'providers/settings_provider.dart';
import 'providers/usage_provider.dart';
import 'presentation/onboarding/permissions_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/dashboard/home_shell.dart';
import 'presentation/lock/lock_screen.dart';
import 'presentation/settings/forgot_pin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  // Foreground task — request battery optimisation exemption
  await FlutterForegroundTask.requestIgnoreBatteryOptimization();

  // Initialise notifications
  await NotificationService().init();
  await NotificationService().requestPermission();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const FocusLockApp());
}

class FocusLockApp extends StatelessWidget {
  const FocusLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
      ],
      child: MaterialApp(
        title: 'FocusLock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _SplashRouter(),
        routes: {
          '/home': (_) => const HomeShell(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/permissions': (_) => const PermissionsScreen(),
          '/lock': (_) => const LockScreen(),
          '/forgot-pin': (_) => const ForgotPinScreen(),
        },
      ),
    );
  }
}

/// Decides which screen to show on cold start.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // Small delay so splash has time to render
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final settingsService = SettingsService();
    final onboarded = await settingsService.isOnboarded();

    if (!onboarded) {
      Navigator.pushReplacementNamed(context, '/permissions');
      return;
    }

    // Load settings into provider
    await context.read<SettingsProvider>().load();

    // Check if currently locked
    final isLocked = await settingsService.isLocked();
    if (isLocked) {
      if (mounted) Navigator.pushReplacementNamed(context, '/lock');
      return;
    }

    // Start accelerometer pickup detection if enabled
    final settings = context.read<SettingsProvider>().settings;
    if (settings.accelerometerEnabled) {
      PickupDetector().start();
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2),
              ),
              child: const Center(
                child: Text('🔒', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 20),
            Text('FocusLock',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppTheme.primary)),
            const SizedBox(height: 8),
            Text('Take back your time.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
