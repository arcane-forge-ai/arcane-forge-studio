import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state for pending changes
  late bool _mockMode;
  late bool _darkMode;
  late ImageGenerationBackend _defaultBackend;
  late Map<ImageGenerationBackend, String> _commands;
  late Map<ImageGenerationBackend, String> _workingDirectories;
  late Map<ImageGenerationBackend, String> _endpoints;
  late Map<ImageGenerationBackend, String> _healthCheckEndpoints;
  
  // Controllers for text fields
  final Map<ImageGenerationBackend, TextEditingController> _commandControllers = {};
  final Map<ImageGenerationBackend, TextEditingController> _workingDirControllers = {};
  final Map<ImageGenerationBackend, TextEditingController> _endpointControllers = {};
  final Map<ImageGenerationBackend, TextEditingController> _healthCheckEndpointControllers = {};
  
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeFromProvider();
  }

  void _initializeFromProvider() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // Initialize local state from provider
    _mockMode = settingsProvider.useMockMode;
    _darkMode = settingsProvider.isDarkMode;
    _defaultBackend = settingsProvider.defaultGenerationServer;
    
    // Initialize maps
    _commands = {};
    _workingDirectories = {};
    _endpoints = {};
    _healthCheckEndpoints = {};
    
    // Initialize controllers and values for each backend
    for (final backend in ImageGenerationBackend.values) {
      final command = settingsProvider.getStartCommand(backend);
      final workingDir = settingsProvider.getWorkingDirectory(backend);
      final endpoint = settingsProvider.getEndpoint(backend);
      final healthCheckEndpoint = settingsProvider.getHealthCheckEndpoint(backend);
      
      _commands[backend] = command;
      _workingDirectories[backend] = workingDir;
      _endpoints[backend] = endpoint;
      _healthCheckEndpoints[backend] = healthCheckEndpoint;
      
      _commandControllers[backend] = TextEditingController(text: command);
      _workingDirControllers[backend] = TextEditingController(text: workingDir);
      _endpointControllers[backend] = TextEditingController(text: endpoint);
      _healthCheckEndpointControllers[backend] = TextEditingController(text: healthCheckEndpoint);
    }
  }

  @override
  void dispose() {
    // Dispose controllers
    for (final controller in _commandControllers.values) {
      controller.dispose();
    }
    for (final controller in _workingDirControllers.values) {
      controller.dispose();
    }
    for (final controller in _endpointControllers.values) {
      controller.dispose();
    }
    for (final controller in _healthCheckEndpointControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  bool _hasChanges() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    if (_mockMode != settingsProvider.useMockMode ||
        _darkMode != settingsProvider.isDarkMode ||
        _defaultBackend != settingsProvider.defaultGenerationServer) {
      return true;
    }
    
    for (final backend in ImageGenerationBackend.values) {
      if (_commands[backend] != settingsProvider.getStartCommand(backend) ||
          _workingDirectories[backend] != settingsProvider.getWorkingDirectory(backend) ||
          _endpoints[backend] != settingsProvider.getEndpoint(backend) ||
          _healthCheckEndpoints[backend] != settingsProvider.getHealthCheckEndpoint(backend)) {
        return true;
      }
    }
    
    return false;
  }

  void _saveSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // Save all settings
    settingsProvider.setMockMode(_mockMode);
    settingsProvider.setThemeMode(_darkMode);
    settingsProvider.setDefaultGenerationServer(_defaultBackend);
    
    for (final backend in ImageGenerationBackend.values) {
      settingsProvider.setStartCommand(backend, _commands[backend]!);
      settingsProvider.setWorkingDirectory(backend, _workingDirectories[backend]!);
      settingsProvider.setEndpoint(backend, _endpoints[backend]!);
      settingsProvider.setHealthCheckEndpoint(backend, _healthCheckEndpoints[backend]!);
    }
    
    setState(() {
      _hasUnsavedChanges = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to discard all unsaved changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeFromProvider();
              setState(() {
                _hasUnsavedChanges = false;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Changes discarded'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

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
      child: Column(
        children: [
          // Save/Reset button bar
          if (_hasUnsavedChanges)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'You have unsaved changes',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetSettings,
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          
          // Settings content
          Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
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
                        Card(
                      child: SwitchListTile(
                        title: const Text('Mock API Mode'),
                        subtitle: Text(
                              _mockMode
                              ? 'Using mock data for development'
                              : 'Using live API endpoints',
                        ),
                            value: _mockMode,
                        onChanged: (bool value) {
                              setState(() {
                                _mockMode = value;
                              });
                              // Auto-save for switches
                              Provider.of<SettingsProvider>(context, listen: false).setMockModeAutoSave(value);
                            },
                            secondary: Icon(
                              _mockMode ? Icons.science : Icons.cloud,
                              color: _mockMode ? Colors.orange : Colors.green,
                            ),
                          ),
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
                                  '• Changes apply after saving settings\n'
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
            
            // Application Settings Section
            _buildSettingsSection(
              context,
              title: 'Application',
              icon: Icons.settings,
              children: [
                        Card(
                      child: SwitchListTile(
                        title: const Text('Dark Mode'),
                        subtitle: Text(
                              _darkMode
                              ? 'Using dark theme'
                              : 'Using light theme',
                        ),
                            value: _darkMode,
                        onChanged: (bool value) {
                              setState(() {
                                _darkMode = value;
                              });
                              // Auto-save for switches
                              Provider.of<SettingsProvider>(context, listen: false).setThemeModeAutoSave(value);
                            },
                            secondary: Icon(
                              _darkMode ? Icons.dark_mode : Icons.light_mode,
                              color: _darkMode ? Colors.indigo : Colors.amber,
                            ),
                          ),
                ),
                const SizedBox(height: 16),
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
                    
                    const SizedBox(height: 32),
                    
                    // Image Generation Settings Section
                    _buildSettingsSection(
                      context,
                      title: 'Image Generation',
                      icon: Icons.image,
                      children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                                      Icons.settings_input_composite,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                                      'Default Generation Server',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                                DropdownButtonFormField<ImageGenerationBackend>(
                                  value: _defaultBackend,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: ImageGenerationBackend.values.map((backend) {
                                    return DropdownMenuItem(
                                      value: backend,
                                      child: Text(backend.displayName),
                                    );
                                  }).toList(),
                                  onChanged: (ImageGenerationBackend? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _defaultBackend = newValue;
                                      });
                                      _markAsChanged();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Backend Configuration Cards
                        ...ImageGenerationBackend.values.take(2).map((backend) => 
                          _buildBackendConfigCard(context, backend)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendConfigCard(BuildContext context, ImageGenerationBackend backend) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: ExpansionTile(
        leading: Icon(
          backend == ImageGenerationBackend.automatic1111 ? Icons.auto_awesome : Icons.layers,
          color: colorScheme.primary,
        ),
        title: Text(
          '${backend.displayName} Configuration',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start Command
                Text(
                  'Start Command',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commandControllers[backend],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter the command to start the server...',
                    contentPadding: EdgeInsets.all(12),
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: (value) {
                    _commands[backend] = value;
                    _markAsChanged();
                  },
                ),
                const SizedBox(height: 16),
                
                // Working Directory
                Text(
                  'Working Directory',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _workingDirControllers[backend],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter the working directory path...',
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: (value) {
                    _workingDirectories[backend] = value;
                    _markAsChanged();
                  },
                ),
                const SizedBox(height: 16),
                
                // API Endpoint
                Text(
                  'API Endpoint',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _endpointControllers[backend],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter the API endpoint URL...',
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: (value) {
                    _endpoints[backend] = value;
                    _markAsChanged();
                  },
                ),
                const SizedBox(height: 16),
                
                // Health Check Endpoint
                Text(
                  'Health Check Endpoint',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _healthCheckEndpointControllers[backend],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter the health check endpoint path...',
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: (value) {
                    _healthCheckEndpoints[backend] = value;
                    _markAsChanged();
                  },
                ),
                const SizedBox(height: 16),
                
                // Reset to Defaults Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final defaultCommand = ImageGenerationConstants.defaultCommands[backend] ?? '';
                      final defaultWorkingDir = ImageGenerationConstants.defaultWorkingDirectories[backend] ?? '';
                      final defaultEndpoint = ImageGenerationConstants.defaultEndpoints[backend] ?? '';
                      final defaultHealthCheckEndpoint = ImageGenerationConstants.defaultHealthCheckEndpoints[backend] ?? '';
                      
                      setState(() {
                        _commands[backend] = defaultCommand;
                        _workingDirectories[backend] = defaultWorkingDir;
                        _endpoints[backend] = defaultEndpoint;
                        _healthCheckEndpoints[backend] = defaultHealthCheckEndpoint;
                        
                        _commandControllers[backend]!.text = defaultCommand;
                        _workingDirControllers[backend]!.text = defaultWorkingDir;
                        _endpointControllers[backend]!.text = defaultEndpoint;
                        _healthCheckEndpointControllers[backend]!.text = defaultHealthCheckEndpoint;
                      });
                      
                      _markAsChanged();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${backend.displayName} settings reset to defaults'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Defaults'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ],
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