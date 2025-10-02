import 'package:flutter/material.dart';
import '../models/feedback_analysis_models.dart';

class MutationEditDialog extends StatefulWidget {
  final MutationBrief? mutation; // null for creating new mutation
  final String runId;
  final Future<bool> Function(Map<String, dynamic>)? onSaved;

  const MutationEditDialog({
    Key? key,
    this.mutation,
    required this.runId,
    this.onSaved,
  }) : super(key: key);

  @override
  State<MutationEditDialog> createState() => _MutationEditDialogState();
}

class _MutationEditDialogState extends State<MutationEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _rationaleController = TextEditingController();
  final _changesController = TextEditingController();
  final _noveltyController = TextEditingController();
  
  int? _impact;
  int? _effort;

  @override
  void initState() {
    super.initState();
    if (widget.mutation != null) {
      _titleController.text = widget.mutation!.title;
      _rationaleController.text = widget.mutation!.rationale ?? '';
      _changesController.text = widget.mutation!.changes?.join('\n') ?? '';
      _noveltyController.text = widget.mutation!.novelty ?? '';
      _impact = widget.mutation!.impact;
      _effort = widget.mutation!.effort;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rationaleController.dispose();
    _changesController.dispose();
    _noveltyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.mutation != null;
    
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 800,
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isEditing ? Icons.edit : Icons.add,
                  color: const Color(0xFFFF6B35),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Mutation Brief' : 'Create New Mutation Brief',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      _buildTextField(
                        controller: _titleController,
                        label: 'Title',
                        hint: 'Enter mutation brief title',
                        required: true,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      
                      // Rationale field
                      _buildTextField(
                        controller: _rationaleController,
                        label: 'Rationale',
                        hint: 'Explain why this mutation is needed',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      
                      // Changes field
                      _buildTextField(
                        controller: _changesController,
                        label: 'Proposed Changes',
                        hint: 'List the changes (one per line)',
                        maxLines: 6,
                        helperText: 'Enter each change on a new line',
                      ),
                      const SizedBox(height: 16),
                      
                      // Impact and Effort row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Impact',
                              value: _impact,
                              items: List.generate(5, (i) => i + 1),
                              onChanged: (value) => setState(() => _impact = value),
                              hint: 'Select impact level',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Effort',
                              value: _effort,
                              items: List.generate(5, (i) => i + 1),
                              onChanged: (value) => setState(() => _effort = value),
                              hint: 'Select effort level',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Novelty field
                      _buildTextField(
                        controller: _noveltyController,
                        label: 'Novelty',
                        hint: 'Describe the novelty level (e.g., Low, Medium, High, Revolutionary)',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveMutation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(isEditing ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (required ? ' *' : ''),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            helperText: helperText,
            helperStyle: const TextStyle(color: Colors.white54, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
          ),
          dropdownColor: const Color(0xFF2A2A2A),
        ),
      ],
    );
  }

  Future<void> _saveMutation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final changes = _changesController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final mutationData = {
      'title': _titleController.text.trim(),
      'rationale': _rationaleController.text.trim().isEmpty 
          ? null 
          : _rationaleController.text.trim(),
      'changes': changes.isEmpty ? null : changes,
      'impact': _impact,
      'effort': _effort,
      'novelty': _noveltyController.text.trim().isEmpty 
          ? null 
          : _noveltyController.text.trim(),
      'runId': widget.runId,
    };

    if (widget.onSaved != null) {
      final success = await widget.onSaved!(mutationData);
      if (success) {
        // Close dialog only on success
        if (mounted) Navigator.of(context).pop(true);
      }
    } else {
      // Fallback: return data if no callback provided
      Navigator.of(context).pop(mutationData);
    }
  }
}
