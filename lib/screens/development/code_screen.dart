import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../constants.dart';
import '../../services/projects_api_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class CodeScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const CodeScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final TextEditingController _codeMapController = TextEditingController();

  bool _isEditingCodeMap = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _errorMessage;
  late ProjectsApiService _projectsApiService;

  @override
  void initState() {
    super.initState();
    _initializeApiService();
    _loadProject();
  }

  void _initializeApiService() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _projectsApiService = ProjectsApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  Future<void> _loadProject() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final project =
          await _projectsApiService.getProjectById(int.parse(widget.projectId));

      if (!mounted) return;
      setState(() {
        _codeMapController.text = project.codeMapUrl ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _saveCodeMapLink() async {
    final link = _codeMapController.text.trim();
    if (link.isNotEmpty && !_isValidUrl(link)) {
      _showSnackBar('Please enter a valid URL for Code Map Link');
      return;
    }
    await _updateProject(codeMapUrl: link.isEmpty ? null : link);
    if (!mounted) return;
    setState(() => _isEditingCodeMap = false);
  }

  Future<void> _updateProject({String? codeMapUrl}) async {
    try {
      if (!mounted) return;
      setState(() => _isSaving = true);

      await _projectsApiService.updateProject(
        projectId: widget.projectId,
        codeMapUrl: codeMapUrl,
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      _showSnackBar('Code map URL updated successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackBar('Failed to update code map URL: ${e.toString()}');
    }
  }

  Future<void> _uploadCodeMapFile() async {
    try {
      // Pick a file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'json'],
        withData: false,
        withReadStream: true,
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        setState(() => _isUploading = true);

        final file = File(result.files.single.path!);
        
        // Upload via API
        await _projectsApiService.uploadCodeMapFile(
          projectId: int.parse(widget.projectId),
          file: file,
        );

        // Reload project to get updated code map URL
        await _loadProject();

        _showSnackBar('Code map file uploaded successfully');
      }
    } catch (e) {
      _showSnackBar('Failed to upload code map file: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) return false;
    
    // Check if it's a relative URL starting with /
    if (value.startsWith('/')) {
      return true;
    }
    
    // Check if it's a full URL with http/https
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.hasAuthority;
  }

  /// Convert relative URL to absolute URL using API base URL
  String _getFullUrl(String url) {
    if (url.isEmpty) return url;
    
    if (url.startsWith('/')) {
      // Remove trailing slash from base URL if present, then add the relative path
      final baseUrl = _projectsApiService.baseUrl.replaceAll(RegExp(r'/$'), '');
      return '$baseUrl/api/v1$url';
    }
    
    return url;
  }

  Future<void> _openUrl(String value) async {
    final link = value.trim();
    if (!_isValidUrl(link)) {
      _showSnackBar('Invalid URL');
      return;
    }
    final fullUrl = _getFullUrl(link);
    final uri = Uri.parse(fullUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Could not open the link');
    }
  }

  Future<void> _copyToClipboard(String value, {String label = 'Link'}) async {
    if (value.trim().isEmpty) {
      _showSnackBar('$label is empty');
      return;
    }
    final fullUrl = _getFullUrl(value.trim());
    await Clipboard.setData(ClipboardData(text: fullUrl));
    _showSnackBar('$label copied to clipboard');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.code, size: 28, color: primaryColor),
                          const SizedBox(width: 12),
                          Text(
                            'Code',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _loadProject,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: defaultPadding * 1.5),

                      // Repository Info Section
                      _buildRepositoryInfoSection(),
                      
                      const SizedBox(height: defaultPadding * 2),

                      // Install MCPs Section
                      _buildInstallMcpsSection(),
                      
                      const SizedBox(height: defaultPadding * 2),

                      // Agent Section
                      _buildAgentSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Failed to load code information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProject,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepositoryInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Icons.folder_outlined, size: 22, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              'Repository Info',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your project\'s code map and repository documentation',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: defaultPadding),

        // Code Map Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined,
                        size: 24, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Code Map',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_isUploading || _isSaving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      Tooltip(
                        message: 'Upload File',
                        child: IconButton(
                          onPressed: _uploadCodeMapFile,
                          icon: const Icon(Icons.upload_file),
                        ),
                      ),
                      Tooltip(
                        message: _isEditingCodeMap ? 'Save' : 'Edit',
                        child: IconButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  if (_isEditingCodeMap) {
                                    _saveCodeMapLink();
                                  } else {
                                    setState(() => _isEditingCodeMap = true);
                                  }
                                },
                          icon: Icon(_isEditingCodeMap ? Icons.check : Icons.edit),
                        ),
                      ),
                      Tooltip(
                        message: 'Open Link',
                        child: IconButton(
                          onPressed: _codeMapController.text.isEmpty
                              ? null
                              : () => _openUrl(_codeMapController.text),
                          icon: const Icon(Icons.open_in_new),
                        ),
                      ),
                      Tooltip(
                        message: 'Copy to clipboard',
                        child: IconButton(
                          onPressed: _codeMapController.text.isEmpty
                              ? null
                              : () => _copyToClipboard(
                                    _codeMapController.text,
                                    label: 'Code map link',
                                  ),
                          icon: const Icon(Icons.copy),
                        ),
                      ),
                    ],
                  ],
                ),const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload a code map file (.md, .txt, .json) or provide a URL to your repository documentation',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeMapController,
                  readOnly: !_isEditingCodeMap,
                  onTap: !_isEditingCodeMap && _codeMapController.text.isNotEmpty
                      ? () => _openUrl(_codeMapController.text)
                      : null,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/code-map.md or upload a file',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor.withOpacity(0.04),
                    suffixIcon: _isEditingCodeMap
                        ? IconButton(
                            tooltip: 'Save',
                            icon: const Icon(Icons.check),
                            onPressed: _isSaving ? null : _saveCodeMapLink,
                          )
                        : null,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!_isEditingCodeMap && _codeMapController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isValidUrl(_codeMapController.text)
                                  ? Icons.verified
                                  : Icons.error_outline,
                              size: 16,
                              color: _isValidUrl(_codeMapController.text)
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isValidUrl(_codeMapController.text)
                                  ? 'Valid URL'
                                  : 'Invalid URL',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        // Show full URL if it's a relative path
                        if (_codeMapController.text.startsWith('/') &&
                            _isValidUrl(_codeMapController.text))
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Full URL: ${_getFullUrl(_codeMapController.text)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstallMcpsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Icons.extension_outlined, size: 22, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              'Install MCPs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Install Model Context Protocol servers to enhance your AI coding experience',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: defaultPadding),

        // MCP Buttons Grid
        Wrap(
          spacing: defaultPadding,
          runSpacing: defaultPadding,
          children: [
            _buildMcpButton(
              name: 'Flame MCP',
              logoPath: 'assets/icons/flame_logo.png',
              url: 'http://flame-mcp-server.dev.arcaneforge.ai/',
            ),
            _buildMcpButton(
              name: 'Flutter MCP',
              logoPath: 'assets/icons/flutter_logo.png',
              url: 'https://docs.flutter.dev/ai/mcp-server',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMcpButton({
    required String name,
    required String logoPath,
    required String url,
  }) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  logoPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Icons.smart_toy_outlined, size: 22, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              'Agent',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'AI-powered coding assistant for your project',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: defaultPadding),

        // Coming Soon Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding * 2),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.code,
                        size: 64,
                        // color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'AI Code Assistant',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Coming Soon Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'COMING SOON',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'An integrated AI-powered code editor and assistant is coming soon. You\'ll be able to write, edit, and test code directly within the platform with intelligent suggestions and automated refactoring.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Current Alternative
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: Colors.green.shade700, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'In the meantime',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can download all design docs from Knowledge Base,  install our MCPs and use any of your favorite AI-powered IDEs like Cursor, GitHub Copilot, or Windsurf to work on your game code.',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Progress Indicator
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'In Development',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _codeMapController.dispose();
    super.dispose();
  }
}


