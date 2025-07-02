import '../models/api_models.dart';
import 'package:uuid/uuid.dart';

class DocumentExtractor {
  static const int _minDocumentLength = 100;
  static const _uuid = Uuid();

  /// Extract markdown blocks from AI response content
  static String? extractMarkdownBlock(String content) {
    // Look for markdown code blocks with ``` markers
    final RegExp markdownPattern = RegExp(
      r'```(?:markdown)?\s*\n(.*?)\n```',
      dotAll: true,
      caseSensitive: false,
    );

    final match = markdownPattern.firstMatch(content);
    if (match != null) {
      String extracted = match.group(1)?.trim() ?? '';
      
      // Validate minimum length
      if (extracted.length >= _minDocumentLength) {
        return extracted;
      }
    }

    return null;
  }

  /// Check if content contains extractable document
  static bool hasExtractableDocument(String content) {
    return extractMarkdownBlock(content) != null;
  }

  /// Create ExtractedDocument from AI response
  static ExtractedDocument? createExtractedDocument(
    String content,
    String projectId,
    String sourceMessageId,
  ) {
    final extractedContent = extractMarkdownBlock(content);
    if (extractedContent == null) return null;

    // Try to extract title from first heading
    String title = _extractTitle(extractedContent);

    return ExtractedDocument(
      id: _uuid.v4(),
      title: title,
      content: extractedContent,
      projectId: projectId,
      extractedAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
    );
  }

  /// Extract title from document content (first heading or fallback)
  static String _extractTitle(String content) {
    // Look for first markdown heading
    final RegExp headingPattern = RegExp(r'^#{1,6}\s+(.+)$', multiLine: true);
    final match = headingPattern.firstMatch(content);
    
    if (match != null) {
      return match.group(1)?.trim() ?? 'Extracted Document';
    }

    // Fallback: use first line or generic title
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
    if (lines.isNotEmpty) {
      String firstLine = lines.first.trim();
      // Remove markdown symbols from first line
      firstLine = firstLine.replaceAll(RegExp(r'^#{1,6}\s*'), '');
      firstLine = firstLine.replaceAll(RegExp(r'^\*+\s*'), '');
      
      if (firstLine.length > 50) {
        firstLine = '${firstLine.substring(0, 47)}...';
      }
      return firstLine.isNotEmpty ? firstLine : 'Extracted Document';
    }

    return 'Game Design Document';
  }

  /// Validate if content appears to be game design related (optional enhancement)
  static bool isGameDesignContent(String content) {
    final gameDesignKeywords = [
      'game', 'player', 'character', 'level', 'mechanic', 'gameplay',
      'quest', 'story', 'narrative', 'design', 'system', 'progression',
      'combat', 'skill', 'attribute', 'inventory', 'weapon', 'enemy',
      'boss', 'world', 'map', 'environment', 'ui', 'interface',
    ];

    final lowerContent = content.toLowerCase();
    return gameDesignKeywords.any((keyword) => lowerContent.contains(keyword));
  }
} 