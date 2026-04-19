import 'package:flutter/material.dart';

import '../../core/widgets/pin_prompt_dialog.dart';
import 'settings_screen.dart';

class SettingsAccessGateScreen extends StatefulWidget {
  const SettingsAccessGateScreen({super.key});

  @override
  State<SettingsAccessGateScreen> createState() => _SettingsAccessGateScreenState();
}

class _SettingsAccessGateScreenState extends State<SettingsAccessGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await showPinPrompt(
      context,
      title: 'Unlock Settings',
      subtitle: 'Enter your PIN before opening Settings.',
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}