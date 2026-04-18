import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/settings_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _usageGranted = false;
  bool _overlayGranted = false;
  bool _accessibilityGranted = false;
  bool _notifGranted = false;

  static const _platform = MethodChannel('com.focuslock.app/permissions');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAll() async {
    bool usage = false;
    bool overlay = false;
    bool accessibility = false;
    try {
      usage = await _platform.invokeMethod<bool>('checkUsageStatsPermission') ?? false;
      overlay = await _platform.invokeMethod<bool>('checkOverlayPermission') ?? false;
      accessibility = await _platform.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
    } catch (_) {}
    final notif = await Permission.notification.isGranted;
    setState(() {
      _usageGranted = usage;
      _overlayGranted = overlay;
      _accessibilityGranted = accessibility;
      _notifGranted = notif;
    });
  }

  bool get _allGranted => _usageGranted && _overlayGranted && _accessibilityGranted;

  void _openUsageSettings() {
    _platform.invokeMethod('openUsageSettings');
  }

  void _openOverlaySettings() {
    _platform.invokeMethod('openOverlaySettings');
  }

  void _openAccessibilitySettings() {
    _platform.invokeMethod('openAccessibilitySettings');
  }

  Future<void> _requestNotif() async {
    await Permission.notification.request();
    await _checkAll();
  }

  Future<void> _proceed() async {
    if (!_allGranted) return;

    final onboarded = await SettingsService().isOnboarded();
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, onboarded ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.84),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.75)),
                    boxShadow: const [
                      BoxShadow(color: AppTheme.shadow, blurRadius: 24, offset: Offset(0, 12)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Permissions first', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              'FocusLock needs a few system permissions to monitor and block apps correctly.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      _PermissionTile(
                        icon: Icons.query_stats_rounded,
                        title: 'Usage Access',
                        description: 'Lets FocusLock see how long you\'ve spent on each app.',
                        isGranted: _usageGranted,
                        onTap: _openUsageSettings,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      _PermissionTile(
                        icon: Icons.layers_rounded,
                        title: 'Display Over Other Apps',
                        description: 'Shows the lock screen over monitored apps when limits are reached.',
                        isGranted: _overlayGranted,
                        onTap: _openOverlaySettings,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      _PermissionTile(
                        icon: Icons.accessibility_new_rounded,
                        title: 'Accessibility Access',
                        description: 'Detects when a monitored app opens so FocusLock can block it immediately.',
                        isGranted: _accessibilityGranted,
                        onTap: _openAccessibilitySettings,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      _PermissionTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        description: 'Sends usage alerts before your limit is reached.',
                        isGranted: _notifGranted,
                        onTap: _requestNotif,
                        isRequired: false,
                      ),
                      const SizedBox(height: 18),
                      if (!_allGranted)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tap each permission and grant it, then return here.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _allGranted ? _proceed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _allGranted ? AppTheme.primary : AppTheme.bgCardLight,
                          foregroundColor: _allGranted ? Colors.white : AppTheme.textMuted,
                        ),
                        child: Text(_allGranted ? 'Continue to Setup →' : 'Grant permissions to continue'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final bool isGranted, isRequired;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGranted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isGranted ? AppTheme.success.withOpacity(0.08) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isGranted ? AppTheme.success.withOpacity(0.35) : AppTheme.divider,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: AppTheme.shadow, blurRadius: 14, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: isGranted ? AppTheme.success : AppTheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      if (!isRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('optional', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isGranted ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isGranted ? AppTheme.success : AppTheme.textMuted,
              size: isGranted ? 24 : 16,
            ),
          ],
        ),
      ),
    );
  }
}
