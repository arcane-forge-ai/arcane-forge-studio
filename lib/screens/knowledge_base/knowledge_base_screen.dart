import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import '../game_design_assistant/models/api_models.dart';
import '../game_design_assistant/services/chat_api_service.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/file_rename_dialog.dart';
import '../../services/file_download_service.dart';
import '../../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../../utils/web_file_picker.dart';
import 'markdown_viewer_screen.dart';
import 'models/file_version_group.dart';

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
  List<FileVersionGroup> _fileGroups = [];
  Set<String> _expandedGroups = {};
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
        _fileGroups = _groupFilesByName(files);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading files: $e');
    }
  }

  /// Group files by name and sort versions by date
  List<FileVersionGroup> _groupFilesByName(List<KnowledgeBaseFile> files) {
    final grouped = <String, List<KnowledgeBaseFile>>{};
    
    for (final file in files) {
      grouped.putIfAbsent(file.documentName, () => []).add(file);
    }
    
    return grouped.entries.map((entry) {
      // Sort versions by date descending (newest first)
      final sortedVersions = entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return FileVersionGroup(
        fileName: entry.key,
        versions: sortedVersions,
      );
    }).toList();
  }

  /// Toggle expansion state for a file group
  void _toggleGroupExpansion(String fileName) {
    setState(() {
      if (_expandedGroups.contains(fileName)) {
        _expandedGroups.remove(fileName);
      } else {
        _expandedGroups.add(fileName);
      }
    });
  }

  Future<void> _uploadFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx'],
        allowMultiple: true,
        withData: true,
      );

      List<PlatformFile>? files = result?.files;
      if (kIsWeb && (files == null || files.isEmpty || files.any((f) => f.bytes == null))) {
        files = await pickFilesWithWebFallback(
          allowedExtensions: const ['pdf', 'txt', 'md', 'doc', 'docx'],
          allowMultiple: true,
        );
      }

      if (files != null && files.isNotEmpty) {
        // Show rename dialog
        final fileNames = await showDialog<List<String>>(
          context: context,
          builder: (context) => FileRenameDialog(files: files!),
        );

        // User cancelled the dialog
        if (fileNames == null) {
          return;
        }

        setState(() {
          _isUploading = true;
        });
        
        int successCount = 0;
        for (var i = 0; i < files.length; i++) {
          final file = files[i];
          final fileName = fileNames[i];
          final uploadSuccess = await _chatApiService.uploadFile(
            widget.projectId,
            fileName,
            filePath: kIsWeb ? null : file.path,
            bytes: file.bytes,
          );

          if (uploadSuccess) {
            successCount++;
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
                      : _fileGroups.isEmpty
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
              itemCount: _fileGroups.length,
              itemBuilder: (context, index) {
                final group = _fileGroups[index];
                return _buildFileGroupItem(group);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileGroupItem(FileVersionGroup group) {
    final isExpanded = _expandedGroups.contains(group.fileName);
    final latestFile = group.latestVersion;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Latest version (always visible)
        _buildFileItem(
          latestFile,
          isLatest: true,
          showVersionBadge: true,
        ),
        
        // Version count and expansion control
        if (group.hasMultipleVersions)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              )),
            ),
            child: Row(
              children: [
                SizedBox(width: 36), // Align with file icon
                InkWell(
                  onTap: () => _toggleGroupExpansion(group.fileName),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${group.versionCount} versions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Older versions (shown when expanded)
        if (group.hasMultipleVersions && isExpanded)
          ...group.olderVersions.map((file) => _buildFileItem(
            file,
            isLatest: false,
            showVersionBadge: true,
            isIndented: true,
          )),
      ],
    );
  }

  Widget _buildFileItem(
    KnowledgeBaseFile file, {
    bool isLatest = true,
    bool showVersionBadge = false,
    bool isIndented = false,
  }) {
    final opacity = isLatest ? 1.0 : 0.85;
    final leftPadding = isIndented ? 52.0 : 16.0; // Extra indent for older versions
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme-aware background color for older versions
    final backgroundColor = isLatest 
        ? null 
        : (isDark 
            ? Colors.white.withOpacity(0.03) 
            : Colors.black.withOpacity(0.02));

    return Container(
      padding: EdgeInsets.only(
        left: leftPadding,
        right: 16,
        top: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        )),
        color: backgroundColor,
      ),
      child: Opacity(
        opacity: opacity,
        child: Row(
          children: [
            // Arrow indicator for older versions
            if (isIndented)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.subdirectory_arrow_right,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
            
            // File icon
            _getFileIcon(file.fileType),
            const SizedBox(width: 12),
            
            // File name with version badge
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          file.documentName,
                          style: TextStyle(
                            fontWeight: isLatest ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (showVersionBadge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLatest 
                                ? (isDark ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1))
                                : (isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isLatest ? 'Latest' : _getRelativeDate(file.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isLatest 
                                  ? (isDark ? Colors.green[300] : Colors.green[700])
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                        ),
                      ],
                    ],
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
                // View button for markdown files
                if (file.fileType.toLowerCase() == 'md')
                  IconButton(
                    onPressed: () => _viewMarkdownFile(file),
                    icon: Icon(Icons.visibility, color: Colors.blue),
                    tooltip: 'View markdown',
                  ),
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
      ),
    );
  }

  /// Get relative date string for version badge
  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? "month" : "months"} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? "year" : "years"} ago';
    }
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
      final downloadResponse = await _chatApiService.getFileDownloadUrl(widget.projectId, file.id);

      if (downloadResponse == null) {
        _showErrorSnackBar('Failed to get download URL');
        return;
      }

      await FileDownloadService.downloadFile(
        url: downloadResponse.downloadUrl,
        defaultFileName: downloadResponse.fileName,
        config: FileDownloadConfig(
          dialogTitle: 'Save ${downloadResponse.fileName}',
          allowedExtensions: const [],
          errorPrefix: 'Error downloading file',
          downloadingSnackbarColor: Colors.blue,
          showOverwriteConfirmation: !kIsWeb,
        ),
        context: context,
        mounted: () => mounted,
      );

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

  Future<void> _viewMarkdownFile(KnowledgeBaseFile file) async {
    // Find all versions of this file
    final group = _fileGroups.firstWhere(
      (g) => g.fileName == file.documentName,
      orElse: () => FileVersionGroup(fileName: file.documentName, versions: [file]),
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MarkdownViewerScreen(
          file: file,
          allVersions: group.versions,
          projectId: widget.projectId,
          chatApiService: _chatApiService,
        ),
      ),
    );
  }

} 