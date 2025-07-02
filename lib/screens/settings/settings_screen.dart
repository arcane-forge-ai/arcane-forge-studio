import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surface.withOpacity(0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure application preferences and behavior',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            
            // API Settings Section
            _buildSettingsSection(
              context,
              title: 'API Settings',
              icon: Icons.api,
              children: [
                Consumer<SettingsProvider>(
                  builder: (context, settingsProvider, child) {
                    return Card(
                      child: SwitchListTile(
                        title: const Text('Mock API Mode'),
                        subtitle: Text(
                          settingsProvider.useMockMode
                              ? 'Using mock data for development'
                              : 'Using live API endpoints',
                        ),
                        value: settingsProvider.useMockMode,
                        onChanged: (bool value) {
                          settingsProvider.setMockMode(value);
                          
                          // Show feedback to user
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value 
                                    ? 'Switched to mock API mode'
                                    : 'Switched to live API mode',
                              ),
                              backgroundColor: value ? Colors.orange : Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        secondary: Icon(
                          settingsProvider.useMockMode 
                              ? Icons.science 
                              : Icons.cloud,
                          color: settingsProvider.useMockMode 
                              ? Colors.orange 
                              : Colors.green,
                        ),
                      ),
                    );
                  }
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mock Mode Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Mock mode uses simulated data for development and testing\n'
                          '• Live mode connects to actual API endpoints\n'
                          '• Changes apply immediately to all API calls\n'
                          '• Mock responses include realistic game design content',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Future Settings Sections
            _buildSettingsSection(
              context,
              title: 'Application',
              icon: Icons.settings,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.construction),
                    title: const Text('Theme Settings'),
                    subtitle: const Text('Coming soon...'),
                    enabled: false,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.construction),
                    title: const Text('Language Settings'),
                    subtitle: const Text('Coming soon...'),
                    enabled: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
} 