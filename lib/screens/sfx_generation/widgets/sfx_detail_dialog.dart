import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../../../models/sfx_generation_models.dart';
import '../../../providers/sfx_generation_provider.dart';
import '../../../services/file_download_service.dart';

class SfxDetailDialog extends StatefulWidget {
  final SfxGeneration generation;
  final SfxAsset? asset;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const SfxDetailDialog({
    super.key,
    required this.generation,
    this.asset,
    this.onFavoriteToggle,
    this.onDownload,
    this.onDelete,
  });

  @override
  State<SfxDetailDialog> createState() => _SfxDetailDialogState();
}

class _SfxDetailDialogState extends State<SfxDetailDialog> {
  late AudioPlayer _audioPlayer;
  late SfxGeneration _currentGeneration;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isTogglingFavorite = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _errorMessage;
  
  // Stream subscriptions to properly dispose of listeners
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _currentGeneration = widget.generation;
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  Future<void> _handleFavoriteToggle() async {
    if (_isTogglingFavorite) return;
    
    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      final provider = Provider.of<SfxGenerationProvider>(context, listen: false);
      
      // First, make the API call
      await provider.setFavoriteSfxGeneration(
        _currentGeneration.assetId,
        _currentGeneration.id,
      );
      
      // After API call succeeds, update the UI
      if (mounted) {
        setState(() {
          _currentGeneration = _currentGeneration.copyWith(
            isFavorite: !_currentGeneration.isFavorite,
          );
          _isTogglingFavorite = false;
        });
      }
      
      // Call the callback if provided (for parent to refresh)
      if (widget.onFavoriteToggle != null) {
        widget.onFavoriteToggle!();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupAudioPlayer() {
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          // Ensure position doesn't exceed duration to prevent slider bounds error
          _position = position > _duration ? _duration : position;
        });
      }
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.playing && _position == Duration.zero;
        });
      }
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent setState() after dispose
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      final audioUrl = widget.generation.audioUrl;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          setState(() {
            _errorMessage = null;
            _isLoading = true;
          });
          await _audioPlayer.play(UrlSource(audioUrl));
        } catch (e) {
          setState(() {
            _errorMessage = 'Failed to play audio: $e';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No audio URL available';
        });
      }
    }
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      _position = Duration.zero;
    });
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 800;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: isLargeScreen ? screenSize.width * 0.9 : screenSize.width,
        height: isLargeScreen ? screenSize.height * 0.9 : screenSize.height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        child: isLargeScreen ? _buildLargeScreenLayout(context) : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context) {
    return Column(
      children: [
        // Header with action buttons
        _buildDialogHeader(context),
        // Main content
        Expanded(
          child: Row(
            children: [
              // Left side - Audio Player
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: _buildAudioPlayerView(),
                ),
              ),
              // Right side - Details
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: _buildDetailsPanel(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // Header with action buttons
        _buildDialogHeader(context),
        // Top - Audio Player
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: _buildAudioPlayerView(),
          ),
        ),
        // Bottom - Details
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: _buildDetailsPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Audio Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Favorite button
          IconButton(
            onPressed: _isTogglingFavorite ? null : _handleFavoriteToggle,
            icon: _isTogglingFavorite
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                    ),
                  )
                : Icon(
                    _currentGeneration.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _currentGeneration.isFavorite ? Colors.red : Colors.white54,
                  ),
            tooltip: _currentGeneration.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
          ),
          // Download button
          IconButton(
            onPressed: widget.generation.status == GenerationStatus.completed 
                ? (widget.onDownload ?? () => _downloadAudio(context))
                : null,
            icon: const Icon(Icons.download, color: Colors.white54),
            tooltip: 'Download audio',
          ),
          // Delete button
          IconButton(
            onPressed: widget.onDelete ?? () => _deleteGeneration(context),
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete generation',
          ),
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white54),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayerView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Audio Waveform Placeholder
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF404040)),
              ),
              child: _errorMessage != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.audiotrack,
                          color: _isPlaying ? Colors.green : Colors.white54,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else if (widget.generation.audioUrl != null)
                          Text(
                            _isPlaying ? 'Playing...' : 'Ready to play',
                            style: TextStyle(
                              color: _isPlaying ? Colors.green : Colors.white54,
                              fontSize: 16,
                            ),
                          )
                        else
                          const Text(
                            'No audio available',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                      ],
                    ),
            ),
            
            const SizedBox(height: 24),
            
            // Progress Slider
            if (_duration.inMilliseconds > 0) ...[
              Slider(
                value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
                max: _duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  _seekTo(Duration(milliseconds: value.toInt()));
                },
                activeColor: Colors.blue,
                inactiveColor: Colors.white24,
              ),
              
              // Time Display
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ] else if (widget.generation.duration != null) ...[
              Text(
                'Duration: ${widget.generation.duration!.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),
            ],
            
            // Control Buttons
            if (widget.generation.audioUrl != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    color: Colors.white,
                    iconSize: 32,
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _playPause,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Generation Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          
          // Basic Info
          _buildDetailSection('Basic Information', [
            _buildDetailItem('Created', _formatDateTime(widget.generation.createdAt)),
            _buildDetailItem('Status', widget.generation.status.name.toUpperCase()),
            _buildDetailItem('Favorite', _currentGeneration.isFavorite ? 'Yes' : 'No'),
            if (widget.asset != null) _buildDetailItem('Asset', widget.asset!.name),
            if (widget.generation.duration != null) 
              _buildDetailItem('Duration', '${widget.generation.duration!.toStringAsFixed(1)}s'),
            if (widget.generation.fileSize != null)
              _buildDetailItem('File Size', _formatFileSize(widget.generation.fileSize!)),
            if (widget.generation.format != null)
              _buildDetailItem('Format', widget.generation.format!.toUpperCase()),
          ]),
          
          const SizedBox(height: 20),
          
          // Generation Parameters
          _buildDetailSection('Generation Parameters', [
            _buildDetailItem('Model', widget.generation.parameters['model'] ?? 'Unknown'),
            if (widget.generation.parameters['duration_seconds'] != null)
              _buildDetailItem('Target Duration', '${widget.generation.parameters['duration_seconds']}s'),
            if (widget.generation.parameters['prompt_influence'] != null)
              _buildDetailItem('Prompt Influence', '${(widget.generation.parameters['prompt_influence'] * 100).toInt()}%'),
          ]),
          
          const SizedBox(height: 20),
          
          // Prompts
          _buildDetailSection('Prompts', [
            _buildTextDetailItem('Prompt', widget.generation.parameters['prompt'] ?? 'No prompt'),
            if (widget.generation.parameters['negative_prompt'] != null && 
                widget.generation.parameters['negative_prompt'].toString().isNotEmpty)
              _buildTextDetailItem('Negative Prompt', widget.generation.parameters['negative_prompt']),
          ]),
          
          const SizedBox(height: 20),
          
          // Copy Details Button
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _copyToClipboard(context),
              icon: const Icon(Icons.copy),
              label: const Text('Copy Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF404040),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF404040)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _copyToClipboard(BuildContext context) {
    final details = StringBuffer();
    details.writeln('SFX Generation Details:');
    details.writeln('Created: ${_formatDateTime(widget.generation.createdAt)}');
    details.writeln('Status: ${widget.generation.status.name.toUpperCase()}');
    details.writeln('Favorite: ${_currentGeneration.isFavorite ? 'Yes' : 'No'}');
    if (widget.asset != null) details.writeln('Asset: ${widget.asset!.name}');
    if (widget.generation.duration != null) details.writeln('Duration: ${widget.generation.duration!.toStringAsFixed(1)}s');
    if (widget.generation.fileSize != null) details.writeln('File Size: ${_formatFileSize(widget.generation.fileSize!)}');
    if (widget.generation.format != null) details.writeln('Format: ${widget.generation.format!.toUpperCase()}');
    details.writeln();
    details.writeln('Generation Parameters:');
    details.writeln('Model: ${widget.generation.parameters['model'] ?? 'Unknown'}');
    if (widget.generation.parameters['duration_seconds'] != null) {
      details.writeln('Target Duration: ${widget.generation.parameters['duration_seconds']}s');
    }
    if (widget.generation.parameters['prompt_influence'] != null) {
      details.writeln('Prompt Influence: ${(widget.generation.parameters['prompt_influence'] * 100).toInt()}%');
    }
    details.writeln();
    details.writeln('Prompt: ${widget.generation.parameters['prompt'] ?? 'No prompt'}');
    if (widget.generation.parameters['negative_prompt'] != null && 
        widget.generation.parameters['negative_prompt'].toString().isNotEmpty) {
      details.writeln('Negative Prompt: ${widget.generation.parameters['negative_prompt']}');
    }
    
    Clipboard.setData(ClipboardData(text: details.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SFX generation details copied to clipboard!')),
    );
  }

  Future<void> _downloadAudio(BuildContext context) async {
    final audioUrl = widget.generation.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio URL available for download'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final defaultFileName = _generateDefaultFileName();
    
    await FileDownloadService.downloadFile(
      url: audioUrl,
      defaultFileName: defaultFileName,
      config: const FileDownloadConfig(
        dialogTitle: 'Save Audio File',
        allowedExtensions: ['mp3', 'wav', 'ogg', 'aac', 'm4a'],
        errorPrefix: 'Error downloading audio',
        downloadingSnackbarColor: Colors.blue,
        showOverwriteConfirmation: true,
      ),
      context: context,
      mounted: () => mounted,
    );
  }

  String _generateDefaultFileName() {
    // Generate a filename based on the prompt or asset name
    String baseName = 'sfx_audio';
    
    if (widget.asset != null && widget.asset!.name.isNotEmpty) {
      baseName = widget.asset!.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    } else if (widget.generation.parameters['prompt'] != null) {
      final prompt = widget.generation.parameters['prompt'].toString();
      if (prompt.isNotEmpty) {
        // Take first few words of prompt and sanitize
        final words = prompt.split(' ').take(3).join('_');
        baseName = words.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      }
    }
    
    // Add timestamp to make filename unique
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Use the format from generation parameters or default to mp3
    final format = widget.generation.format ?? 'mp3';
    
    return '${baseName}_$timestamp.$format';
  }


  void _deleteGeneration(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Delete Generation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this generated audio?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close confirmation dialog
              Navigator.of(context).pop(); // Close audio detail dialog
              // TODO: Implement actual deletion logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete functionality will be implemented soon'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
} 