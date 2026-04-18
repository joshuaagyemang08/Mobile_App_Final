import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene_background.dart';
import '../../data/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _wake = true;
  bool _sleep = true;
  bool _tips = true;

  Future<void> _preview() async {
    await NotificationService().showPreviewNotification(
      title: 'FocusLock Preview',
      body: 'This is how your reminders will appear.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preview notification sent.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Notification Center')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _switchTile(
              title: 'Wake-up alarm',
              subtitle: 'Reminder at your wake time',
              value: _wake,
              onChanged: (v) => setState(() => _wake = v),
            ),
            const SizedBox(height: 10),
            _switchTile(
              title: 'Sleep reminder',
              subtitle: 'Reminder at your sleep time',
              value: _sleep,
              onChanged: (v) => setState(() => _sleep = v),
            ),
            const SizedBox(height: 10),
            _switchTile(
              title: 'Motivation tips',
              subtitle: 'Small nudges during the day',
              value: _tips,
              onChanged: (v) => setState(() => _tips = v),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _preview,
              child: const Text('Send Preview Notification'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.divider),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
