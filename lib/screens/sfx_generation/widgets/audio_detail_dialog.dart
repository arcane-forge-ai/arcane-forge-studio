import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../models/sfx_generation_models.dart';

class AudioDetailDialog extends StatefulWidget {
  final SfxGeneration generation;
  final SfxAsset? asset;
  final VoidCallback? onFavoriteToggle;

  const AudioDetailDialog({
    super.key,
    required this.generation,
    this.asset,
    this.onFavoriteToggle,
  });

  @override
  State<AudioDetailDialog> createState() => _AudioDetailDialogState();
}

class _AudioDetailDialogState extends State<AudioDetailDialog> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = state == PlayerState.playing && _position == Duration.zero;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
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
        child: isLargeScreen ? _buildLargeScreenLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return Row(
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
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
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
                value: _position.inMilliseconds.toDouble(),
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
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: widget.onFavoriteToggle,
                    icon: Icon(
                      widget.generation.isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    color: widget.generation.isFavorite ? Colors.red : Colors.white,
                    iconSize: 32,
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
            _buildDetailItem('Favorite', widget.generation.isFavorite ? 'Yes' : 'No'),
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
    details.writeln('Favorite: ${widget.generation.isFavorite ? 'Yes' : 'No'}');
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
} 