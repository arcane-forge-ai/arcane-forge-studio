import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:dio/dio.dart';
import '../game_design_assistant/models/api_models.dart';
import '../game_design_assistant/services/chat_api_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final KnowledgeBaseFile file;
  final List<KnowledgeBaseFile> allVersions;
  final String projectId;
  final ChatApiService chatApiService;

  const PdfViewerScreen({
    Key? key,
    required this.file,
    required this.allVersions,
    required this.projectId,
    required this.chatApiService,
  }) : super(key: key);

  @override
  _PdfViewerScreenState createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _pdfUrl;
  bool _isLoading = true;
  String? _errorMessage;
  late int _currentVersionIndex;
  late KnowledgeBaseFile _currentFile;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    // Find the index of the current file in the versions list
    _currentVersionIndex = widget.allVersions.indexWhere((f) => f.id == widget.file.id);
    if (_currentVersionIndex == -1) {
      _currentVersionIndex = 0; // Fallback to first version
    }
    _currentFile = widget.allVersions[_currentVersionIndex];
    _loadPdfUrl();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  Future<void> _loadPdfUrl() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pdfUrl = null;
    });

    try {
      // Get download URL from API
      final downloadResponse = await widget.chatApiService.getFileDownloadUrl(
        widget.projectId,
        _currentFile.id,
      );

      if (downloadResponse == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get download URL';
        });
        return;
      }

      setState(() {
        _pdfUrl = downloadResponse.downloadUrl;
        _isLoading = false;
      });
    } catch (e) {
      String errorMessage = 'Error loading PDF file: ';
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
      _loadPdfUrl();
    }
  }

  void _switchToOlderVersion() {
    if (_currentVersionIndex < widget.allVersions.length - 1) {
      setState(() {
        _currentVersionIndex++;
        _currentFile = widget.allVersions[_currentVersionIndex];
      });
      _loadPdfUrl();
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
            onPressed: _isLoading ? null : _loadPdfUrl,
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
                    'Loading PDF...',
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
                          onPressed: _loadPdfUrl,
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
              : _pdfUrl == null
                  ? Center(
                      child: Text(
                        'No PDF URL available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : SfPdfViewer.network(
                      _pdfUrl!,
                      controller: _pdfViewerController,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      enableDoubleTapZooming: true,
                      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                        setState(() {
                          _errorMessage = 'Failed to load PDF: ${details.error}';
                        });
                      },
                    ),
    );
  }
}
