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
  late List<TextEditingController> _controllers;
  late List<String> _fileExtensions;
  final Map<int, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _controllers = [];
    _fileExtensions = [];

    for (final file in widget.files) {
      final fileName = file.name;
      final lastDotIndex = fileName.lastIndexOf('.');

      final nameWithoutExt =
          lastDotIndex > 0 ? fileName.substring(0, lastDotIndex) : fileName;
      final extension = lastDotIndex > 0 ? fileName.substring(lastDotIndex) : '';

      _controllers.add(TextEditingController(text: nameWithoutExt));
      _fileExtensions.add(extension);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _validateNames() {
    _errors.clear();
    
    for (var i = 0; i < _controllers.length; i++) {
      final name = _controllers[i].text.trim();
      if (name.isEmpty) {
        _errors[i] = 'Name cannot be empty';
      }
    }

    final Map<String, List<int>> nameOccurrences = {};
    for (var i = 0; i < _controllers.length; i++) {
      final fullName = _controllers[i].text.trim() + _fileExtensions[i];
      nameOccurrences.putIfAbsent(fullName, () => []).add(i);
    }

    for (final entry in nameOccurrences.entries) {
      if (entry.value.length > 1) {
        for (final index in entry.value) {
          _errors[index] = 'Duplicate file name';
        }
      }
    }

    return _errors.isEmpty;
  }

  List<String> _getFileNames() {
    return List.generate(
      _controllers.length,
      (index) => _controllers[index].text.trim() + _fileExtensions[index],
    );
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
                  final controller = _controllers[index];
                  final extension = _fileExtensions[index];
                  final error = _errors[index];

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


