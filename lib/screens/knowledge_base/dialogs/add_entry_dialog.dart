import 'package:flutter/material.dart';
import '../../game_design_assistant/models/api_models.dart';
import 'add_link_dialog.dart';
import 'add_contact_dialog.dart';
import 'add_other_entry_dialog.dart';

/// Main dialog for selecting and creating different types of knowledge base entries
class AddEntryDialog extends StatefulWidget {
  const AddEntryDialog({Key? key}) : super(key: key);

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  String _selectedType = 'link';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Knowledge Base Entry'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select entry type:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip(
                  icon: Icons.link,
                  label: 'Link',
                  value: 'link',
                  color: Colors.blue,
                ),
                _buildTypeChip(
                  icon: Icons.person,
                  label: 'Contact',
                  value: 'contact',
                  color: Colors.green,
                ),
                _buildTypeChip(
                  icon: Icons.folder,
                  label: 'Folder',
                  value: 'folder',
                  color: Colors.orange,
                ),
                _buildTypeChip(
                  icon: Icons.notes,
                  label: 'Other',
                  value: 'other',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _openTypeSpecificDialog,
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildTypeChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : color,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedType = value;
          });
        }
      },
      selectedColor: color,
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _openTypeSpecificDialog() async {
    // Save navigator and context before popping
    final navigator = Navigator.of(context);
    final parentContext = context;
    
    navigator.pop();

    // Wait for dialog close animation to complete
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;

    KnowledgeBaseFile? entry;
    switch (_selectedType) {
      case 'link':
        entry = await showDialog<KnowledgeBaseFile>(
          context: parentContext,
          builder: (context) => const AddLinkDialog(),
        );
        break;
      case 'contact':
        entry = await showDialog<KnowledgeBaseFile>(
          context: parentContext,
          builder: (context) => const AddContactDialog(),
        );
        break;
      case 'folder':
        entry = await showDialog<KnowledgeBaseFile>(
          context: parentContext,
          builder: (context) => AddOtherEntryDialog(entryType: 'folder'),
        );
        break;
      case 'other':
        entry = await showDialog<KnowledgeBaseFile>(
          context: parentContext,
          builder: (context) => AddOtherEntryDialog(entryType: 'other'),
        );
        break;
    }

    if (entry != null && mounted) {
      Navigator.of(parentContext).pop(entry);
    }
  }
}
