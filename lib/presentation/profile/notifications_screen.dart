import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/notification_service.dart';
import '../../providers/settings_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, String>? _diag;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshDiagnostics();
  }

  Future<void> _refreshDiagnostics() async {
    setState(() => _loading = true);
    final d = await NotificationService().getNotificationDiagnostics();
    if (!mounted) return;
    setState(() {
      _diag = d;
      _loading = false;
    });
  }

  Future<void> _preview() async {
    await NotificationService().showPreviewNotification(
      title: 'FocusLock Preview',
      body: 'This is how FocusLock notifications appear.',
    );
    await _refreshDiagnostics();
  }

  Future<void> _requestPermissions() async {
    await NotificationService().requestPermission();
    await _refreshDiagnostics();
  }

  Future<void> _setAppNotifications(SettingsProvider sp, bool enabled) async {
    await sp.update(sp.settings.copyWith(notificationsEnabled: enabled));
    await _refreshDiagnostics();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();

    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Notification Center')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _diagCard(),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.divider),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('App notifications', style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                  'Controls FocusLock app notifications.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: sp.settings.notificationsEnabled,
                onChanged: (v) => _setAppNotifications(sp, v),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _requestPermissions,
              child: const Text('Request Notification Permission Again'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _preview,
              child: const Text('Send Preview Notification'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _refreshDiagnostics,
              child: const Text('Refresh Diagnostics'),
            ),
            const SizedBox(height: 14),
            Text(
              'Tip: if notifications do not show, check app notification permission and channel settings.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagCard() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final d = _diag ?? const <String, String>{};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notification diagnostics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _diagLine('Permission', d['permission'] ?? 'Unknown'),
          _diagLine('App notifications', d['appNotificationsEnabled'] ?? 'Yes'),
          _diagLine('Local timezone', d['localTimezone'] ?? 'Unknown'),
          _diagLine('Pending scheduled count', d['pendingCount'] ?? '0'),
        ],
      ),
    );
  }

  Widget _diagLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
