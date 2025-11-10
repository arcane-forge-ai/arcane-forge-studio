import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../game_design_assistant/models/api_models.dart';
import '../game_design_assistant/services/chat_api_service.dart';
import '../../providers/settings_provider.dart';

class KnowledgeBaseScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  
  const KnowledgeBaseScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);
  
  @override
  _KnowledgeBaseScreenState createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  late final ChatApiService _chatApiService;
  List<KnowledgeBaseFile> _files = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Initialize chat API service with settings provider
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _chatApiService = ChatApiService(settingsProvider: settingsProvider);
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _chatApiService.getKnowledgeBaseFiles(widget.projectId);
      
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading files: $e');
    }
  }

  Future<void> _uploadFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
        });
        
        int successCount = 0;
        for (final file in result.files) {
          if (file.path != null) {
            final success = await _chatApiService.uploadFile(
              widget.projectId,
              file.path!,
              file.name,
            );
            
            if (success) {
              successCount++;
            }
          }
        }

        setState(() {
          _isUploading = false;
        });

        if (successCount > 0) {
          _showSuccessSnackBar('Uploaded $successCount file(s) successfully');
          await _loadFiles(); // Refresh the file list
        }

        if (successCount < result.files.length) {
          _showErrorSnackBar('Some files failed to upload');
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showErrorSnackBar('Error uploading files: $e');
    }
  }

  Future<void> _deleteFile(KnowledgeBaseFile file) async {
    final confirm = await _showDeleteConfirmDialog(file.documentName);
    if (!confirm) return;

    try {
      final success = await _chatApiService.deleteFile(widget.projectId, file.id);
      
      if (success) {
        _showSuccessSnackBar('File deleted successfully');
        await _loadFiles(); // Refresh the file list
      } else {
        _showErrorSnackBar('Failed to delete file');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting file: $e');
    }
  }

  Future<bool> _showDeleteConfirmDialog(String fileName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete File'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Knowledge Base',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage your project\'s knowledge base files',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadFiles,
                        icon: _isUploading 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.upload_file),
                        label: Text(_isUploading ? 'Uploading...' : 'Upload Files'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Files list
                  Expanded(
                    child: _isLoading 
                      ? Center(child: CircularProgressIndicator())
                      : _files.isEmpty
                        ? _buildEmptyState()
                        : _buildFilesList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No files in knowledge base',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload files to start building your project\'s knowledge base',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadFiles,
            icon: _isUploading 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.upload_file),
            label: Text(_isUploading ? 'Uploading...' : 'Upload Your First File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return Card(
      child: Column(
        children: [
          // Header row
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('File Name', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Date Added', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 100), // Space for action buttons
              ],
            ),
          ),
          
          // Files list
          Expanded(
            child: ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                return _buildFileItem(file);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(KnowledgeBaseFile file) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // File icon
          _getFileIcon(file.fileType),
          const SizedBox(width: 12),
          
          // File name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.documentName,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                if (file.metadata != null && file.metadata!.isNotEmpty)
                  Text(
                    'Size: ${file.metadata!['size'] ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // File type
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getFileTypeColor(file.fileType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                file.fileType.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getFileTypeColor(file.fileType),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Date
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(file.createdAt),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          
          // Action buttons
          Row(
            children: [
              IconButton(
                onPressed: () => _downloadFile(file),
                icon: Icon(Icons.download, color: Colors.green),
                tooltip: 'Download file',
              ),
              IconButton(
                onPressed: () => _deleteFile(file),
                icon: Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete file',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getFileIcon(String fileType) {
    IconData iconData;
    Color color;
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'md':
        iconData = Icons.description;
        color = Colors.blue;
        break;
      case 'txt':
        iconData = Icons.text_snippet;
        color = Colors.grey;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        color = Colors.blue[700]!;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }
    
    return Icon(iconData, color: color, size: 24);
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'md':
        return Colors.blue;
      case 'txt':
        return Colors.green;
      case 'doc':
      case 'docx':
        return Colors.blue[700]!;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    // Convert to local time
    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate);
    
    String relativeTime;
    if (difference.inDays == 0) {
      relativeTime = 'Today';
    } else if (difference.inDays == 1) {
      relativeTime = 'Yesterday';
    } else if (difference.inDays < 7) {
      relativeTime = '${difference.inDays} days ago';
    } else {
      relativeTime = '${difference.inDays} days ago';
    }
    
    // Format absolute time as YYYY-MM-DD HH:mm:ss in local time
    final year = localDate.year.toString().padLeft(4, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    final second = localDate.second.toString().padLeft(2, '0');
    final absoluteTime = '$year-$month-$day $hour:$minute:$second';
    
    return '$relativeTime ($absoluteTime)';
  }

  Future<void> _downloadFile(KnowledgeBaseFile file) async {
    try {
      // Show loading indicator
      _showSuccessSnackBar('Getting download link...');
      
      // Get download URL from API
      final downloadResponse = await _chatApiService.getFileDownloadUrl(widget.projectId, file.id);
      
      if (downloadResponse == null) {
        _showErrorSnackBar('Failed to get download URL');
        return;
      }
      
      // Show "Save As" dialog
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${downloadResponse.fileName}',
        fileName: downloadResponse.fileName,
        type: FileType.any,
      );
      
      if (outputFile == null) {
        // User cancelled the dialog
        return;
      }
      
      // Check if file already exists and confirm overwrite
      final outputFileObj = File(outputFile);
      if (await outputFileObj.exists()) {
        final shouldOverwrite = await _showOverwriteConfirmDialog(outputFileObj.path);
        if (!shouldOverwrite) {
          return;
        }
      }
      
      // Show downloading indicator
      _showSuccessSnackBar('Downloading ${downloadResponse.fileName}...');
      
      // Download file content using dio
      final dio = Dio();
      final response = await dio.get(
        downloadResponse.downloadUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5), // 5 minute timeout for large files
        ),
      );
      
      // Write to selected location
      await outputFileObj.writeAsBytes(response.data);
      
      // Show success message with file location
      final fileName = outputFileObj.path.split(Platform.pathSeparator).last;
      final directory = outputFileObj.parent.path;
      _showSuccessSnackBar('Saved "$fileName" to $directory');
      
    } catch (e) {
      String errorMessage = 'Error downloading file: ';
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
      } else if (e is FileSystemException) {
        errorMessage += 'Could not save file. Check permissions and disk space.';
      } else {
        errorMessage += e.toString();
      }
      _showErrorSnackBar(errorMessage);
    }
  }

  Future<bool> _showOverwriteConfirmDialog(String filePath) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Already Exists'),
        content: Text('The file "$filePath" already exists. Do you want to overwrite it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    ) ?? false;
  }

} 