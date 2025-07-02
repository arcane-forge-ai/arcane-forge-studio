import 'dart:convert';
import '../models/chat_message.dart' as app_models;
import '../models/api_models.dart';

/// Utility class to parse LangChain SQLChatMessageHistory format
class LangChainMessageParser {
  /// Parse a LangChain message string and convert to our ChatMessage format
  static app_models.ChatMessage? parseMessage(String? messageJson, {int? index}) {
    if (messageJson == null || messageJson.isEmpty) return null;

    try {
      // Try to parse as JSON
      final Map<String, dynamic> parsed = jsonDecode(messageJson);
      
      // Handle different LangChain formats
      if (parsed.containsKey('type') && parsed.containsKey('data')) {
        // Standard LangChain format: {"type": "human|ai", "data": {"content": "..."}}
        return _parseStandardFormat(parsed, index);
      } else if (parsed.containsKey('role') && parsed.containsKey('content')) {
        // OpenAI-style format: {"role": "user|assistant", "content": "..."}
        return _parseOpenAIFormat(parsed, index);
      } else if (parsed.containsKey('content')) {
        // Simple content format: {"content": "..."}
        return _parseSimpleFormat(parsed, index);
      } else {
        // Unknown format, try to extract content
        return _parseUnknownFormat(parsed, index);
      }
    } catch (e) {
      // If JSON parsing fails, treat as plain text
      return _parseAsPlainText(messageJson, index);
    }
  }

  /// Parse LangChain standard format: {"type": "human|ai", "data": {"content": "..."}}
  static app_models.ChatMessage _parseStandardFormat(Map<String, dynamic> parsed, int? index) {
    final String type = parsed['type'] ?? 'human';
    final Map<String, dynamic> data = parsed['data'] ?? {};
    final String content = data['content'] ?? '';
    
    // Convert LangChain types to our role format
    String role;
    switch (type.toLowerCase()) {
      case 'human':
      case 'user':
        role = 'user';
        break;
      case 'ai':
      case 'assistant':
        role = 'assistant';
        break;
      case 'system':
        role = 'system';
        break;
      default:
        role = 'user'; // Default to user
    }

    return app_models.ChatMessage(
      id: 'langchain_${index ?? DateTime.now().millisecondsSinceEpoch}',
      role: role,
      content: content,
      timestamp: _extractTimestamp(data),
    );
  }

  /// Parse OpenAI-style format: {"role": "user|assistant", "content": "..."}
  static app_models.ChatMessage _parseOpenAIFormat(Map<String, dynamic> parsed, int? index) {
    final String role = parsed['role'] ?? 'user';
    final String content = parsed['content'] ?? '';

    return app_models.ChatMessage(
      id: 'langchain_${index ?? DateTime.now().millisecondsSinceEpoch}',
      role: role,
      content: content,
      timestamp: _extractTimestamp(parsed),
    );
  }

  /// Parse simple content format: {"content": "..."}
  static app_models.ChatMessage _parseSimpleFormat(Map<String, dynamic> parsed, int? index) {
    final String content = parsed['content'] ?? '';
    
    // Alternate between user and assistant based on index
    final String role = (index != null && index % 2 == 0) ? 'user' : 'assistant';

    return app_models.ChatMessage(
      id: 'langchain_${index ?? DateTime.now().millisecondsSinceEpoch}',
      role: role,
      content: content,
      timestamp: _extractTimestamp(parsed),
    );
  }

  /// Parse unknown JSON format - try to extract any text content
  static app_models.ChatMessage _parseUnknownFormat(Map<String, dynamic> parsed, int? index) {
    // Look for common content fields
    String content = '';
    
    for (final key in ['content', 'message', 'text', 'data']) {
      if (parsed.containsKey(key)) {
        final value = parsed[key];
        if (value is String) {
          content = value;
          break;
        } else if (value is Map && value.containsKey('content')) {
          content = value['content']?.toString() ?? '';
          break;
        }
      }
    }

    // If no content found, convert entire JSON to string
    if (content.isEmpty) {
      content = parsed.toString();
    }

    return app_models.ChatMessage(
      id: 'langchain_${index ?? DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: content,
      timestamp: _extractTimestamp(parsed),
    );
  }

  /// Parse as plain text when JSON parsing fails
  static app_models.ChatMessage _parseAsPlainText(String text, int? index) {
    return app_models.ChatMessage(
      id: 'langchain_${index ?? DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
  }

  /// Extract timestamp from message data, with fallback to current time
  static DateTime _extractTimestamp(Map<String, dynamic> data) {
    // Look for common timestamp fields
    for (final key in ['timestamp', 'created_at', 'time', 'date']) {
      if (data.containsKey(key)) {
        final value = data[key];
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (e) {
            // Invalid date format, continue
          }
        } else if (value is int) {
          try {
            // Assume Unix timestamp
            return DateTime.fromMillisecondsSinceEpoch(value * 1000);
          } catch (e) {
            // Invalid timestamp, continue
          }
        }
      }
    }

    // No timestamp found, use current time
    return DateTime.now();
  }

  /// Parse a list of MessageResponse objects to ChatMessage objects
  static List<app_models.ChatMessage> parseMessageList(List<MessageResponse> messages) {
    final List<app_models.ChatMessage> chatMessages = [];
    
    for (int i = 0; i < messages.length; i++) {
      final messageResponse = messages[i];
      final parsed = parseMessage(messageResponse.message, index: i);
      if (parsed != null) {
        chatMessages.add(parsed);
      }
    }

    return chatMessages;
  }
} 