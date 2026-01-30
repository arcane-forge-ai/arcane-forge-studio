import 'package:flutter/material.dart';
import '../../game_design_assistant/models/api_models.dart';

/// Dialog for adding folder or other entry types to the knowledge base
class AddOtherEntryDialog extends StatefulWidget {
  final String entryType; // 'folder' or 'other'
  final KnowledgeBaseFile? existingEntry;

  const AddOtherEntryDialog({
    Key? key,
    required this.entryType,
    this.existingEntry,
  }) : super(key: key);

  @override
  State<AddOtherEntryDialog> createState() => _AddOtherEntryDialogState();
}

class _AddOtherEntryDialogState extends State<AddOtherEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  String _visibility = 'vendor_visible';
  String _authorityLevel = 'reference';

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _titleController.text = widget.existingEntry!.documentName;
      _contentController.text = widget.existingEntry!.metadata?['content'] ?? '';
      _descriptionController.text = widget.existingEntry!.description ?? '';
      _tagsController.text = widget.existingEntry!.tags.join(', ');
      _visibility = widget.existingEntry!.visibility;
      _authorityLevel = widget.existingEntry!.authorityLevel;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String get _dialogTitle {
    if (widget.existingEntry != null) {
      return widget.entryType == 'folder' ? 'Edit Folder' : 'Edit Entry';
    }
    return widget.entryType == 'folder' ? 'Add Folder' : 'Add Other Entry';
  }

  IconData get _icon {
    return widget.entryType == 'folder' ? Icons.folder : Icons.notes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_dialogTitle),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(_icon),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content / Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.text_fields),
                    hintText: 'Additional information or notes',
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    hintText: 'Brief description',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                    hintText: 'category, topic (comma-separated)',
                  ),
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'Visibility',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Vendor Visible'),
                      selected: _visibility == 'vendor_visible',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _visibility = 'vendor_visible');
                        }
                      },
                      avatar: const Icon(Icons.visibility, size: 18),
                    ),
                    ChoiceChip(
                      label: const Text('Internal Only'),
                      selected: _visibility == 'internal_only',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _visibility = 'internal_only');
                        }
                      },
                      avatar: const Icon(Icons.lock, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'Authority Level',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Source of Truth'),
                      selected: _authorityLevel == 'source_of_truth',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _authorityLevel = 'source_of_truth');
                        }
                      },
                      avatar: const Icon(Icons.star, size: 18),
                    ),
                    ChoiceChip(
                      label: const Text('Reference'),
                      selected: _authorityLevel == 'reference',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _authorityLevel = 'reference');
                        }
                      },
                      avatar: const Icon(Icons.book, size: 18),
                    ),
                    ChoiceChip(
                      label: const Text('Deprecated'),
                      selected: _authorityLevel == 'deprecated',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _authorityLevel = 'deprecated');
                        }
                      },
                      avatar: const Icon(Icons.warning, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveEntry,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveEntry() {
    if (_formKey.currentState!.validate()) {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final metadata = _contentController.text.trim().isEmpty
          ? null
          : {'content': _contentController.text.trim()};

      final entry = KnowledgeBaseFile(
        id: widget.existingEntry?.id ?? 0,
        documentName: _titleController.text.trim(),
        fileType: widget.entryType,
        createdAt: widget.existingEntry?.createdAt ?? DateTime.now(),
        entryType: widget.entryType,
        visibility: _visibility,
        authorityLevel: _authorityLevel,
        tags: tags,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        metadata: metadata,
      );

      Navigator.of(context).pop(entry);
    }
  }
}
