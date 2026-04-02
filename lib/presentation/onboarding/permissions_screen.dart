import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _usageGranted = false;
  bool _overlayGranted = false;
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
    try {
      usage = await _platform.invokeMethod<bool>('checkUsageStatsPermission') ?? false;
      overlay = await _platform.invokeMethod<bool>('checkOverlayPermission') ?? false;
    } catch (_) {}
    final notif = await Permission.notification.isGranted;
    setState(() {
      _usageGranted = usage;
      _overlayGranted = overlay;
      _notifGranted = notif;
    });
  }

  bool get _allGranted => _usageGranted && _overlayGranted && _notifGranted;

  void _openUsageSettings() {
    _platform.invokeMethod('openUsageSettings');
  }

  void _openOverlaySettings() {
    _platform.invokeMethod('openOverlaySettings');
  }

  Future<void> _requestNotif() async {
    await Permission.notification.request();
    await _checkAll();
  }

  void _proceed() {
    if (_allGranted) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('🛡️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('FocusLock needs\na few permissions',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(height: 1.2)),
              const SizedBox(height: 8),
              Text(
                'These are required for the app to track and block your social media usage.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              _PermissionTile(
                emoji: '📊',
                title: 'Usage Access',
                description: 'Lets FocusLock see how long you\'ve spent on each app.',
                isGranted: _usageGranted,
                onTap: _openUsageSettings,
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _PermissionTile(
                emoji: '🪟',
                title: 'Display Over Other Apps',
                description: 'Allows FocusLock to show the blocking screen on top of social media apps.',
                isGranted: _overlayGranted,
                onTap: _openOverlaySettings,
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _PermissionTile(
                emoji: '🔔',
                title: 'Notifications',
                description: 'Sends usage alerts before your limit is reached.',
                isGranted: _notifGranted,
                onTap: _requestNotif,
                isRequired: false,
              ),
              const Spacer(),
              if (!_allGranted)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tap each permission and grant it, then return here.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.warning),
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
                ),
                child: Text(_allGranted ? 'Continue to Setup →' : 'Grant permissions to continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String emoji, title, description;
  final bool isGranted, isRequired;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.emoji,
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
          color: isGranted ? AppTheme.success.withOpacity(0.08) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted ? AppTheme.success.withOpacity(0.4) : AppTheme.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
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
