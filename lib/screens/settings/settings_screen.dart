import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_constants.dart';
import '../../models/download_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state for pending changes
  late bool _mockMode;
  late bool _darkMode;
  late String _apiBaseUrl;
  late ImageGenerationBackend _defaultBackend;
  late Map<ImageGenerationBackend, String> _commands;
  late Map<ImageGenerationBackend, String> _workingDirectories;
  late Map<ImageGenerationBackend, String> _endpoints;
  late Map<ImageGenerationBackend, String> _healthCheckEndpoints;
  
  // Controllers for text fields
  final TextEditingController _apiBaseUrlController = TextEditingController();
  final Map<ImageGenerationBackend, TextEditingController> _commandControllers = {};
  final Map<ImageGenerationBackend, TextEditingController> _workingDirControllers = {};
  final Map<ImageGenerationBackend, TextEditingController> _endpointControllers = {};
  final Map<ImageGenerationBackend, TextEditingController> _healthCheckEndpointControllers = {};
  
  bool _hasUnsavedChanges = false;
  bool _hasInitialized = false;
  bool _a1111SnackShown = false;
  Timer? _progressPollTimer;

  /// Check if we're in development mode
  bool get _isDevelopmentMode {
    const environment = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');
    return environment.toLowerCase() == 'development';
  }

  @override
  void initState() {
    super.initState();
    // Initialize will happen in build method after provider is available
    
    // Start polling timer for A1111 download progress updates
    // Only updates UI when downloading is active
    _progressPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final provider = Provider.of<SettingsProvider>(context, listen: false);
        if (provider.a1111Status == InstallerStatus.downloading) {
          setState(() {}); // Trigger rebuild to show updated progress
        }
      }
    });
  }

  void _initializeFromProvider(SettingsProvider settingsProvider) {
    // Initialize local state from provider
    _mockMode = settingsProvider.useMockMode; // Still initialize for consistency
    _darkMode = settingsProvider.isDarkMode;
    _apiBaseUrl = settingsProvider.apiBaseUrl;
    _defaultBackend = settingsProvider.defaultGenerationServer;
    
    // Initialize API base URL controller
    _apiBaseUrlController.text = _apiBaseUrl;
    
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
    // Cancel polling timer
    _progressPollTimer?.cancel();
    
    // Dispose controllers
    _apiBaseUrlController.dispose();
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

  void _saveSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // Save all settings
    if (!_isDevelopmentMode) {
      settingsProvider.setMockMode(_mockMode);
    }
    settingsProvider.setThemeMode(_darkMode);
    settingsProvider.setApiBaseUrl(_apiBaseUrl);
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

  void _resetSettings(BuildContext context, SettingsProvider settingsProvider) {
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
              _initializeFromProvider(settingsProvider);
              setState(() {
                _hasUnsavedChanges = false;
                _hasInitialized = true; // Keep as initialized since we're just resetting
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
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // Show loading screen while settings are being loaded
    if (settingsProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading settings...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Initialize local state from provider (only after loading is complete and not already initialized)
    if (!_hasInitialized) {
      _initializeFromProvider(settingsProvider);
      _hasInitialized = true;
    }

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
                color: colorScheme.secondaryContainer,
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
                    onPressed: () => _resetSettings(context, settingsProvider),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: Text('Save Changes', style: TextStyle(color: colorScheme.secondary),),
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
            // Environment indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isDevelopmentMode
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDevelopmentMode ? Colors.orange : Colors.green,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isDevelopmentMode ? Icons.build : Icons.production_quantity_limits,
                    size: 16,
                    color: _isDevelopmentMode ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isDevelopmentMode ? 'Development Mode' : 'Production Mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isDevelopmentMode ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
              title: 'Backend API Configuration',
              icon: Icons.api,
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
                              Icons.link,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'API Base URL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _apiBaseUrlController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter the API base URL...',
                            contentPadding: EdgeInsets.all(12),
                          ),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          onChanged: (value) {
                            _apiBaseUrl = value;
                            _markAsChanged();
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Example: http://localhost:8000',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Only show Mock API Mode setting when in development mode
                if (_isDevelopmentMode)
                  Card(
                    child: SwitchListTile(
                      title: const Text('Mock API Mode'),
                      subtitle: Text(
                        _mockMode
                            ? 'Using mock data for development (no backend needed)'
                            : 'Connecting to backend API at configured URL',
                      ),
                      value: _mockMode,
                      onChanged: (bool value) {
                        setState(() {
                          _mockMode = value;
                        });
                        // Auto-save for switches (only when not in development mode)
                        if (!_isDevelopmentMode) {
                          Provider.of<SettingsProvider>(context, listen: false).setMockModeAutoSave(value);
                        }
                      },
                      secondary: Icon(
                        _mockMode ? Icons.science : Icons.cloud_done,
                        color: _mockMode ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Only show "How It Works" explanation when Mock Mode setting is visible
                if (_isDevelopmentMode)
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
                                'How It Works',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• API Base URL: Your backend server address (applied immediately after saving)\n'
                            '• Mock Mode OFF: Connects to real backend API for projects, chat, and asset generation\n'
                            '• Mock Mode ON: Uses simulated data for development and testing (no backend required)\n'
                            '• Recommended: Use Mock Mode during development, turn OFF for production',
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
                              color: _darkMode ? Colors.deepOrange : Colors.amber,
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
                        // Output Directory
                        Text(
                          'Output Directory',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Consumer<SettingsProvider>(
                          builder: (context, settingsProvider, child) {
                            final controller = TextEditingController(text: settingsProvider.outputDirectory);
                            return TextFormField(
                              controller: controller,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Enter the output directory for generated contents...',
                                contentPadding: EdgeInsets.all(12),
                              ),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              onChanged: (value) {
                                settingsProvider.setOutputDirectory(value);
                              },
                            );
                          },
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
                if (backend == ImageGenerationBackend.automatic1111)
                  Consumer<SettingsProvider>(
                    builder: (context, sp, _) {
                      // Show success snackbar once
                      if (sp.a1111Status == InstallerStatus.completed && !_a1111SnackShown) {
                        _a1111SnackShown = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('A1111 installed successfully'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        });
                      }

                      Widget content;
                      switch (sp.a1111Status) {
                        case InstallerStatus.downloading:
                          final percent = sp.a1111Progress != null
                              ? (sp.a1111Progress! * 100).clamp(0, 100).toStringAsFixed(0)
                              : null;
                          content = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.download, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Downloading A1111 from Supabase'),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: sp.cancelA1111Install,
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: sp.a1111Progress),
                              const SizedBox(height: 8),
                              Text(
                                percent != null
                                    ? '$percent%'
                                    : 'Downloading...',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                            ],
                          );
                          break;
                        case InstallerStatus.extracting:
                          content = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.archive_outlined, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Extracting A1111...'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(),
                            ],
                          );
                          break;
                        case InstallerStatus.completed:
                          content = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('A1111 is installed'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Location: ./packages/automatic1111/',
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                              ),
                            ],
                          );
                          break;
                        case InstallerStatus.error:
                          content = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.red),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Installation failed'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => sp.startA1111Install(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                              if (sp.a1111Error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Error: ${sp.a1111Error}',
                                  style: const TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ],
                            ],
                          );
                          break;
                        case InstallerStatus.idle:
                          content = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.cloud_download, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Download and install Automatic1111 from Supabase'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => sp.startA1111Install(),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Downloads to ./packages/, installs to ./packages/automatic1111/',
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                              ),
                            ],
                          );
                      }

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: content,
                        ),
                      );
                    },
                  ),
                if (backend == ImageGenerationBackend.automatic1111)
                  const SizedBox(height: 16),
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