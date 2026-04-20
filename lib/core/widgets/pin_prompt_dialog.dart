import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/settings_service.dart';

enum PinPromptResult {
  success,
  cancel,
  forgot,
}

Future<PinPromptResult> showPinPrompt(
  BuildContext context, {
  String title = 'Enter PIN',
  String subtitle = 'Enter your 6-digit PIN to continue.',
}) async {
  final result = await showDialog<PinPromptResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinPromptDialog(
      title: title,
      subtitle: subtitle,
    ),
  );

  return result ?? PinPromptResult.cancel;
}

class _PinPromptDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const _PinPromptDialog({
    required this.title,
    required this.subtitle,
  });

  @override
  State<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends State<_PinPromptDialog> {
  final _pinCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _service = SettingsService();
  String? _error;
  bool _isVerifying = false;
  bool _isClosing = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isVerifying || _isClosing) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    _focusNode.unfocus();

    final ok = await _service.verifyPin(_pinCtrl.text);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context, rootNavigator: true).pop(PinPromptResult.success);
      return;
    }

    setState(() {
      _isVerifying = false;
      _error = 'Incorrect PIN.';
    });
  }

  Future<void> _dismiss() async {
    if (_isClosing || _isVerifying) return;

    setState(() => _isClosing = true);
    _focusNode.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(PinPromptResult.cancel);
    }
  }

  void _forgotPin() {
    if (_isVerifying || _isClosing) return;
    Navigator.of(context, rootNavigator: true).pop(PinPromptResult.forgot);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          IconButton(
            onPressed: _dismiss,
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrl,
            focusNode: _focusNode,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'PIN (6 digits)',
              errorText: _error,
              counterText: '',
            ),
            onSubmitted: (_) => _focusNode.unfocus(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _forgotPin,
              child: const Text('Forgot PIN? Reset with OTP'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _dismiss,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
