import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import '../game_design_assistant/models/api_models.dart';
import '../game_design_assistant/services/chat_api_service.dart';

class MarkdownViewerScreen extends StatefulWidget {
  final KnowledgeBaseFile file;
  final List<KnowledgeBaseFile> allVersions;
  final String projectId;
  final ChatApiService chatApiService;
  final String? passcode;

  const MarkdownViewerScreen({
    Key? key,
    required this.file,
    required this.allVersions,
    required this.projectId,
    required this.chatApiService,
    this.passcode,
  }) : super(key: key);

  @override
  _MarkdownViewerScreenState createState() => _MarkdownViewerScreenState();
}

class _MarkdownViewerScreenState extends State<MarkdownViewerScreen> {
  String? _markdownContent;
  bool _isLoading = true;
  String? _errorMessage;
  late int _currentVersionIndex;
  late KnowledgeBaseFile _currentFile;

  @override
  void initState() {
    super.initState();
    // Find the index of the current file in the versions list
    _currentVersionIndex = widget.allVersions.indexWhere((f) => f.id == widget.file.id);
    if (_currentVersionIndex == -1) {
      _currentVersionIndex = 0; // Fallback to first version
    }
    _currentFile = widget.allVersions[_currentVersionIndex];
    _loadMarkdownContent();
  }

  Future<void> _loadMarkdownContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get download URL from API
      final downloadResponse = await widget.chatApiService.getFileDownloadUrl(
        widget.projectId,
        _currentFile.id,
        passcode: widget.passcode,
      );

      if (downloadResponse == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get download URL';
        });
        return;
      }

      // Download file content as text using dio
      final dio = Dio();
      final response = await dio.get(
        downloadResponse.downloadUrl,
        options: Options(
          responseType: ResponseType.plain, // Get as text
          receiveTimeout: const Duration(minutes: 2), // 2 minute timeout
        ),
      );

      setState(() {
        _markdownContent = response.data as String;
        _isLoading = false;
      });
    } catch (e) {
      String errorMessage = 'Error loading markdown file: ';
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage += 'Request timed out. Please try again.';
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

      setState(() {
        _isLoading = false;
        _errorMessage = errorMessage;
      });
    }
  }

  void _switchToNewerVersion() {
    if (_currentVersionIndex > 0) {
      setState(() {
        _currentVersionIndex--;
        _currentFile = widget.allVersions[_currentVersionIndex];
      });
      _loadMarkdownContent();
    }
  }

  void _switchToOlderVersion() {
    if (_currentVersionIndex < widget.allVersions.length - 1) {
      setState(() {
        _currentVersionIndex++;
        _currentFile = widget.allVersions[_currentVersionIndex];
      });
      _loadMarkdownContent();
    }
  }

  String _formatTimestamp(DateTime date) {
    final localDate = date.toLocal();
    final year = localDate.year.toString().padLeft(4, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    final second = localDate.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleVersions = widget.allVersions.length > 1;
    final canGoNewer = _currentVersionIndex > 0;
    final canGoOlder = _currentVersionIndex < widget.allVersions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.documentName),
        actions: [
          // Version switcher (only show if multiple versions exist)
          if (hasMultipleVersions)
            Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Newer version button (left arrow)
                  IconButton(
                    icon: Icon(Icons.chevron_left),
                    onPressed: canGoNewer ? _switchToNewerVersion : null,
                    tooltip: 'Newer version',
                    iconSize: 20,
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(),
                  ),
                  // Current version timestamp
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _formatTimestamp(_currentFile.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  // Older version button (right arrow)
                  IconButton(
                    icon: Icon(Icons.chevron_right),
                    onPressed: canGoOlder ? _switchToOlderVersion : null,
                    tooltip: 'Older version',
                    iconSize: 20,
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMarkdownContent,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading markdown content...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadMarkdownContent,
                          icon: Icon(Icons.refresh),
                          label: Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _markdownContent == null
                  ? Center(
                      child: Text(
                        'No content available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : MarkdownView(
                      data: _markdownContent!,
                      selectable: true,
                    ),
    );
  }
}

class MarkdownView extends StatelessWidget {
  final String data;
  final bool selectable;

  const MarkdownView({
    Key? key,
    required this.data,
    this.selectable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MarkdownBody(
        data: data,
        selectable: selectable,
        styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        h1: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        h2: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        h3: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        h4: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        code: TextStyle(
          backgroundColor: Colors.grey[100],
          fontSize: 14,
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.onSurface,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        blockquote: TextStyle(
          color: Colors.grey[700],
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(
            left: BorderSide(
              color: Colors.grey[400]!,
              width: 4,
            ),
          ),
        ),
        listBullet: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        tableBody: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        tableBorder: TableBorder.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      ),
    );
  }
}

