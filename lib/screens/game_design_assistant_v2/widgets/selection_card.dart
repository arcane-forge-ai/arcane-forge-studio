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
  bool _invalidated = false;
  String? _localError;
  String? _localInfo;
  Timer? _countdownTimer;

  bool get _expired => DateTime.now().isAfter(widget.selection.expiresAt);
  bool get _isSingle => !widget.selection.allowMultiple;
  int get _selectedCount => _selectedIds.length;
  bool get _hasReachedMaxSelection =>
      widget.selection.allowMultiple &&
      _selectedCount >= widget.selection.maxSelection;

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
      _selectedIds.clear();
      _completed = false;
      _invalidated = false;
      _localError = null;
      _localInfo = null;
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
      if (_expired || _completed || _invalidated) {
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
    if (_expired || _completed || _invalidated) return;
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
      final invalidated =
          result.status == 'expired' || result.status == 'stale';
      if (invalidated) {
        _selectedIds.clear();
      }
      _localError = null;
      _localInfo = invalidated ? null : result.message;
      _completed = result.status == 'success';
      _invalidated = invalidated;
      if (invalidated ||
          result.status == 'validation_error' ||
          result.status == 'error') {
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
      final invalidated =
          result.status == 'expired' || result.status == 'stale';
      if (invalidated) {
        _selectedIds.clear();
      }
      _localError =
          result.status == 'error' || invalidated ? result.message : null;
      _localInfo = result.status == 'error' || invalidated
          ? null
          : (result.message ?? 'Skipped');
      _completed = result.status == 'success';
      _invalidated = invalidated;
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
    final canSubmit = !_expired &&
        !_completed &&
        !_invalidated &&
        !isOutdated &&
        _withinRange;
    final isDisabled = _expired || _completed || _invalidated || isOutdated;
    final infoText = _completed ? null : (_localInfo ?? panelInfo);
    final min = widget.selection.minSelection;
    final max = widget.selection.maxSelection;

    return Opacity(
      opacity: isDisabled ? 0.58 : 1,
      child: Card(
        margin: const EdgeInsets.only(top: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _expired
                ? colorScheme.outline.withValues(alpha: 0.35)
                : colorScheme.outline.withValues(alpha: 0.2),
          ),
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
              if (_expired)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '该选择已过期，可直接在输入框继续，或让助手重新给一个选择题。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ...widget.selection.options.map((option) {
                final isSelected = _selectedIds.contains(option.id);
                final optionEnabled =
                    !isDisabled && (!_hasReachedMaxSelection || isSelected);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !optionEnabled && !isSelected
                          ? colorScheme.outline.withValues(alpha: 0.14)
                          : isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.06)
                        : !optionEnabled
                            ? colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.28)
                            : null,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap:
                        optionEnabled ? () => _toggleOption(option.id) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          if (widget.selection.allowMultiple)
                            Checkbox(
                              value: isSelected,
                              onChanged: optionEnabled
                                  ? (_) => _toggleOption(option.id)
                                  : null,
                            )
                          else
                            Radio<String>(
                              value: option.id,
                              groupValue: _selectedIds.isEmpty
                                  ? null
                                  : _selectedIds.first,
                              onChanged: optionEnabled
                                  ? (_) => _toggleOption(option.id)
                                  : null,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: optionEnabled || isSelected
                                        ? null
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if ((option.description ?? '').isNotEmpty)
                                  Text(
                                    option.description!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: optionEnabled || isSelected
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.75),
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
                _isSingle ? 'Choose 1 option' : 'Select $min-$max options',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.selection.allowMultiple && _hasReachedMaxSelection)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Up to $max options can be selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
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
              if ((infoText ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    infoText!,
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
                    onPressed: (_completed ||
                            submitting ||
                            isOutdated ||
                            _expired ||
                            _invalidated)
                        ? null
                        : _cancel,
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
      ),
    );
  }
}
