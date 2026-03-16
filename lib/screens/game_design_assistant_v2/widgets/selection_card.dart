import 'dart:async';

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
  bool _completed = false;
  String? _localError;
  String? _localInfo;
  Timer? _countdownTimer;

  bool get _expired => DateTime.now().isAfter(widget.selection.expiresAt);
  bool get _isSingle => !widget.selection.allowMultiple;
  int get _selectedCount => _selectedIds.length;

  @override
  void initState() {
    super.initState();
    _startCountdownTicker();
  }

  @override
  void didUpdateWidget(covariant SelectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection.questionId != widget.selection.questionId ||
        oldWidget.selection.expiresAt != widget.selection.expiresAt) {
      _startCountdownTicker();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_expired || _completed) {
        _countdownTimer?.cancel();
      }
      setState(() {});
    });
  }

  bool get _withinRange {
    if (_selectedCount < widget.selection.minSelection) return false;
    if (_selectedCount > widget.selection.maxSelection) return false;
    return true;
  }

  void _toggleOption(String id) {
    if (_expired || _completed) return;
    setState(() {
      _localError = null;
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

  Future<void> _submit() async {
    if (_expired) {
      setState(() {
        _localError = 'This selection has expired.';
      });
      return;
    }
    if (!_withinRange) {
      setState(() {
        _localError =
            'Please select ${widget.selection.minSelection}-${widget.selection.maxSelection} option(s).';
      });
      return;
    }

    final result = await context.read<V2SessionProvider>().submitSelection(
          selection: widget.selection,
          selectedIds: _selectedIds.toList(growable: false),
        );
    if (!mounted) return;
    setState(() {
      _localError = null;
      _localInfo = result.message;
      _completed = result.status == 'success';
      if (result.status == 'validation_error' || result.status == 'error') {
        _localError = result.message;
      }
    });
  }

  Future<void> _cancel() async {
    final result = await context
        .read<V2SessionProvider>()
        .cancelSelection(selection: widget.selection);
    if (!mounted) return;
    setState(() {
      _localError = result.status == 'error' ? result.message : null;
      _localInfo =
          result.status == 'error' ? null : (result.message ?? 'Skipped');
      _completed = result.status == 'success';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<V2SessionProvider>();
    final panelError = provider.selectionPanelError;
    final panelInfo = provider.selectionPanelInfo;
    final providerPending = provider.pendingSelection;
    final isOutdated = providerPending != null &&
        providerPending.questionId.isNotEmpty &&
        providerPending.questionId != widget.selection.questionId;
    final submitting = provider.isSubmittingSelection;
    final timeLeft = widget.selection.expiresAt.difference(DateTime.now());
    final secondsLeft = timeLeft.inSeconds.clamp(0, 999999);
    final canSubmit = !_expired && !_completed && !isOutdated && _withinRange;
    final min = widget.selection.minSelection;
    final max = widget.selection.maxSelection;

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
                Text(
                  _expired
                      ? 'Expired'
                      : 'Expires in ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _expired
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
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
            Text(
              _isSingle
                  ? 'Choose 1 option'
                  : 'Selected $_selectedCount ($min-$max required)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (isOutdated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'This question has been replaced by a newer one.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.error),
                ),
              ),
            if ((_localError ?? panelError ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _localError ?? panelError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.error),
                ),
              ),
            if ((_localInfo ?? panelInfo ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _localInfo ?? panelInfo!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            if (_completed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selection submitted.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      (_completed || submitting || isOutdated) ? null : _cancel,
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (submitting || !canSubmit) ? null : _submit,
                  child: submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
