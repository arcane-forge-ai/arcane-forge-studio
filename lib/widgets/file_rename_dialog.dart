import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FileRenameDialog extends StatefulWidget {
  final List<PlatformFile> files;

  const FileRenameDialog({
    Key? key,
    required this.files,
  }) : super(key: key);

  @override
  _FileRenameDialogState createState() => _FileRenameDialogState();
}

class _FileRenameDialogState extends State<FileRenameDialog> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, String> _fileExtensions;
  final Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _fileExtensions = {};

    for (final file in widget.files) {
      final fileName = file.name;
      final lastDotIndex = fileName.lastIndexOf('.');
      
      String nameWithoutExt;
      String extension;
      
      if (lastDotIndex != -1 && lastDotIndex > 0) {
        nameWithoutExt = fileName.substring(0, lastDotIndex);
        extension = fileName.substring(lastDotIndex); // includes the dot
      } else {
        nameWithoutExt = fileName;
        extension = '';
      }

      _controllers[file.path!] = TextEditingController(text: nameWithoutExt);
      _fileExtensions[file.path!] = extension;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _validateNames() {
    _errors.clear();
    
    // Check for empty names
    for (final entry in _controllers.entries) {
      final name = entry.value.text.trim();
      if (name.isEmpty) {
        _errors[entry.key] = 'Name cannot be empty';
      }
    }

    // Check for duplicate names (including extensions)
    final Map<String, List<String>> nameOccurrences = {};
    for (final entry in _controllers.entries) {
      final fullName = entry.value.text.trim() + _fileExtensions[entry.key]!;
      if (!nameOccurrences.containsKey(fullName)) {
        nameOccurrences[fullName] = [];
      }
      nameOccurrences[fullName]!.add(entry.key);
    }

    for (final entry in nameOccurrences.entries) {
      if (entry.value.length > 1) {
        for (final path in entry.value) {
          _errors[path] = 'Duplicate file name';
        }
      }
    }

    return _errors.isEmpty;
  }

  Map<String, String> _getFileNames() {
    final result = <String, String>{};
    for (final entry in _controllers.entries) {
      result[entry.key] = entry.value.text.trim() + _fileExtensions[entry.key]!;
    }
    return result;
  }

  void _onConfirm() {
    setState(() {
      if (_validateNames()) {
        Navigator.of(context).pop(_getFileNames());
      }
    });
  }

  void _onCancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Rename Files'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You can optionally rename the files before uploading them.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.files.length,
                itemBuilder: (context, index) {
                  final file = widget.files[index];
                  final controller = _controllers[file.path!]!;
                  final extension = _fileExtensions[file.path!]!;
                  final error = _errors[file.path!];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _getFileIcon(extension),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  labelText: 'File name ${index + 1}',
                                  suffixText: extension,
                                  suffixStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.bold,
                                  ),
                                  errorText: error,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (value) {
                                  // Clear error when user types
                                  if (error != null) {
                                    setState(() {
                                      _errors.remove(file.path!);
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (index == 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Original: ${file.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Upload'),
        ),
      ],
    );
  }

  Widget _getFileIcon(String extension) {
    IconData iconData;
    Color color;

    switch (extension.toLowerCase()) {
      case '.pdf':
        iconData = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case '.md':
        iconData = Icons.description;
        color = Colors.blue;
        break;
      case '.txt':
        iconData = Icons.text_snippet;
        color = Colors.grey;
        break;
      case '.doc':
      case '.docx':
        iconData = Icons.description;
        color = Colors.blue[700]!;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(iconData, color: color, size: 20);
  }
}


