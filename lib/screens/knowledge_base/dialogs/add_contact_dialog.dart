import 'package:flutter/material.dart';
import '../../game_design_assistant/models/api_models.dart';

/// Dialog for adding a contact entry to the knowledge base
class AddContactDialog extends StatefulWidget {
  final KnowledgeBaseFile? existingEntry;

  const AddContactDialog({Key? key, this.existingEntry}) : super(key: key);

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  final _contactMethodController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  String _visibility = 'vendor_visible';
  String _authorityLevel = 'reference';

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _nameController.text = widget.existingEntry!.documentName;
      
      // Parse description format: "Description\nEmail: xxx\nPhone: xxx\nRole: xxx\nContact Method: xxx"
      if (widget.existingEntry!.description != null && widget.existingEntry!.description!.isNotEmpty) {
        _parseContactDescription(widget.existingEntry!.description!);
      } else {
        // Fallback to contactInfo if description parsing fails
        _emailController.text = widget.existingEntry!.contactInfo?['email'] ?? '';
        _roleController.text = widget.existingEntry!.contactInfo?['role'] ?? '';
        _contactMethodController.text = widget.existingEntry!.contactInfo?['method'] ?? '';
      }
      
      _tagsController.text = widget.existingEntry!.tags.join(', ');
      _visibility = widget.existingEntry!.visibility;
      _authorityLevel = widget.existingEntry!.authorityLevel;
    }
  }
  
  void _parseContactDescription(String description) {
    final lines = description.split('\n');
    String descriptionText = '';
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.startsWith('Email:')) {
        _emailController.text = line.substring(6).trim();
      } else if (line.startsWith('Phone:')) {
        // Skip phone field for now as we don't have a controller for it
      } else if (line.startsWith('Role:')) {
        _roleController.text = line.substring(5).trim();
      } else if (line.startsWith('Contact Method:')) {
        _contactMethodController.text = line.substring(15).trim();
      } else if (line.isNotEmpty) {
        // First non-metadata line(s) are the description
        if (descriptionText.isNotEmpty) {
          descriptionText += '\n';
        }
        descriptionText += line;
      }
    }
    
    _descriptionController.text = descriptionText;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _contactMethodController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingEntry == null ? 'Add Contact' : 'Edit Contact'),
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
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    hintText: 'name@example.com',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // More flexible email regex supporting modern TLDs (2+ characters)
                      final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _roleController,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                    hintText: 'UI Lead, Backend Engineer, etc.',
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _contactMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Method',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_phone),
                    hintText: 'slack: #ui-questions, email, phone, etc.',
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    hintText: 'Additional notes about this contact',
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
                    hintText: 'ui, backend, support (comma-separated)',
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

      // Build description in the format: "Description\nEmail: xxx\nPhone: xxx\nRole: xxx\nContact Method: xxx"
      final descriptionParts = <String>[];
      
      // Add description text first
      if (_descriptionController.text.trim().isNotEmpty) {
        descriptionParts.add(_descriptionController.text.trim());
      }
      
      // Add structured contact fields
      if (_emailController.text.trim().isNotEmpty) {
        descriptionParts.add('Email: ${_emailController.text.trim()}');
      }
      
      if (_roleController.text.trim().isNotEmpty) {
        descriptionParts.add('Role: ${_roleController.text.trim()}');
      }
      
      if (_contactMethodController.text.trim().isNotEmpty) {
        descriptionParts.add('Contact Method: ${_contactMethodController.text.trim()}');
      }
      
      final formattedDescription = descriptionParts.isEmpty 
          ? null 
          : descriptionParts.join('\n');

      // Also build contactInfo map for backward compatibility
      final contactInfo = <String, String>{};
      if (_emailController.text.trim().isNotEmpty) {
        contactInfo['email'] = _emailController.text.trim();
      }
      if (_roleController.text.trim().isNotEmpty) {
        contactInfo['role'] = _roleController.text.trim();
      }
      if (_contactMethodController.text.trim().isNotEmpty) {
        contactInfo['method'] = _contactMethodController.text.trim();
      }

      final entry = KnowledgeBaseFile(
        id: widget.existingEntry?.id ?? 0,
        documentName: _nameController.text.trim(),
        fileType: 'contact',
        createdAt: widget.existingEntry?.createdAt ?? DateTime.now(),
        entryType: 'contact',
        visibility: _visibility,
        authorityLevel: _authorityLevel,
        tags: tags,
        description: formattedDescription,
        contactInfo: contactInfo.isEmpty ? null : contactInfo,
      );

      Navigator.of(context).pop(entry);
    }
  }
}
