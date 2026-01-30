import 'package:flutter/material.dart';
import '../../game_design_assistant/models/api_models.dart';

/// Dialog for adding a link entry to the knowledge base
class AddLinkDialog extends StatefulWidget {
  final KnowledgeBaseFile? existingEntry;

  const AddLinkDialog({Key? key, this.existingEntry}) : super(key: key);

  @override
  State<AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<AddLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  String _visibility = 'vendor_visible';
  String _authorityLevel = 'reference';

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _titleController.text = widget.existingEntry!.documentName;
      _urlController.text = widget.existingEntry!.url ?? '';
      _descriptionController.text = widget.existingEntry!.description ?? '';
      _tagsController.text = widget.existingEntry!.tags.join(', ');
      _visibility = widget.existingEntry!.visibility;
      _authorityLevel = widget.existingEntry!.authorityLevel;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingEntry == null ? 'Add Link' : 'Edit Link'),
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
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
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
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://example.com',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'URL is required';
                    }
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.hasScheme) {
                      return 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    hintText: 'Brief description of this link',
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
                    hintText: 'documentation, api, guide (comma-separated)',
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

      final entry = KnowledgeBaseFile(
        id: widget.existingEntry?.id ?? 0,
        documentName: _titleController.text.trim(),
        fileType: 'link',
        createdAt: widget.existingEntry?.createdAt ?? DateTime.now(),
        entryType: 'link',
        visibility: _visibility,
        authorityLevel: _authorityLevel,
        tags: tags,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        url: _urlController.text.trim(),
      );

      Navigator.of(context).pop(entry);
    }
  }
}
