import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../game_design_assistant/models/api_models.dart';
import '../../game_design_assistant/services/chat_api_service.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/file_download_service.dart';
import '../../knowledge_base/models/file_version_group.dart';
import '../../knowledge_base/widgets/entry_type_icon.dart';
import '../../knowledge_base/widgets/visibility_badge.dart';
import '../../knowledge_base/widgets/authority_badge.dart';
import '../../knowledge_base/widgets/tags_chips.dart';
import '../../knowledge_base/markdown_viewer_screen.dart';
import '../../knowledge_base/pdf_viewer_screen.dart';

/// Public Knowledge Base Dialog for vendors
/// Shows only vendor-visible documents in read-only mode
class PublicKnowledgeBaseDialog extends StatefulWidget {
  final String projectId;
  final String passcode;
  final String? highlightDocumentId;

  const PublicKnowledgeBaseDialog({
    Key? key,
    required this.projectId,
    required this.passcode,
    this.highlightDocumentId,
  }) : super(key: key);

  @override
  State<PublicKnowledgeBaseDialog> createState() => _PublicKnowledgeBaseDialogState();
}

enum SortField { name, date, type }
enum SortDirection { ascending, descending }

class _PublicKnowledgeBaseDialogState extends State<PublicKnowledgeBaseDialog> {
  late final ChatApiService _chatApiService;
  List<FileVersionGroup> _fileGroups = [];
  Set<String> _expandedGroups = {};
  bool _isLoading = false;
  SortField _sortField = SortField.date;
  SortDirection _sortDirection = SortDirection.descending;

  @override
  void initState() {
    super.initState();
    // Initialize chat API service with passcode authentication
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
      // Get all files using passcode, then filter for vendor-visible
      final allFiles = await _chatApiService.getKnowledgeBaseFiles(
        widget.projectId,
        passcode: widget.passcode,
      );
      
      // Filter to only vendor-visible documents
      final files = allFiles.where((f) => f.visibility == 'vendor_visible').toList();
      
      if (!mounted) return;
      
      setState(() {
        _fileGroups = _groupFilesByName(files);
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
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Public Knowledge Base'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Refresh button
            IconButton(
              onPressed: _isLoading ? null : _loadFiles,
              icon: Icon(
                Icons.refresh,
                color: _isLoading ? Colors.grey : Colors.blue,
              ),
              tooltip: 'Refresh entries',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header section
                    Text(
                      'Browse vendor-visible documents',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Files list
                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
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
            'No vendor-visible documents',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no documents shared with external vendors yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              )),
            ),
            child: Row(
              children: [
                const SizedBox(width: 36), // Align with file icon
                InkWell(
                  onTap: () => _toggleGroupExpansion(group.fileName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        const SizedBox(width: 4),
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
            
            // Action buttons (read-only: view info, open link, download)
            Row(
              children: [
                // View metadata button for non-file entries
                if (file.entryType != 'document')
                  IconButton(
                    onPressed: () => _viewEntryMetadata(file),
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    tooltip: 'View details',
                  ),
                // Open link button for links and contacts
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
      final downloadResponse = await _chatApiService.getFileDownloadUrl(
        widget.projectId,
        file.id,
        passcode: widget.passcode,
      );

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
          passcode: widget.passcode,
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
          passcode: widget.passcode,
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
