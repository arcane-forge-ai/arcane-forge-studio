import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/qa_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/qa_api_service.dart';
import 'dialogs/responsibility_area_dialog.dart';

/// Screen for managing Responsibility Areas
/// Only accessible to project owners
class ResponsibilityAreasScreen extends StatefulWidget {
  final String projectId;
  final String? projectName;

  const ResponsibilityAreasScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  State<ResponsibilityAreasScreen> createState() => _ResponsibilityAreasScreenState();
}

class _ResponsibilityAreasScreenState extends State<ResponsibilityAreasScreen> {
  late final QAApiService _qaApiService;
  List<ResponsibilityArea>? _areas;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    _qaApiService = QAApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );

    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final areas = await _qaApiService.listResponsibilityAreas(widget.projectId);
      setState(() {
        _areas = areas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load responsibility areas: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createArea() async {
    final result = await showDialog<ResponsibilityArea>(
      context: context,
      builder: (context) => ResponsibilityAreaDialog(
        projectId: widget.projectId,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        await _qaApiService.createResponsibilityArea(widget.projectId, result);
        await _loadAreas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Responsibility area created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to create responsibility area: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editArea(ResponsibilityArea area) async {
    final result = await showDialog<ResponsibilityArea>(
      context: context,
      builder: (context) => ResponsibilityAreaDialog(
        area: area,
        projectId: widget.projectId,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        await _qaApiService.updateResponsibilityArea(
          widget.projectId,
          area.id!,
          result,
        );
        await _loadAreas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Responsibility area updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to update responsibility area: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteArea(ResponsibilityArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Responsibility Area'),
        content: Text(
          'Are you sure you want to delete "${area.areaName}"?\n\n'
          'This will affect automatic escalation in Q&A.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        await _qaApiService.deleteResponsibilityArea(widget.projectId, area.id!);
        await _loadAreas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Responsibility area deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to delete responsibility area: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName != null
            ? '${widget.projectName} - Responsibility Areas'
            : 'Responsibility Areas'),
      ),
      body: Column(
        children: [
          // Header with description
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 32,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Responsibility Areas',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Define who owns what in your project for automatic Q&A escalation',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error message
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _error = null),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading responsibility areas...'),
                  ],
                ),
              ),
            )
          else if (_areas == null)
            const Expanded(
              child: Center(
                child: Text('Failed to load areas'),
              ),
            )
          else if (_areas!.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: theme.dividerColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No responsibility areas yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.textTheme.titleLarge?.color?.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first area to enable automatic Q&A escalation',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _createArea,
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Area'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _areas!.length,
                itemBuilder: (context, index) {
                  final area = _areas![index];
                  return _buildAreaCard(area);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _areas != null && _areas!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _createArea,
              icon: const Icon(Icons.add),
              label: const Text('New Area'),
            )
          : null,
    );
  }

  Widget _buildAreaCard(ResponsibilityArea area) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    area.areaName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _editArea(area),
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: () => _deleteArea(area),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Keywords
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: area.areaKeywords
                  .map((keyword) => Chip(
                        label: Text(keyword),
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 12,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Contact info
            _buildInfoRow(
              Icons.email,
              'Internal Contact',
              area.internalContact,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.badge,
              'External Display',
              area.externalDisplayName,
            ),
            if (area.contactMethod != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.chat,
                'Contact Method',
                area.contactMethod!,
              ),
            ],
            if (area.notes != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        area.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    // Use onSurface to ensure contrast, fallback to white/light grey if theme is broken
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = textColor.withOpacity(0.7);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: mutedColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
