import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/image_generation_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/app_constants.dart';
import '../../../services/comfyui_service.dart';

class ImageGenerationHeaderWidget extends StatelessWidget {
  final VoidCallback onShowServiceLogs;

  const ImageGenerationHeaderWidget({
    Key? key,
    required this.onShowServiceLogs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.onSurface,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'AI Image Generation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const Spacer(),
              if (Provider.of<SettingsProvider>(context, listen: false).a1111Mode == A1111Mode.local) ...[
                _buildAIServiceStatusIndicator(context, provider),
                const SizedBox(width: 16),
                _buildAIServiceControls(context, provider),
              ] else
                _buildAIServiceControls(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAIServiceStatusIndicator(BuildContext context, ImageGenerationProvider provider) {
    final status = provider.serviceStatus;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case AIServiceStatus.running:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Running';
        break;
      case AIServiceStatus.starting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Starting...';
        break;
      case AIServiceStatus.stopping:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Stopping...';
        break;
      case AIServiceStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Error';
        break;
      case AIServiceStatus.stopped:
        statusColor = Colors.red;
        statusIcon = Icons.stop_circle;
        statusText = 'Stopped';
        break;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${provider.currentBackendName}: $statusText',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
            ),
            if (status == AIServiceStatus.running &&
                provider.currentBackendName == 'Automatic1111' &&
                provider.currentA1111Checkpoint != null &&
                Provider.of<SettingsProvider>(context, listen: false).a1111Mode == A1111Mode.local)
              Text(
                'Checkpoint: ${_getCheckpointDisplayName(provider.currentA1111Checkpoint!)}',
                style: TextStyle(
                  color: statusColor.withOpacity(0.8),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _getCheckpointDisplayName(String checkpointTitle) {
    final hashMatch = RegExp(r'\s*\[[a-fA-F0-9]+\]$').firstMatch(checkpointTitle);
    if (hashMatch != null) {
      return checkpointTitle.substring(0, hashMatch.start);
    }
    return checkpointTitle;
  }

  Widget _buildAIServiceControls(BuildContext context, ImageGenerationProvider provider) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isA1111Online = provider.currentBackendName == 'Automatic1111' &&
        settingsProvider.a1111Mode == A1111Mode.online;

    if (isA1111Online) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud, color: Colors.blue, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Using Online API',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (!provider.isServiceRunning)
          ElevatedButton.icon(
            onPressed: provider.isServiceStarting ? null : () => provider.startService(),
            icon: provider.isServiceStarting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.play_arrow, color: Colors.white),
            label: Text(
              provider.isServiceStarting ? 'Starting...' : 'Start AI Service',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        if (provider.isServiceRunning)
          ElevatedButton.icon(
            onPressed: provider.isServiceStopping ? null : () => provider.stopService(),
            icon: provider.isServiceStopping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.stop, color: Colors.white),
            label: Text(
              provider.isServiceStopping ? 'Stopping...' : 'Stop AI Service',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onShowServiceLogs,
          icon: const Icon(Icons.article, color: Colors.white54),
          tooltip: 'Show Service Logs',
        ),
      ],
    );
  }
}

