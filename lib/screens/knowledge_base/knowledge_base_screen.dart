import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import '../game_design_assistant/models/api_models.dart';
import '../game_design_assistant/services/chat_api_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/file_rename_dialog.dart';
import '../../services/file_download_service.dart';
import '../../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../../utils/web_file_picker.dart';
import 'markdown_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'models/file_version_group.dart';
import 'models/kb_entry_filter.dart';
import 'dialogs/add_link_dialog.dart';
import 'dialogs/add_contact_dialog.dart';
import 'dialogs/add_other_entry_dialog.dart';
import 'dialogs/edit_entry_metadata_dialog.dart';
import 'widgets/entry_type_icon.dart';
import 'widgets/visibility_badge.dart';
import 'widgets/authority_badge.dart';
import 'widgets/tags_chips.dart';

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

enum SortField { name, date, type }
enum SortDirection { ascending, descending }

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  late final ChatApiService _chatApiService;
  List<FileVersionGroup> _fileGroups = [];
  Set<String> _expandedGroups = {};
  bool _isLoading = false;
  bool _isUploading = false;
  KBEntryFilter _filter = const KBEntryFilter();
  SortField _sortField = SortField.date;
  SortDirection _sortDirection = SortDirection.descending;

  @override
  void initState() {
    super.initState();
    // Initialize chat API service with settings and auth providers
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _chatApiService = ChatApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _chatApiService.getKnowledgeBaseFiles(widget.projectId);
      
      if (!mounted) return;
      
      setState(() {
        _fileGroups = _groupFilesByName(_applyFilters(files));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading files: $e');
    }
  }

  /// Apply current filters to the file list
  List<KnowledgeBaseFile> _applyFilters(List<KnowledgeBaseFile> files) {
    var filtered = files;

    if (_filter.entryTypes.isNotEmpty) {
      filtered = filtered
          .where((f) => _filter.entryTypes.contains(f.entryType))
          .toList();
    }

    if (_filter.visibility != null) {
      filtered = filtered
          .where((f) => f.visibility == _filter.visibility)
          .toList();
    }

    if (_filter.authorityLevels.isNotEmpty) {
      filtered = filtered
          .where((f) => _filter.authorityLevels.contains(f.authorityLevel))
          .toList();
    }

    if (_filter.tags.isNotEmpty) {
      filtered = filtered.where((f) {
        return _filter.tags.any((tag) => f.tags.contains(tag));
      }).toList();
    }

    return filtered;
  }

  /// Group files by name and sort versions by date
  List<FileVersionGroup> _groupFilesByName(List<KnowledgeBaseFile> files) {
    final grouped = <String, List<KnowledgeBaseFile>>{};
    
    for (final file in files) {
      grouped.putIfAbsent(file.documentName, () => []).add(file);
    }
    
    var groups = grouped.entries.map((entry) {
      // Sort versions by date descending (newest first)
      final sortedVersions = entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return FileVersionGroup(
        fileName: entry.key,
        versions: sortedVersions,
      );
    }).toList();
    
    // Apply sorting
    return _sortFileGroups(groups);
  }

  /// Sort file groups based on current sort field and direction
  List<FileVersionGroup> _sortFileGroups(List<FileVersionGroup> groups) {
    final sortedGroups = List<FileVersionGroup>.from(groups);
    
    sortedGroups.sort((a, b) {
      int comparison;
      
      switch (_sortField) {
        case SortField.name:
          comparison = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
          break;
        case SortField.date:
          comparison = a.latestVersion.createdAt.compareTo(b.latestVersion.createdAt);
          break;
        case SortField.type:
          comparison = a.latestVersion.entryType.compareTo(b.latestVersion.entryType);
          break;
      }
      
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });
    
    return sortedGroups;
  }

  /// Change sort field or toggle direction if same field
  void _changeSorting(SortField field) {
    setState(() {
      if (_sortField == field) {
        // Toggle direction if clicking same field
        _sortDirection = _sortDirection == SortDirection.ascending 
            ? SortDirection.descending 
            : SortDirection.ascending;
      } else {
        // Change field and use default direction
        _sortField = field;
        _sortDirection = field == SortField.date 
            ? SortDirection.descending  // Newest first by default
            : SortDirection.ascending;  // A-Z by default for name/type
      }
      // Re-sort existing groups
      _fileGroups = _sortFileGroups(_fileGroups);
    });
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

        if (successCount < files.length) {
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

  Future<void> _addEntryOfType(String entryType) async {
    KnowledgeBaseFile? entry;
    
    switch (entryType) {
      case 'link':
        entry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => const AddLinkDialog(),
        );
        break;
      case 'contact':
        entry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => const AddContactDialog(),
        );
        break;
      case 'folder':
        entry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => AddOtherEntryDialog(entryType: 'folder'),
        );
        break;
      case 'other':
        entry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => AddOtherEntryDialog(entryType: 'other'),
        );
        break;
    }

    if (entry != null) {
      try {
        await _chatApiService.addKnowledgeBaseEntry(widget.projectId, entry);
        _showSuccessSnackBar('Entry added successfully');
        await _loadFiles();
      } catch (e) {
        _showErrorSnackBar('Error adding entry: $e');
      }
    }
  }

  Future<void> _editEntryMetadata(KnowledgeBaseFile entry) async {
    KnowledgeBaseFile? updatedEntry;
    
    // Route to the appropriate dialog based on entry type
    switch (entry.entryType) {
      case 'link':
        updatedEntry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => AddLinkDialog(existingEntry: entry),
        );
        break;
      case 'contact':
        updatedEntry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => AddContactDialog(existingEntry: entry),
        );
        break;
      case 'folder':
        updatedEntry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => AddOtherEntryDialog(
            entryType: 'folder',
            existingEntry: entry,
          ),
        );
        break;
      case 'other':
        updatedEntry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => AddOtherEntryDialog(
            entryType: 'other',
            existingEntry: entry,
          ),
        );
        break;
      case 'document':
      default:
        // For documents and other types, use the metadata-only dialog
        updatedEntry = await showDialog<KnowledgeBaseFile>(
          context: context,
          builder: (context) => EditEntryMetadataDialog(entry: entry),
        );
        break;
    }

    if (updatedEntry != null) {
      try {
        await _chatApiService.updateKnowledgeBaseEntry(
          widget.projectId,
          entry.id,
          updatedEntry,
        );
        _showSuccessSnackBar('Entry updated successfully');
        await _loadFiles();
      } catch (e) {
        _showErrorSnackBar('Error updating entry: $e');
      }
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
                            'Manage your project\'s knowledge base entries',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Refresh button
                          IconButton(
                            onPressed: _isLoading ? null : _loadFiles,
                            icon: Icon(
                              Icons.refresh,
                              color: _isLoading ? Colors.grey : Colors.blue,
                            ),
                            tooltip: 'Refresh entries',
                          ),
                          const SizedBox(width: 8),
                          // Filter indicator
                          if (_filter.hasActiveFilters)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Filtered',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _filter = _filter.clearAll();
                                      });
                                      _loadFiles();
                                    },
                                    child: const Icon(Icons.close, size: 16, color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                          MenuAnchor(
                            builder: (context, controller, child) {
                              return ElevatedButton.icon(
                                onPressed: () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Entry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              );
                            },
                            menuChildren: [
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.upload_file),
                                onPressed: _isUploading ? null : _uploadFiles,
                                child: const Text('Upload Documents'),
                              ),
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.link),
                                onPressed: () => _addEntryOfType('link'),
                                child: const Text('Add Link'),
                              ),
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.person),
                                onPressed: () => _addEntryOfType('contact'),
                                child: const Text('Add Contact'),
                              ),
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.folder),
                                onPressed: () => _addEntryOfType('folder'),
                                child: const Text('Add Folder'),
                              ),
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.notes),
                                onPressed: () => _addEntryOfType('other'),
                                child: const Text('Add Other Entry'),
                              ),
                            ],
                          ),
                        ],
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
          // Header row with sorting
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[850]
                  : Colors.grey[100],
            ),
            child: Row(
              children: [
                const SizedBox(width: 36), // Icon space
                // Name column header
                SizedBox(
                  width: 350,
                  child: _buildSortableHeader('Name', SortField.name),
                ),
                // Type & Metadata column header
                SizedBox(
                  width: 250,
                  child: _buildSortableHeader('Type & Metadata', SortField.type),
                ),
                // Date column header
                SizedBox(
                  width: 280,
                  child: _buildSortableHeader('Date Added', SortField.date),
                ),
                const SizedBox(width: 120), // Space for action buttons
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

  Widget _buildSortableHeader(String label, SortField field) {
    final isActive = _sortField == field;
    final color = isActive ? Colors.blue : null;
    
    return InkWell(
      onTap: () => _changeSorting(field),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          if (isActive)
            Icon(
              _sortDirection == SortDirection.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 16,
              color: color,
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
    final leftPadding = isIndented ? 52.0 : 16.0;
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
            
            // Entry type icon
            EntryTypeIcon(entryType: file.entryType),
            const SizedBox(width: 12),
            
            // File name with version badge, link/email, and description
            SizedBox(
              width: 350,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  // Email for contact entries or URL for link entries
                  // Email for contact entries (backend auto-creates mailto: url from contact_info.email)
                  if (file.entryType == 'contact' && file.url != null && file.url!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      file.url!.replaceFirst('mailto:', '').trim(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                    ),
                  ],
                  // Description below entry name
                  if (file.description != null && file.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      file.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Type & Metadata column
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VisibilityBadge(visibility: file.visibility, compact: true),
                      const SizedBox(width: 8),
                      AuthorityBadge(authorityLevel: file.authorityLevel, compact: true),
                    ],
                  ),
                  if (file.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TagsChips(tags: file.tags, maxVisible: 2, compact: true),
                  ],
                ],
              ),
            ),
            
            // Date
            SizedBox(
              width: 280,
              child: Text(
                _formatDate(file.createdAt),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            
            // Action buttons
            Row(
              children: [
                // View metadata button for non-file entries
                if (file.entryType != 'document')
                  IconButton(
                    onPressed: () => _viewEntryMetadata(file),
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    tooltip: 'View details',
                  ),
                // Open link button for links and contacts (both use url field)
                if ((file.entryType == 'link' || file.entryType == 'contact') && file.url != null)
                  IconButton(
                    onPressed: () => _openLink(file),
                    icon: const Icon(Icons.open_in_new, color: Colors.green),
                    tooltip: file.entryType == 'link' ? 'Open link' : 'Send email',
                  ),
                // Copy link/email button
                if ((file.entryType == 'link' || file.entryType == 'contact') && file.url != null)
                  IconButton(
                    onPressed: () => _copyLink(file),
                    icon: const Icon(Icons.copy, color: Colors.purple),
                    tooltip: 'Copy to clipboard',
                  ),
                // Edit metadata button
                IconButton(
                  onPressed: () => _editEntryMetadata(file),
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  tooltip: 'Edit metadata',
                ),
                // View button for markdown files
                if (file.fileType.toLowerCase() == 'md')
                  IconButton(
                    onPressed: () => _viewMarkdownFile(file),
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    tooltip: 'View markdown',
                  ),
                // View button for PDF files
                if (file.fileType.toLowerCase() == 'pdf')
                  IconButton(
                    onPressed: () => _viewPdfFile(file),
                    icon: const Icon(Icons.visibility, color: Colors.red),
                    tooltip: 'View PDF',
                  ),
                // Download button for document entries
                if (file.entryType == 'document')
                  IconButton(
                    onPressed: () => _downloadFile(file),
                    icon: const Icon(Icons.download, color: Colors.green),
                    tooltip: 'Download file',
                  ),
                IconButton(
                  onPressed: () => _deleteFile(file),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete entry',
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

  Future<void> _viewPdfFile(KnowledgeBaseFile file) async {
    // Find all versions of this file
    final group = _fileGroups.firstWhere(
      (g) => g.fileName == file.documentName,
      orElse: () => FileVersionGroup(fileName: file.documentName, versions: [file]),
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          file: file,
          allVersions: group.versions,
          projectId: widget.projectId,
          chatApiService: _chatApiService,
        ),
      ),
    );
  }

  void _viewEntryMetadata(KnowledgeBaseFile entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: SelectableText(entry.documentName),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMetadataRow('Entry Type', entry.entryType.toUpperCase()),
                const SizedBox(height: 12),
                
                _buildMetadataRow('Visibility', entry.visibility == 'vendor_visible' ? 'Vendor Visible' : 'Internal Only'),
                const SizedBox(height: 12),
                
                _buildMetadataRow('Authority', entry.authorityLevel.replaceAll('_', ' ').toUpperCase()),
                const SizedBox(height: 12),
                
                if (entry.url != null && entry.url!.isNotEmpty) ...[
                  _buildMetadataRow('URL', entry.url!),
                  const SizedBox(height: 12),
                ],
                
                if (entry.contactInfo != null && entry.contactInfo!.isNotEmpty) ...[
                  const SelectableText(
                    'Contact Information',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...entry.contactInfo!.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildMetadataRow(e.key.toUpperCase(), e.value),
                  )),
                  const SizedBox(height: 12),
                ],
                
                if (entry.tags.isNotEmpty) ...[
                  const SelectableText(
                    'Tags',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TagsChips(tags: entry.tags, maxVisible: 100),
                  const SizedBox(height: 12),
                ],
                
                if (entry.description != null && entry.description!.isNotEmpty) ...[
                  const SelectableText(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    entry.description!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Future<void> _openLink(KnowledgeBaseFile file) async {
    String? urlString;
    
    // Both link and contact entries use the url field
    // For contacts, backend auto-creates mailto: url from contact_info.email
    if ((file.entryType == 'link' || file.entryType == 'contact') && file.url != null) {
      urlString = file.url;
    }
    
    if (urlString != null) {
      try {
        final uri = Uri.parse(urlString);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar('Could not open link');
        }
      } catch (e) {
        _showErrorSnackBar('Invalid URL: $e');
      }
    }
  }

  Future<void> _copyLink(KnowledgeBaseFile file) async {
    String? textToCopy;
    String? successMessage;
    
    // Both link and contact entries use the url field
    // For contacts, backend auto-creates mailto: url from contact_info.email
    if (file.entryType == 'link' && file.url != null) {
      textToCopy = file.url;
      successMessage = 'Link copied to clipboard';
    } else if (file.entryType == 'contact' && file.url != null) {
      textToCopy = file.url!.replaceFirst('mailto:', '').trim();
      successMessage = 'Email copied to clipboard';
    }
    
    if (textToCopy != null) {
      try {
        await Clipboard.setData(ClipboardData(text: textToCopy));
        _showSuccessSnackBar(successMessage!);
      } catch (e) {
        _showErrorSnackBar('Failed to copy: $e');
      }
    }
  }

} 