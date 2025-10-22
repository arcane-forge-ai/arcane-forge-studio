import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../models/music_generation_models.dart';
import '../../../models/sfx_generation_models.dart'; // For GenerationStatus

class MusicDetailDialog extends StatefulWidget {
  final MusicGeneration generation;
  final MusicAsset? asset;
  final VoidCallback? onFavoriteToggle;

  const MusicDetailDialog({
    Key? key,
    required this.generation,
    this.asset,
    this.onFavoriteToggle,
  }) : super(key: key);

  @override
  State<MusicDetailDialog> createState() => _MusicDetailDialogState();
}

class _MusicDetailDialogState extends State<MusicDetailDialog> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
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
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
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
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMusicVisualization(),
                    const SizedBox(height: 24),
                    _buildInfoSection(),
                    const SizedBox(height: 24),
                    _buildParametersSection(),
                    if (widget.generation.metadata.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildMetadataSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Music Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (widget.onFavoriteToggle != null)
            IconButton(
              onPressed: widget.onFavoriteToggle,
              icon: Icon(
                widget.generation.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.generation.isFavorite ? Colors.red : Colors.white54,
              ),
              tooltip: widget.generation.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
            ),
          // Download button
          IconButton(
            onPressed: widget.generation.status == GenerationStatus.completed 
                ? () => _downloadAudio(context)
                : null,
            icon: const Icon(Icons.download, color: Colors.white54),
            tooltip: 'Download music',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white54),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicVisualization() {
    return Column(
      children: [
        // Waveform/Player visualization
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.withOpacity(0.3),
                Colors.pink.withOpacity(0.2),
              ],
            ),
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
              : Stack(
                  children: [
                    // Main visualization
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_note,
                            color: _isPlaying ? Colors.orange : Colors.white.withOpacity(0.8),
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            )
                          else if (widget.generation.audioUrl != null)
                            Text(
                              _isPlaying ? 'Playing...' : 'Ready to play',
                              style: TextStyle(
                                color: _isPlaying ? Colors.orange : Colors.white54,
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
                    
                    // Status badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.generation.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(widget.generation.status),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(widget.generation.status),
                              color: _getStatusColor(widget.generation.status),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.generation.status.name,
                              style: TextStyle(
                                color: _getStatusColor(widget.generation.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Favorite badge
                    if (widget.generation.isFavorite)
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                  ],
                ),
        ),
        
        const SizedBox(height: 16),
        
        // Progress Slider
        if (_duration.inMilliseconds > 0) ...[
          Slider(
            value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
            max: _duration.inMilliseconds.toDouble(),
            onChanged: (value) {
              _seekTo(Duration(milliseconds: value.toInt()));
            },
            activeColor: Colors.orange,
            inactiveColor: Colors.white24,
          ),
          
          // Time Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDurationTime(_position),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _formatDurationTime(_duration),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ] else if (widget.generation.duration != null) ...[
          Text(
            'Duration: ${_formatDuration(widget.generation.duration!)}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
        
        const SizedBox(height: 16),
        
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
                    color: Colors.orange,
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
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Asset', widget.asset?.name ?? 'Unknown'),
          _buildInfoRow('Generation ID', widget.generation.id),
          _buildInfoRow('Asset ID', widget.generation.assetId),
          _buildInfoRow('Created', _formatDetailedDateTime(widget.generation.createdAt)),
          if (widget.generation.duration != null)
            _buildInfoRow('Duration', _formatDuration(widget.generation.duration!)),
          if (widget.generation.fileSize != null)
            _buildInfoRow('File Size', '${(widget.generation.fileSize! / 1024).toStringAsFixed(2)} KB'),
          if (widget.generation.format != null)
            _buildInfoRow('Format', widget.generation.format!.toUpperCase()),
          if (widget.generation.audioPath != null && widget.generation.audioPath!.isNotEmpty)
            _buildPathRow('Audio Path', widget.generation.audioPath!),
          if (widget.generation.audioUrl != null && widget.generation.audioUrl!.isNotEmpty)
            _buildPathRow('Audio URL', widget.generation.audioUrl!),
        ],
      ),
    );
  }

  Widget _buildParametersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generation Parameters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.generation.parameters['prompt'] != null) ...[
            const Text(
              'Prompt',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.generation.parameters['prompt'].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.generation.parameters['music_length_ms'] != null)
            _buildInfoRow(
              'Target Length',
              '${widget.generation.parameters['music_length_ms']} ms (${(widget.generation.parameters['music_length_ms'] / 1000).toStringAsFixed(1)}s)',
            ),
          // Show any other parameters
          ...widget.generation.parameters.entries
              .where((e) => e.key != 'prompt' && e.key != 'music_length_ms')
              .map((e) => _buildInfoRow(
                    e.key.replaceAll('_', ' ').toUpperCase(),
                    e.value.toString(),
                  )),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metadata',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.generation.metadata.entries.map((e) =>
            _buildInfoRow(e.key, e.value.toString())
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathRow(String label, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    path,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: path));
                  },
                  icon: const Icon(Icons.copy, color: Colors.white54, size: 16),
                  tooltip: 'Copy path',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  String _formatDurationTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatDetailedDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(GenerationStatus status) {
    switch (status) {
      case GenerationStatus.completed:
        return Colors.green;
      case GenerationStatus.generating:
        return Colors.orange;
      case GenerationStatus.failed:
        return Colors.red;
      case GenerationStatus.pending:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(GenerationStatus status) {
    switch (status) {
      case GenerationStatus.completed:
        return Icons.check_circle;
      case GenerationStatus.generating:
        return Icons.hourglass_empty;
      case GenerationStatus.failed:
        return Icons.error;
      case GenerationStatus.pending:
        return Icons.pending;
    }
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

    try {
      // Generate a default filename based on generation data
      final defaultFileName = _generateDefaultFileName();
      
      // Show "Save As" dialog
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Music File',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'aac', 'm4a'],
      );
      
      if (outputFile == null) {
        // User cancelled the dialog
        return;
      }
      
      // Show downloading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $defaultFileName...'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Download file content using dio
      final dio = Dio();
      final response = await dio.get(
        audioUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5), // 5 minute timeout for large files
        ),
      );
      
      // Write to selected location
      final outputFileObj = File(outputFile);
      await outputFileObj.writeAsBytes(response.data);
      
      // Show success message with file location
      final fileName = outputFileObj.path.split(Platform.pathSeparator).last;
      final directory = outputFileObj.parent.path;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$fileName" to $directory'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      String errorMessage = 'Error downloading music: ';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateDefaultFileName() {
    // Generate a filename based on the prompt or asset name
    String baseName = 'music';
    
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
}

