import 'package:flutter/material.dart';

/// Widget to display an icon based on entry type
class EntryTypeIcon extends StatelessWidget {
  final String entryType;
  final double size;

  const EntryTypeIcon({
    Key? key,
    required this.entryType,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconData();
    final color = _getColor();

    return Icon(
      iconData,
      color: color,
      size: size,
    );
  }

  IconData _getIconData() {
    switch (entryType.toLowerCase()) {
      case 'document':
        return Icons.description;
      case 'link':
        return Icons.link;
      case 'contact':
        return Icons.person;
      case 'folder':
        return Icons.folder;
      case 'other':
        return Icons.notes;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColor() {
    switch (entryType.toLowerCase()) {
      case 'document':
        return Colors.blue;
      case 'link':
        return Colors.purple;
      case 'contact':
        return Colors.green;
      case 'folder':
        return Colors.orange;
      case 'other':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
