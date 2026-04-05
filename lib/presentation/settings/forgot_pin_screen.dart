import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _answerCtrl = TextEditingController();
  final _answerCtrl2 = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _step2 = false; // step1 = verify answer, step2 = new PIN
  bool _loading = false;

  @override
  void dispose() {
    _answerCtrl.dispose();
    _answerCtrl2.dispose();
    _newPinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAnswer() async {
    setState(() { _loading = true; _error = null; });
    final sp = context.read<SettingsProvider>();
    final ok1 = await sp.verifySecurityAnswer(_answerCtrl.text.trim());
    final ok2 = await sp.verifySecurityAnswer2(_answerCtrl2.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok1 && ok2) {
      setState(() => _step2 = true);
    } else {
      setState(() => _error = 'Both answers must match. Please try again.');
    }
  }

  Future<void> _setNewPin() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_newPinCtrl.text)) {
      setState(() => _error = 'PIN must be exactly ${AppConstants.pinLength} digits.');
      return;
    }
    if (_newPinCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final sp = context.read<SettingsProvider>();
    await sp.savePin(_newPinCtrl.text);
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN reset successfully! 🎉'), backgroundColor: AppTheme.success),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final question = sp.settings.securityQuestion;
    final question2 = sp.settings.securityQuestion2;

    return Scaffold(
      appBar: AppBar(title: const Text('Recover PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🔑', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PIN Recovery', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          _step2
                              ? 'Identity verified. Set your new PIN below.'
                              : 'Answer both security questions to reset your PIN.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (!_step2) ...[
              // Step 1: verify security answer
              Text('Security Question 1', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Text(question.isEmpty ? 'No security question set.' : question,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        )),
              ),
              const SizedBox(height: 20),
              Text('Security Question 2', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Text(question2.isEmpty ? 'No second security question set.' : question2,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        )),
              ),
              const SizedBox(height: 20),
              if (question.isEmpty || question2.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Security questions were not fully configured. Please update them in Settings.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.danger),
                  ),
                )
              else ...[
                TextField(
                  controller: _answerCtrl,
                  decoration: InputDecoration(
                    labelText: 'Answer 1',
                    errorText: _error,
                    hintText: 'Answer is not case-sensitive',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _answerCtrl2,
                  decoration: InputDecoration(
                    labelText: 'Answer 2',
                    errorText: _error,
                    hintText: 'Answer is not case-sensitive',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyAnswer,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Verify Answer'),
                ),
              ],
            ] else ...[
              // Step 2: set new PIN
              const Text('✅', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Identity Verified', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.success)),
              const SizedBox(height: 24),
              TextField(
                controller: _newPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.pinLength,
                decoration: const InputDecoration(labelText: 'New PIN (6 digits)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.pinLength,
                decoration: InputDecoration(labelText: 'Confirm new PIN (6 digits)', errorText: _error),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _setNewPin,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Set New PIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
