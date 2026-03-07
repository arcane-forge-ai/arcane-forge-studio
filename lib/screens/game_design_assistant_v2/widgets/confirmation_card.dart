import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/confirmation.dart';
import '../providers/v2_session_provider.dart';

class ConfirmationCard extends StatelessWidget {
  final Confirmation confirmation;

  const ConfirmationCard({
    super.key,
    required this.confirmation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<V2SessionProvider>();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: colorScheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    confirmation.action,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (confirmation.goal.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Goal: ${confirmation.goal}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (confirmation.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
                child: Text(confirmation.reason),
              ),
            ],
            if (confirmation.preview != null &&
                confirmation.preview!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withOpacity(0.05),
                  border:
                      Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    confirmation.preview!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (provider.isConfirming)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: () =>
                        context.read<V2SessionProvider>().cancelTransaction(
                              transactionId: confirmation.transactionId,
                            ),
                    child: Text(confirmation.cancelText),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<V2SessionProvider>().confirmTransaction(
                              transactionId: confirmation.transactionId,
                            ),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(confirmation.confirmText),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
