import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../utils/app_constants.dart';

/// Widget to display API connection status
class ApiStatusIndicator extends StatelessWidget {
  final bool showLabel;
  final bool compact;
  
  const ApiStatusIndicator({
    Key? key,
    this.showLabel = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show if API service is enabled
    if (!ApiConfig.enabled) return const SizedBox.shrink();
    
    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        return _buildStatusIndicator(context, provider);
      },
    );
  }

  Widget _buildStatusIndicator(BuildContext context, ImageGenerationProvider provider) {
    final isConnected = provider.isApiConnected;
    final color = isConnected ? Colors.green : Colors.red;
    final icon = isConnected ? Icons.cloud_done : Icons.cloud_off;
    final status = isConnected ? 'Connected' : 'Disconnected';

    if (compact) {
      return Tooltip(
        message: 'API Status: $status',
        child: Icon(
          icon,
          color: color,
          size: 16,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget to display detailed API information
class ApiInfoCard extends StatelessWidget {
  const ApiInfoCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.enabled) {
      return Card(
        color: const Color(0xFF2A2A2A),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'API Configuration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Using Mock Service',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'To use the API service, enable it in the configuration.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        return Card(
          color: const Color(0xFF2A2A2A),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.api, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'API Configuration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ApiStatusIndicator(compact: true),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Endpoint', ApiConfig.baseUrl),
                _buildInfoRow('Status', provider.isApiConnected ? 'Connected' : 'Disconnected'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _testConnection(context, provider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF404040),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
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
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(BuildContext context, ImageGenerationProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final isConnected = await provider.testApiConnection();
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            isConnected 
              ? 'API connection successful!' 
              : 'API connection failed. Check your backend service.',
          ),
          backgroundColor: isConnected ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Connection test failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
} 