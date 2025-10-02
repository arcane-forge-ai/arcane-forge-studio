import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../providers/settings_provider.dart';
import '../models/extracted_asset_models.dart';
import '../screens/game_design_assistant/models/api_models.dart';
import '../screens/game_design_assistant/services/chat_api_service.dart';

/// Generic interface for providers that support asset creation from documents
abstract class AssetCreationProvider {
  Future<List<ExtractedAsset>> extractAssetsFromContent(String content);
  Future<void> batchCreateAssets(String projectId, List<ExtractedAsset> extractedAssets);
  Future<void> refreshAssets({String? projectId});
}

/// Reusable dialog for creating assets from documents
/// Can be used by both Image and SFX asset providers
class CreateAssetsFromDocDialog extends StatefulWidget {
  final String projectId;
  final VoidCallback onAssetsCreated;
  final AssetCreationProvider provider;
  final String assetType; // 'image' or 'sfx'

  const CreateAssetsFromDocDialog({
    Key? key,
    required this.projectId,
    required this.onAssetsCreated,
    required this.provider,
    required this.assetType,
  }) : super(key: key);

  @override
  State<CreateAssetsFromDocDialog> createState() => _CreateAssetsFromDocDialogState();
}

class _CreateAssetsFromDocDialogState extends State<CreateAssetsFromDocDialog> {
  late final ChatApiService _chatApiService;
  bool _isLoading = false;
  bool _isExtracting = false;
  bool _isCreating = false;
  List<KnowledgeBaseFile> _knowledgeBaseFiles = [];
  List<ExtractedAsset> _extractedAssets = [];
  List<EditableExtractedAsset> _editableAssets = [];
  Map<int, bool> _selectedAssets = {};
  String _documentContent = '';
  String _selectedSource = 'knowledge_base'; // 'knowledge_base' or 'local'
  
  // Controllers for editing
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _descriptionControllers = {};
  final Map<int, TextEditingController> _tagsControllers = {};
  final Map<int, TextEditingController> _metadataControllers = {};

  bool get _isAnyOperationInProgress => _isLoading || _isExtracting || _isCreating;

  @override
  void initState() {
    super.initState();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _chatApiService = ChatApiService(settingsProvider: settingsProvider);
    _loadKnowledgeBaseFiles();
  }

