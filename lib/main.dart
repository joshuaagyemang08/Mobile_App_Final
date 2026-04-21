import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/widgets/scene_background.dart';
import 'data/services/settings_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/pickup_detector.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/signup_screen.dart';
import 'presentation/auth/forgot_password_screen.dart';
import 'presentation/auth/verify_email_otp_screen.dart';
import 'presentation/onboarding/permissions_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/dashboard/home_shell.dart';
import 'presentation/lock/lock_screen.dart';
import 'presentation/settings/forgot_pin_screen.dart';
import 'presentation/settings/settings_access_gate_screen.dart';
import 'presentation/profile/feedback_screen.dart';
import 'presentation/profile/notifications_screen.dart';
import 'core/widgets/focuslock_brand.dart';

const _permissionsChannel = MethodChannel('com.focuslock.app/permissions');
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  FlutterForegroundTask.initCommunicationPort();

  _permissionsChannel.setMethodCallHandler((call) async {
    if (call.method == 'forceOpenLock') {
      final nav = _navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil('/lock', (route) => false);
      }
    }
  });

  if (AppConstants.enableTracking) {
    // Foreground task — request battery optimisation exemption
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  // Initialise notifications
  await NotificationService().init();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const FocusLockApp());
}

class FocusLockApp extends StatelessWidget {
  const FocusLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'FocusLock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeProvider.themeMode,
        home: const _SplashRouter(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignupScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/home': (_) => const HomeShell(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/permissions': (_) => const PermissionsScreen(),
          '/lock': (_) => const LockScreen(),
          '/forgot-pin': (_) => const ForgotPinScreen(),
          '/settings-jump': (_) => const SettingsAccessGateScreen(),
          '/feedback': (_) => const FeedbackScreen(),
          '/notifications': (_) => const NotificationsScreen(),
        },
      ),
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

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    await user.reload();
    final refreshedUser = auth.currentUser;
    if (refreshedUser == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (!refreshedUser.emailVerified) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailOtpScreen(email: refreshedUser.email ?? ''),
          ),
        );
      }
      return;
    }

    final settingsService = SettingsService();
    var onboarded = await settingsService.isOnboarded();
    if (!onboarded) {
      final remoteOnboarded = await settingsService.inferRemoteOnboardingComplete();
      if (remoteOnboarded) {
        await settingsService.completeOnboarding();
        onboarded = true;
      }
    }

    if (AppConstants.enableTracking) {
      final hasPermissions = await _hasBlockingPermissions();
      if (!hasPermissions) {
        if (mounted) Navigator.pushReplacementNamed(context, '/permissions');
        return;
      }
    }

    if (!onboarded) {
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    // Load settings into provider
    await context.read<SettingsProvider>().load();

    final settings = context.read<SettingsProvider>().settings;

    // Start accelerometer pickup detection if enabled
    if (AppConstants.enableTracking && settings.accelerometerEnabled) {
      PickupDetector().start();
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  Future<bool> _hasBlockingPermissions() async {
    try {
      final usage = await _permissionsChannel.invokeMethod<bool>('checkUsageStatsPermission') ?? false;
      final overlay = await _permissionsChannel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      final accessibility = await _permissionsChannel.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
      return usage && overlay && accessibility;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.7)),
              boxShadow: const [
                BoxShadow(color: AppTheme.shadow, blurRadius: 30, offset: Offset(0, 16)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FocusLockMark(size: 92),
                const SizedBox(height: 24),
                Text(
                  'FocusLock',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A calmer way to manage screen time.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
