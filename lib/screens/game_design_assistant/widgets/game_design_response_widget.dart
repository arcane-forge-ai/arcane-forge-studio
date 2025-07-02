import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/api_models.dart';
import '../services/document_extractor.dart';
import '../providers/project_provider.dart';

class GameDesignResponseWidget extends StatelessWidget {
  final String response;

  const GameDesignResponseWidget({
    Key? key,
    required this.response,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasExtractableDocument = DocumentExtractor.hasExtractableDocument(response);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main response content
        MarkdownBody(
          data: response,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
            code: TextStyle(
              backgroundColor: Colors.grey[100],
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
          ),
        ),
        
        // Document extraction card
        if (hasExtractableDocument) ...[
          const SizedBox(height: 16),
          _buildExtractionCard(context),
        ],
      ],
    );
  }

  Widget _buildExtractionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Document Available for Extraction',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This response contains a game design document that can be extracted and saved to your project.',
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _extractDocument(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Extract Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _previewDocument(context),
                icon: const Icon(Icons.preview, size: 18),
                label: const Text('Preview'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _extractDocument(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final currentProject = projectProvider.currentProject;
    
    if (currentProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active project found. Please initialize a project first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final extractedDocument = DocumentExtractor.createExtractedDocument(
      response,
      currentProject.id,
      'response_${DateTime.now().millisecondsSinceEpoch}', // Source message ID
    );

    if (extractedDocument != null) {
      projectProvider.addExtractedDocument(extractedDocument);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document "${extractedDocument.title}" extracted successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _showExtractedDocument(context, extractedDocument),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to extract document from response.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _previewDocument(BuildContext context) {
    final extractedContent = DocumentExtractor.extractMarkdownBlock(response);
    
    if (extractedContent != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Document Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: extractedContent,
                selectable: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _extractDocument(context);
              },
              child: const Text('Extract'),
            ),
          ],
        ),
      );
    }
  }

  void _showExtractedDocument(BuildContext context, ExtractedDocument document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extracted: ${document.extractedAt.toString().split('.')[0]}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: document.content,
                  selectable: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 