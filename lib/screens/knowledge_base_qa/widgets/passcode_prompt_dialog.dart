import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PasscodePromptDialog extends StatefulWidget {
  final String projectId;
  final Function(String) onSubmit;

  const PasscodePromptDialog({
    super.key,
    required this.projectId,
    required this.onSubmit,
  });

  @override
  State<PasscodePromptDialog> createState() => _PasscodePromptDialogState();
}

class _PasscodePromptDialogState extends State<PasscodePromptDialog> {
  final _passcodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePasscode = true;

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_passcodeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the access code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(_passcodeController.text.trim());
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid access code. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 28,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Enter Access Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This project\'s Q&A requires an access code. Please enter it below to continue.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passcodeController,
              obscureText: _obscurePasscode,
              decoration: InputDecoration(
                labelText: 'Access Code',
                hintText: 'Enter the code',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePasscode ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePasscode = !_obscurePasscode;
                    });
                  },
                ),
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _submit(),
              autofocus: true,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => context.go('/'),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