  @override
  void dispose() {
    // Dispose all text controllers
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _descriptionControllers.values) {
      controller.dispose();
    }
    for (final controller in _tagsControllers.values) {
      controller.dispose();
    }
    for (final controller in _metadataControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadKnowledgeBaseFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _chatApiService.getKnowledgeBaseFiles(widget.projectId);
      setState(() {
        _knowledgeBaseFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading knowledge base files: $e');
    }
  }

  Future<void> _pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        setState(() {
          _documentContent = content;
          _selectedSource = 'local';
        });
        _extractAssets();
      }
    } catch (e) {
      _showErrorSnackBar('Error reading local file: $e');
    }
  }

  Future<void> _selectKnowledgeBaseFile(KnowledgeBaseFile file) async {
    setState(() {
      _selectedSource = 'knowledge_base';
      _isExtracting = true; // Show loading state while downloading
    });

    try {
      // Get file download URL from API
      final downloadResponse = await _chatApiService.getFileDownloadUrl(widget.projectId, file.id);
      if (downloadResponse == null) {
        setState(() {
          _isExtracting = false;
        });
        _showErrorSnackBar('Failed to get download URL for ${file.documentName}');
        return;
      }

      // Download file content using dio
      final dio = Dio();
      final response = await dio.get(
        downloadResponse.downloadUrl,
        options: Options(
          responseType: ResponseType.plain, // Get as text
          receiveTimeout: const Duration(minutes: 2), // 2 minute timeout
        ),
      );

      // Set the document content and extract assets
      final content = response.data as String;
      setState(() {
        _documentContent = content;
      });
      
      // Extract assets from the downloaded content
      await _extractAssets();
      
    } catch (e) {
      setState(() {
        _isExtracting = false;
      });
      
      String errorMessage = 'Error loading file content: ';
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage += 'Download timed out. Please try again.';
            break;
          case DioExceptionType.connectionError:
            errorMessage += 'Network connection error.';
            break;
          default:
            errorMessage += e.message ?? 'Unknown network error';
        }
      } else {
        errorMessage += e.toString();
      }
      _showErrorSnackBar(errorMessage);
    }
  }

  Future<void> _extractAssets() async {
    if (_documentContent.isEmpty) return;

    setState(() {
      _isExtracting = true;
    });

    try {
      final assets = await widget.provider.extractAssetsFromContent(_documentContent);
      
      // Create editable assets and text controllers
      final editableAssets = <EditableExtractedAsset>[];
      _nameControllers.clear();
      _descriptionControllers.clear();
      _tagsControllers.clear();
      _metadataControllers.clear();
      
      for (int i = 0; i < assets.length; i++) {
        final editableAsset = EditableExtractedAsset.fromExtractedAsset(assets[i]);
        editableAssets.add(editableAsset);
        
        _nameControllers[i] = TextEditingController(text: editableAsset.name);
        _descriptionControllers[i] = TextEditingController(text: editableAsset.description);
        _tagsControllers[i] = TextEditingController(text: editableAsset.tagsAsString);
        _metadataControllers[i] = TextEditingController(text: editableAsset.metadataAsString);
      }
      
      setState(() {
        _extractedAssets = assets;
        _editableAssets = editableAssets;
        _selectedAssets = {for (int i = 0; i < assets.length; i++) i: true}; // Select all by default
        _isExtracting = false;
      });
    } catch (e) {
      setState(() {
        _isExtracting = false;
      });
      _showErrorSnackBar('Error extracting assets: $e');
    }
  }

  Future<void> _createSelectedAssets() async {
    // Update editable assets with current text field values
    for (int i = 0; i < _editableAssets.length; i++) {
      if (_nameControllers[i] != null) {
        _editableAssets[i].name = _nameControllers[i]!.text;
      }
      if (_descriptionControllers[i] != null) {
        _editableAssets[i].description = _descriptionControllers[i]!.text;
      }
      if (_tagsControllers[i] != null) {
        _editableAssets[i].tagsAsString = _tagsControllers[i]!.text;
      }
      if (_metadataControllers[i] != null) {
        _editableAssets[i].metadataAsString = _metadataControllers[i]!.text;
      }
    }

    // Get selected assets with edited values
    final selectedAssets = _editableAssets
        .asMap()
        .entries
        .where((entry) => _selectedAssets[entry.key] == true)
        .map((entry) => entry.value.toExtractedAsset())
        .toList();

    if (selectedAssets.isEmpty) {
      _showErrorSnackBar('Please select at least one asset to create');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      await widget.provider.batchCreateAssets(widget.projectId, selectedAssets);
      
      Navigator.of(context).pop();
      widget.onAssetsCreated();
      _showSuccessSnackBar('${selectedAssets.length} ${widget.assetType} assets created successfully!');
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      _showErrorSnackBar('Error creating assets: $e');
    }
  }

  void _toggleSelectAll() {
    final allSelected = _selectedAssets.values.every((selected) => selected);
    setState(() {
      for (int i = 0; i < _editableAssets.length; i++) {
        _selectedAssets[i] = !allSelected;
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create ${widget.assetType.toUpperCase()} Assets from Document',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_extractedAssets.isEmpty) ...[
                  _buildDocumentSelection(),
                ] else ...[
                  _buildExtractedAssets(),
                ],
              ],
            ),
            // Loading overlay
            if (_isAnyOperationInProgress)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF0078D4),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSelection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAnyOperationInProgress ? null : () => setState(() => _selectedSource = 'knowledge_base'),
                  icon: Icon(Icons.folder, color: _selectedSource == 'knowledge_base' ? Colors.white : Colors.white54),
                  label: Text(
                    'Select from Knowledge Base',
                    style: TextStyle(color: _selectedSource == 'knowledge_base' ? Colors.white : Colors.white54),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSource == 'knowledge_base' ? const Color(0xFF0078D4) : const Color(0xFF404040),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAnyOperationInProgress ? null : _pickLocalFile,
                  icon: Icon(Icons.upload_file, color: _selectedSource == 'local' ? Colors.white : Colors.white54),
                  label: Text(
                    'Upload Local File',
                    style: TextStyle(color: _selectedSource == 'local' ? Colors.white : Colors.white54),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSource == 'local' ? const Color(0xFF0078D4) : const Color(0xFF404040),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedSource == 'knowledge_base') ...[
            const Text(
              'Select a document from your knowledge base:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _knowledgeBaseFiles.isEmpty
                      ? const Center(
                          child: Text(
                            'No documents found in knowledge base',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _knowledgeBaseFiles.length,
                          itemBuilder: (context, index) {
                            final file = _knowledgeBaseFiles[index];
                            return Card(
                              color: const Color(0xFF3A3A3A),
                              child: ListTile(
                                leading: Icon(
                                  _getFileIcon(file.fileType),
                                  color: Colors.white54,
                                ),
                                title: Text(
                                  file.documentName,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  file.fileType.toUpperCase(),
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                trailing: _isExtracting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.arrow_forward, color: Colors.white54),
                                onTap: _isAnyOperationInProgress ? null : () => _selectKnowledgeBaseFile(file),
                              ),
                            );
                          },
                        ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isAnyOperationInProgress ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedAssets() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Extracted ${widget.assetType.toUpperCase()} Assets (${_editableAssets.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isAnyOperationInProgress ? null : _toggleSelectAll,
                icon: const Icon(Icons.select_all, color: Colors.white54, size: 16),
                label: Text(
                  _selectedAssets.values.every((selected) => selected) ? 'Unselect All' : 'Select All',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(50), // Checkbox column
                  1: FlexColumnWidth(2), // Name column
                  2: FlexColumnWidth(3), // Description column
                  3: FlexColumnWidth(2), // Tags column
                  4: FlexColumnWidth(2), // Metadata column
                },
                children: [
                  // Header row
                  TableRow(
                    decoration: const BoxDecoration(
                      color: Color(0xFF404040),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Tags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: const Text('Metadata', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows
                  for (int index = 0; index < _editableAssets.length; index++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: index % 2 == 0 ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: Checkbox(
                            value: _selectedAssets[index] ?? false,
                            onChanged: _isAnyOperationInProgress ? null : (value) {
                              setState(() {
                                _selectedAssets[index] = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF0078D4),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _nameControllers[index],
                            enabled: !_isAnyOperationInProgress,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.all(8),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _descriptionControllers[index],
                            enabled: !_isAnyOperationInProgress,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 2,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.all(8),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _tagsControllers[index],
                            enabled: !_isAnyOperationInProgress,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.all(8),
                              hintText: 'tag1, tag2, tag3',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: Tooltip(
                            message: 'Metadata is displayed as JSON. Edit the JSON directly or use key: value format.',
                            child: TextField(
                              controller: _metadataControllers[index],
                              enabled: !_isAnyOperationInProgress,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: 4,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.all(8),
                                hintText: '{"key": "value", "key2": "value2"}',
                                hintStyle: TextStyle(color: Colors.white54, fontSize: 10),
                                helperText: 'JSON format or key: value pairs',
                                helperStyle: TextStyle(color: Colors.white38, fontSize: 9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isAnyOperationInProgress ? null : () {
                  setState(() {
                    _extractedAssets.clear();
                    _editableAssets.clear();
                    _selectedAssets.clear();
                    _documentContent = '';
                    // Clear controllers
                    for (final controller in _nameControllers.values) {
                      controller.dispose();
                    }
                    for (final controller in _descriptionControllers.values) {
                      controller.dispose();
                    }
                    for (final controller in _tagsControllers.values) {
                      controller.dispose();
                    }
                    for (final controller in _metadataControllers.values) {
                      controller.dispose();
                    }
                    _nameControllers.clear();
                    _descriptionControllers.clear();
                    _tagsControllers.clear();
                    _metadataControllers.clear();
                  });
                },
                child: const Text(
                  'Back',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _isAnyOperationInProgress ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isAnyOperationInProgress ? null : _createSelectedAssets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Assets',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
      case 'md':
        return Icons.description;
      case 'doc':
      case 'docx':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }
}
