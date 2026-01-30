import 'package:flutter/material.dart';
import '../../../models/qa_models.dart';

/// Dialog for creating or editing a Responsibility Area
/// Supports both create (area == null) and edit (area != null) modes
class ResponsibilityAreaDialog extends StatefulWidget {
  final ResponsibilityArea? area;
  final String projectId;

  const ResponsibilityAreaDialog({
    super.key,
    this.area,
    required this.projectId,
  });

  @override
  State<ResponsibilityAreaDialog> createState() => _ResponsibilityAreaDialogState();
}

class _ResponsibilityAreaDialogState extends State<ResponsibilityAreaDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late final TextEditingController _areaNameController;
  late final TextEditingController _keywordsController;
  late final TextEditingController _internalContactController;
  late final TextEditingController _externalDisplayNameController;
  late final TextEditingController _contactMethodController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing data if editing
    _areaNameController = TextEditingController(text: widget.area?.areaName ?? '');
    _keywordsController = TextEditingController(
      text: widget.area?.areaKeywords.join(', ') ?? '',
    );
    _internalContactController = TextEditingController(
      text: widget.area?.internalContact ?? '',
    );
    _externalDisplayNameController = TextEditingController(
      text: widget.area?.externalDisplayName ?? '',
    );
    _contactMethodController = TextEditingController(
      text: widget.area?.contactMethod ?? '',
    );
    _notesController = TextEditingController(text: widget.area?.notes ?? '');
  }

  @override
  void dispose() {
    _areaNameController.dispose();
    _keywordsController.dispose();
    _internalContactController.dispose();
    _externalDisplayNameController.dispose();
    _contactMethodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Parse keywords (comma-separated)
    final keywords = _keywordsController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    if (keywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least one keyword'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create the responsibility area object
    final area = ResponsibilityArea(
      id: widget.area?.id,
      projectId: int.tryParse(widget.projectId),
      areaName: _areaNameController.text.trim(),
      areaKeywords: keywords,
      internalContact: _internalContactController.text.trim(),
      externalDisplayName: _externalDisplayNameController.text.trim(),
      contactMethod: _contactMethodController.text.trim().isNotEmpty
          ? _contactMethodController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      createdAt: widget.area?.createdAt,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(area);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.area != null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 28,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing
                              ? 'Edit Responsibility Area'
                              : 'New Responsibility Area',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Define who owns what in your project for automatic Q&A escalation',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Area Name
                  TextFormField(
                    controller: _areaNameController,
                    decoration: InputDecoration(
                      labelText: 'Area Name *',
                      hintText: 'e.g., UI/UX Design, Backend Engineering',
                      helperText: 'A descriptive name for this responsibility area',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an area name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Keywords
                  TextFormField(
                    controller: _keywordsController,
                    decoration: InputDecoration(
                      labelText: 'Keywords *',
                      hintText: 'ui, design, button, interface, ux',
                      helperText: 'Comma-separated keywords for topic matching',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.local_offer),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter at least one keyword';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Internal Contact
                  TextFormField(
                    controller: _internalContactController,
                    decoration: InputDecoration(
                      labelText: 'Internal Contact *',
                      hintText: 'alice@studio.com',
                      helperText: 'Email for internal team reference',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an internal contact email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // External Display Name
                  TextFormField(
                    controller: _externalDisplayNameController,
                    decoration: InputDecoration(
                      labelText: 'External Display Name *',
                      hintText: 'UI Lead, Backend Team',
                      helperText: 'Public-facing name shown to vendors/partners',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an external display name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Contact Method (Optional)
                  TextFormField(
                    controller: _contactMethodController,
                    decoration: InputDecoration(
                      labelText: 'Contact Method',
                      hintText: 'slack: #ui-questions, email: team@studio.com',
                      helperText: 'How to reach this team (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.chat),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Notes (Optional)
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Additional context about this responsibility area',
                      helperText: 'Internal notes (not shown to external users)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'When Q&A can\'t find answers, it will automatically escalate to the right team based on topic keywords.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: Icon(isEditing ? Icons.save : Icons.add),
                        label: Text(isEditing ? 'Save Changes' : 'Create Area'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
