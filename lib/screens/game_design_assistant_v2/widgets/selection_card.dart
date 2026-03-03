import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/selection.dart';
import '../providers/v2_session_provider.dart';

class SelectionCard extends StatefulWidget {
  final SelectionInfo selection;

  const SelectionCard({
    super.key,
    required this.selection,
  });

  @override
  State<SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<SelectionCard> {
  final Set<String> _selectedIds = <String>{};

  void _toggleOption(String id) {
    setState(() {
      if (widget.selection.allowMultiple) {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else if (_selectedIds.length < widget.selection.maxSelection) {
          _selectedIds.add(id);
        }
      } else {
        _selectedIds
          ..clear()
          ..add(id);
      }
    });
  }

  void _submit() {
    if (_selectedIds.isEmpty) return;
    context
        .read<V2SessionProvider>()
        .sendMessage('Selected: ${_selectedIds.join(',')}');
  }

  void _cancel() {
    context.read<V2SessionProvider>().sendMessage('cancel');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(top: 8),
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
                Icon(Icons.checklist_rounded, color: colorScheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.selection.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if ((widget.selection.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.selection.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...widget.selection.options.map((option) {
              final isSelected = _selectedIds.contains(option.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  color:
                      isSelected ? colorScheme.primary.withOpacity(0.06) : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _toggleOption(option.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (widget.selection.allowMultiple)
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleOption(option.id),
                          )
                        else
                          Radio<String>(
                            value: option.id,
                            groupValue: _selectedIds.isEmpty
                                ? null
                                : _selectedIds.first,
                            onChanged: (_) => _toggleOption(option.id),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              if ((option.description ?? '').isNotEmpty)
                                Text(
                                  option.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _cancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _submit,
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
