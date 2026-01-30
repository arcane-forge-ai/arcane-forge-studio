import 'package:flutter/material.dart';
import '../../game_design_assistant/models/api_models.dart';

/// Dialog for editing metadata of an existing knowledge base entry
class EditEntryMetadataDialog extends StatefulWidget {
  final KnowledgeBaseFile entry;

  const EditEntryMetadataDialog({
    Key? key,
    required this.entry,
  }) : super(key: key);

  @override
  State<EditEntryMetadataDialog> createState() => _EditEntryMetadataDialogState();
}

class _EditEntryMetadataDialogState extends State<EditEntryMetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  late String _visibility;
  late String _authorityLevel;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.entry.description ?? '';
    _tagsController.text = widget.entry.tags.join(', ');
    _visibility = widget.entry.visibility;
    _authorityLevel = widget.entry.authorityLevel;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Entry Metadata'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entry: ${widget.entry.documentName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                    hintText: 'tag1, tag2, tag3 (comma-separated)',
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
          onPressed: _saveChanges,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final updatedEntry = widget.entry.copyWith(
        visibility: _visibility,
        authorityLevel: _authorityLevel,
        tags: tags,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
      );

      Navigator.of(context).pop(updatedEntry);
    }
  }
}
