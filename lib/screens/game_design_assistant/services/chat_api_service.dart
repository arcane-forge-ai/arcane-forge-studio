import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/io.dart'; // Temporarily unused - for future WebSocket implementation
// import 'dart:convert'; // Temporarily unused - for future WebSocket implementation
import 'dart:async';
import '../models/api_models.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';

class ChatApiService {
  static const String _apiVersion = 'v1';
  static const bool _useStreamingByDefault = false; // MVP: Set to false for non-streaming
  
  // Note: WebSocket streaming is currently disabled because the backend
  // doesn't have WebSocket endpoints implemented. The OpenAPI spec only
  // shows HTTP REST endpoints. To enable streaming in the future:
  // 1. Backend needs to implement WebSocket at /ws/chat
  // 2. Or implement Server-Sent Events (SSE) for streaming
  // 3. Update streamChatResponse method to use real WebSocket connection
  
  final SettingsProvider? _settingsProvider;
  late final ApiClient _apiClient;
  WebSocketChannel? _wsChannel;

  ChatApiService({SettingsProvider? settingsProvider, AuthProvider? authProvider})
      : _settingsProvider = settingsProvider {
    _apiClient = ApiClient(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  /// Get current mock mode setting
  bool get _useMockMode => _settingsProvider?.useMockMode ?? false;
  
  /// Get API base URL from settings provider with fallback to default
  String get _baseUrl => _apiClient.baseUrl;
  
  /// Get full API URL with version
  String get _apiUrl => _apiClient.apiUrl;

  /// Send chat message via HTTP API (non-streaming)
  Future<ChatResponse> sendChatMessage(ChatRequest request) async {
    print('ChatApiService: Mock mode = $_useMockMode');
    if (_useMockMode) {
      print('ChatApiService: Using mock response');
      return _mockChatResponse(request);
    }

    final requestBody = request.toJson();
    print('ChatApiService: Making real API call to $_apiUrl/chat');

    try {
      final response = await _apiClient.post('/chat', data: requestBody);
      print('ChatApiService: API call successful, status: ${response.statusCode}');
      return ChatResponse.fromJson(response.data);
    } catch (e) {
      print('Chat API Error: $e');
      rethrow;
    }
  }

  /// Send chat message with configurable streaming/non-streaming
  Future<ChatResponse?> sendChatMessageWithMode({
    required ChatRequest request, 
    required bool useStreaming,
    Function(String)? onStreamChunk,
  }) async {
    if (useStreaming) {
      // Note: WebSocket streaming is currently not available in the backend
      // Using mock streaming for now
      if (onStreamChunk != null) {
        await for (final chunk in streamChatResponse(request)) {
          onStreamChunk(chunk);
        }
      }
      return null;
    } else {
      // For non-streaming, return the complete response
      return await sendChatMessage(request);
    }
  }

  /// Stream chat response via WebSocket
  Stream<String> streamChatResponse(ChatRequest request) async* {
    if (_useMockMode) {
      yield* _mockStreamResponse(request);
      return;
    }

    // WebSocket streaming not available in backend, fall back to mock streaming
    // TODO: Implement Server-Sent Events (SSE) or HTTP polling if backend supports it
    print('WebSocket streaming not available, using mock streaming');
    yield* _mockStreamResponse(request);
    
    /* Original WebSocket implementation - disabled due to 404 error
    try {
      _wsChannel = IOWebSocketChannel.connect('ws://localhost:8000/ws/chat');
      
      // Send request using the new ChatRequest format
      _wsChannel!.sink.add(jsonEncode(request.toJson()));

      await for (final message in _wsChannel!.stream) {
        final data = jsonDecode(message);
        if (data['type'] == 'message_chunk') {
          yield data['content'];
        } else if (data['type'] == 'message_complete') {
          break;
        }
      }
    } catch (e) {
      print('WebSocket Error: $e');
      // Fallback to mock streaming
      yield* _mockStreamResponse(request);
    } finally {
      _wsChannel?.sink.close();
      _wsChannel = null;
    }
    */
  }

  /// Get knowledge base files for a project
  Future<List<KnowledgeBaseFile>> getKnowledgeBaseFiles(
    String projectId, {
    String? passcode,
  }) async {
    if (_useMockMode) {
      return _mockKnowledgeBaseFiles();
    }

    try {
      // Use passcode authentication if provided (for unauthenticated access)
      if (passcode != null) {
        final response = await _apiClient.dio.get(
          '${_apiClient.apiUrl}/projects/$projectId/files',
          options: Options(
            headers: {
              'X-QA-Passcode': passcode,
              'Content-Type': 'application/json',
            },
          ),
        );
        final Map<String, dynamic> responseData = response.data;
        final List<dynamic> files = responseData['files'] ?? [];
        return files.map((item) => KnowledgeBaseFile.fromJson(item)).toList();
      } else {
        final response = await _apiClient.get('/projects/$projectId/files');
        final Map<String, dynamic> responseData = response.data;
        final List<dynamic> files = responseData['files'] ?? [];
        return files.map((item) => KnowledgeBaseFile.fromJson(item)).toList();
      }
    } catch (e) {
      print('Knowledge Base API Error: $e');
      rethrow;
    }
  }

  /// Upload file to knowledge base
  Future<bool> uploadFile(
    String projectId,
    String fileName, {
    String? filePath,
    Uint8List? bytes,
  }) async {
    if (_useMockMode) {
      await Future.delayed(const Duration(seconds: 2)); // Simulate upload
      return true;
    }

    try {
      Response response;
      
      if (bytes != null) {
        response = await _apiClient.uploadFileFromBytes(
          '/projects/$projectId/files',
          fileFieldName: 'file',
          bytes: bytes,
          fileName: fileName,
        );
      } else if (filePath != null) {
        response = await _apiClient.uploadFile(
          '/projects/$projectId/files',
          fileFieldName: 'file',
          filePath: filePath,
          fileName: fileName,
        );
      } else {
        throw ArgumentError('Either filePath or bytes must be provided.');
      }

      final responseData = response.data;
      return responseData['success'] == true || response.statusCode == 200;
    } catch (e) {
      print('File Upload Error: $e');
      rethrow;
    }
  }

  /// Delete file from knowledge base (works for both file and non-file entries)
  Future<bool> deleteFile(String projectId, int fileId) async {
    if (_useMockMode) {
      await Future.delayed(const Duration(seconds: 1)); // Simulate deletion
      return true;
    }

    try {
      // Try knowledge-base endpoint first (for non-file entries)
      final response = await _apiClient.delete('/projects/$projectId/knowledge-base/$fileId');
      return response.data['success'] == true;
    } catch (e) {
      // If that fails, try the files endpoint (for document entries)
      try {
        final response = await _apiClient.delete('/projects/$projectId/files/$fileId');
        return response.data['success'] == true;
      } catch (fallbackError) {
        print('File Delete Error: $fallbackError');
        rethrow;
      }
    }
  }

  /// Get download URL for a file
  Future<FileDownloadResponse?> getFileDownloadUrl(
    String projectId,
    int fileId, {
    String? passcode,
  }) async {
    if (_useMockMode) {
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      return FileDownloadResponse(
        downloadUrl: 'https://example.com/mock-download-url',
        fileName: 'mock_file.pdf',
        fileSize: 1024000,
        contentType: 'application/pdf',
        expiresIn: 3600,
      );
    }

    try {
      // Use passcode authentication if provided (for unauthenticated access)
      if (passcode != null) {
        final response = await _apiClient.dio.get(
          '${_apiClient.apiUrl}/projects/$projectId/files/$fileId/download',
          options: Options(
            headers: {
              'X-QA-Passcode': passcode,
              'Content-Type': 'application/json',
            },
          ),
        );
        return FileDownloadResponse.fromJson(response.data);
      } else {
        final response = await _apiClient.get('/projects/$projectId/files/$fileId/download');
        return FileDownloadResponse.fromJson(response.data);
      }
    } catch (e) {
      print('File Download URL Error: $e');
      rethrow;
    }
  }

  /// Add new knowledge base entry (non-file types: link, contact, folder, other)
  /// For document uploads, use uploadFile() instead
  Future<KnowledgeBaseFile> addKnowledgeBaseEntry(
    String projectId,
    KnowledgeBaseFile entry,
  ) async {
    if (_useMockMode) {
      return _mockAddKnowledgeBaseEntry(entry);
    }

    try {
      // Prepare request body according to API spec
      final requestBody = <String, dynamic>{
        'document_name': entry.documentName,
        'entry_type': entry.entryType,
        'visibility': entry.visibility,
        'authority_level': entry.authorityLevel,
        'tags': entry.tags,
      };

      // Add optional fields
      if (entry.description != null && entry.description!.isNotEmpty) {
        requestBody['description'] = entry.description;
      }
      
      if (entry.url != null && entry.url!.isNotEmpty) {
        requestBody['url'] = entry.url;
      }
      
      if (entry.contactInfo != null && entry.contactInfo!.isNotEmpty) {
        requestBody['contact_info'] = entry.contactInfo;
      }

      final response = await _apiClient.post(
        '/projects/$projectId/knowledge-base',
        data: requestBody,
      );
      return KnowledgeBaseFile.fromJson(response.data);
    } catch (e) {
      print('Add KB Entry Error: $e');
      rethrow;
    }
  }

  /// Update knowledge base entry metadata
  Future<KnowledgeBaseFile> updateKnowledgeBaseEntry(
    String projectId,
    int entryId,
    KnowledgeBaseFile entry,
  ) async {
    if (_useMockMode) {
      return _mockUpdateKnowledgeBaseEntry(entryId, entry);
    }

    try {
      // Prepare PATCH request body with only fields that should be updated
      final requestBody = <String, dynamic>{};
      
      // Add fields to update
      if (entry.documentName.isNotEmpty) {
        requestBody['document_name'] = entry.documentName;
      }
      if (entry.description != null) {
        requestBody['description'] = entry.description;
      }
      requestBody['tags'] = entry.tags;
      requestBody['visibility'] = entry.visibility;
      requestBody['authority_level'] = entry.authorityLevel;
      
      if (entry.url != null) {
        requestBody['url'] = entry.url;
      }
      if (entry.contactInfo != null) {
        requestBody['contact_info'] = entry.contactInfo;
      }

      final response = await _apiClient.patch(
        '/projects/$projectId/knowledge-base/$entryId',
        data: requestBody,
      );
      return KnowledgeBaseFile.fromJson(response.data);
    } catch (e) {
      print('Update KB Entry Error: $e');
      rethrow;
    }
  }

  /// Get knowledge base entries with optional filtering
  Future<List<KnowledgeBaseFile>> getKnowledgeBaseEntries(
    String projectId, {
    String? entryType,
    String? visibility,
    List<String>? tags,
    String? passcode,
  }) async {
    if (_useMockMode) {
      return _mockGetKnowledgeBaseEntries(
        entryType: entryType,
        visibility: visibility,
        tags: tags,
      );
    }

    try {
      final queryParams = <String, dynamic>{};
      if (entryType != null) queryParams['entry_type'] = entryType;
      if (visibility != null) queryParams['visibility'] = visibility;
      if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags.join(',');

      // Use passcode authentication if provided (for unauthenticated access)
      if (passcode != null) {
        final response = await _apiClient.dio.get(
          '${_apiClient.apiUrl}/projects/$projectId/knowledge-base',
          queryParameters: queryParams,
          options: Options(
            headers: {
              'X-QA-Passcode': passcode,
              'Content-Type': 'application/json',
            },
          ),
        );
        
        final List<dynamic> entries = response.data['entries'] ?? response.data;
        return entries.map((item) => KnowledgeBaseFile.fromJson(item)).toList();
      } else {
        final response = await _apiClient.get(
          '/projects/$projectId/knowledge-base',
          queryParameters: queryParams,
        );
        
        final List<dynamic> entries = response.data['entries'] ?? response.data;
        return entries.map((item) => KnowledgeBaseFile.fromJson(item)).toList();
      }
    } catch (e) {
      print('Get KB Entries Error: $e');
      rethrow;
    }
  }

  /// Get chat sessions for a project
  Future<List<ChatSession>> getChatSessions(int projectId) async {
    if (_useMockMode) {
      return _mockChatSessions(projectId);
    }

    try {
      final response = await _apiClient.get('/projects/$projectId/chat/sessions');
      final List<dynamic> sessions = response.data;
      return sessions.map((item) => ChatSession.fromJson(item)).toList();
    } catch (e) {
      print('Chat Sessions API Error: $e');
      rethrow;
    }
  }

  /// Create a new chat session for a project
  Future<ChatSessionCreateResponse?> createChatSession(int projectId, String userId, {String? sessionId}) async {
    if (_useMockMode) {
      return _mockCreateChatSession(projectId, userId, sessionId: sessionId);
    }

    final request = ChatSessionCreateRequest(userId: userId, sessionId: sessionId);
    final requestBody = request.toJson();

    try {
      final response = await _apiClient.post(
        '/projects/$projectId/chat/sessions',
        data: requestBody,
      );
      return ChatSessionCreateResponse.fromJson(response.data);
    } catch (e) {
      print('Create Chat Session API Error: $e');
      rethrow;
    }
  }

  /// Get chat history for a specific session
  Future<ChatHistoryResponse> getChatHistory(String sessionId) async {
    if (_useMockMode) {
      return _mockChatHistory(sessionId);
    }

    try {
      final response = await _apiClient.get('/chat/sessions/$sessionId/messages');
      return ChatHistoryResponse.fromJson(response.data);
    } catch (e) {
      print('Chat History API Error: $e');
      rethrow;
    }
  }

  /// Close WebSocket connection
  void dispose() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  // Mock responses for development - ALWAYS includes extractable markdown for testing
  ChatResponse _mockChatResponse(ChatRequest request) {
    final userMessage = request.message.toLowerCase();
    String response;

    if (userMessage.contains('character') || userMessage.contains('progression')) {
      response = '''I'll create a character progression system for your RPG. Here's a comprehensive design:

```markdown
# Character Progression System - RPG Game

## Core Mechanics

### Experience Points (XP)
- **Combat XP**: 10-50 XP per enemy defeated
- **Quest XP**: 100-500 XP per quest completed
- **Discovery XP**: 25 XP per new location found

### Level Progression
- **Level 1-10**: 1000 XP per level
- **Level 11-20**: 2000 XP per level  
- **Level 21-30**: 3000 XP per level

### Attribute System
Players distribute 5 attribute points per level among:
- **Strength**: Affects melee damage and carry capacity
- **Dexterity**: Affects accuracy and movement speed
- **Intelligence**: Affects magic damage and mana pool
- **Constitution**: Affects health and stamina

### Skill Trees
Three main branches:
1. **Combat**: Weapon mastery, defensive abilities
2. **Magic**: Elemental spells, magical knowledge  
3. **Utility**: Crafting, social skills, exploration

## Implementation Notes
- Consider soft caps for attributes to prevent over-specialization
- Implement skill synergies to encourage diverse builds
- Balance XP sources to maintain engagement across all play styles
```

This system provides balanced progression while allowing player choice in character development.''';
    } else if (userMessage.contains('story') || userMessage.contains('narrative')) {
      response = '''Let me help you create a compelling narrative structure:

```markdown
# Three-Act Story Structure for Games

## Act I: Setup (25% of game)
### Opening Hook
- Establish protagonist's normal world
- Introduce core conflict or threat
- Tutorial integration with story beats

### Inciting Incident
- Event that disrupts normal world
- Forces protagonist into action
- Sets main quest objective

## Act II: Confrontation (50% of game)
### Rising Action
- Series of escalating challenges
- Character development through trials
- Building relationships and alliances

### Midpoint Twist
- Major revelation or setback
- Stakes are raised significantly
- Player's understanding shifts

### Climax Build-up
- Final obstacles before resolution
- All character arcs converge
- Maximum tension point

## Act III: Resolution (25% of game)
### Climax
- Final confrontation or challenge
- Player uses all learned skills
- Emotional and mechanical payoff

### Resolution
- Consequences of player choices
- Character arc completions
- World state changes shown
```

This structure ensures proper pacing and emotional engagement throughout your game.''';
    } else if (userMessage.contains('mechanics') || userMessage.contains('system')) {
      response = '''Here's a comprehensive game mechanics document:

```markdown
# Core Game Mechanics Document

## Combat System
### Turn-Based Combat
- **Initiative**: Dexterity + 1d20 determines turn order
- **Action Points**: Each character gets 2 action points per turn
- **Attack Resolution**: Attack roll vs. Defense value
- **Damage**: Weapon damage + Strength modifier

### Status Effects
- **Poison**: -2 HP per turn for 3 turns
- **Stun**: Lose next turn
- **Buff/Debuff**: +/-2 to specific attributes

## Resource Management
### Health System
- **Hit Points**: Constitution × 10 + Level × 5
- **Healing**: Rest recovers 25% HP, potions vary
- **Death**: 0 HP = unconscious, -10 HP = death

### Magic System
- **Mana Points**: Intelligence × 5 + Level × 3
- **Spell Slots**: Limited high-level spells per day
- **Mana Recovery**: Meditation or rest

## Progression Mechanics
### Experience Gain
- Combat: Enemy level × 10 XP
- Quests: Varies by complexity (50-500 XP)
- Discovery: 25 XP per new area

### Leveling Benefits
- +5 HP per level
- +3 Mana per level
- 1 Attribute point per level
- New abilities every 3 levels
```

This framework provides clear, balanced mechanics for player progression and engagement.''';
    } else {
      response = '''I'd be happy to help with your game design! Here are some key areas I can assist with:

## 🎮 Game Design Areas
- **Core Mechanics**: Combat systems, player progression, resource management
- **Narrative Design**: Story structure, character development, dialogue systems  
- **Level Design**: Pacing, difficulty curves, player guidance
- **Balancing**: Mathematical models for fair and engaging gameplay

## 📋 Documentation I Can Create
```markdown
# Sample Game Design Document

## Game Overview
- Genre and target audience
- Core gameplay loop
- Key selling points

## Technical Specifications  
- Engine requirements
- Platform considerations
- Performance targets

## Implementation Roadmap
- Development phases
- Milestone planning
- Testing strategies
```

What specific aspect of game design would you like to explore? I can create detailed documentation for any system you'd like to develop!''';
    }

    return ChatResponse(
      output: response,
      input: request.message,
      sessionId: request.sessionId ?? 'mock_session_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
    );
  }

  // Mock streaming response that simulates real-time generation
  Stream<String> _mockStreamResponse(ChatRequest request) async* {
    final response = _mockChatResponse(request);
    final words = response.output.split(' ');
    
    String currentText = '';
    for (int i = 0; i < words.length; i++) {
      currentText += (i == 0 ? '' : ' ') + words[i];
      yield currentText;
      
      // Simulate typing delay - faster for words, slower for punctuation
      if (words[i].endsWith('.') || words[i].endsWith('!') || words[i].endsWith('?')) {
        await Future.delayed(const Duration(milliseconds: 200));
      } else {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  // Static storage for mock KB entries
  static final List<KnowledgeBaseFile> _mockKBEntries = [
    KnowledgeBaseFile(
      id: 1,
      documentName: 'Game Design Document.md',
      fileType: 'md',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      entryType: 'document',
      visibility: 'vendor_visible',
      authorityLevel: 'source_of_truth',
      tags: ['documentation', 'design', 'core'],
      description: 'Main game design document with core mechanics',
    ),
    KnowledgeBaseFile(
      id: 2,
      documentName: 'Character Progression System.md',
      fileType: 'md',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      entryType: 'document',
      visibility: 'vendor_visible',
      authorityLevel: 'source_of_truth',
      tags: ['progression', 'mechanics', 'balance'],
      description: 'Detailed character progression and leveling system',
    ),
    KnowledgeBaseFile(
      id: 3,
      documentName: 'Art Style Guide.pdf',
      fileType: 'pdf',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      entryType: 'document',
      visibility: 'internal_only',
      authorityLevel: 'reference',
      tags: ['art', 'style', 'guide'],
      description: 'Visual style guidelines for artists',
    ),
    KnowledgeBaseFile(
      id: 4,
      documentName: 'Unity Asset Store',
      fileType: 'link',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      entryType: 'link',
      visibility: 'vendor_visible',
      authorityLevel: 'reference',
      tags: ['resources', 'assets', 'unity'],
      description: 'Unity Asset Store for approved asset packages',
      url: 'https://assetstore.unity.com/',
    ),
    KnowledgeBaseFile(
      id: 5,
      documentName: 'Alice Chen - UI Lead',
      fileType: 'contact',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      entryType: 'contact',
      visibility: 'vendor_visible',
      authorityLevel: 'source_of_truth',
      tags: ['ui', 'contact', 'lead'],
      description: 'UI/UX Lead for design questions',
      contactInfo: {
        'email': 'alice@studio.com',
        'role': 'UI/UX Lead',
        'method': 'slack: #ui-questions',
      },
    ),
  ];

  List<KnowledgeBaseFile> _mockKnowledgeBaseFiles() {
    return List.from(_mockKBEntries);
  }

  KnowledgeBaseFile _mockAddKnowledgeBaseEntry(KnowledgeBaseFile entry) {
    final newId = _mockKBEntries.isEmpty 
        ? 1 
        : _mockKBEntries.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
    
    final newEntry = entry.copyWith(
      id: newId,
      createdAt: DateTime.now(),
    );
    
    _mockKBEntries.add(newEntry);
    return newEntry;
  }

  KnowledgeBaseFile _mockUpdateKnowledgeBaseEntry(int entryId, KnowledgeBaseFile entry) {
    final index = _mockKBEntries.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      throw Exception('Entry not found');
    }
    
    final updatedEntry = entry.copyWith(id: entryId);
    _mockKBEntries[index] = updatedEntry;
    return updatedEntry;
  }

  List<KnowledgeBaseFile> _mockGetKnowledgeBaseEntries({
    String? entryType,
    String? visibility,
    List<String>? tags,
  }) {
    var filtered = List<KnowledgeBaseFile>.from(_mockKBEntries);
    
    if (entryType != null) {
      filtered = filtered.where((e) => e.entryType == entryType).toList();
    }
    
    if (visibility != null) {
      filtered = filtered.where((e) => e.visibility == visibility).toList();
    }
    
    if (tags != null && tags.isNotEmpty) {
      filtered = filtered.where((e) {
        return tags.any((tag) => e.tags.contains(tag));
      }).toList();
    }
    
    return filtered;
  }

  List<ChatSession> _mockChatSessions(int projectId) {
    final now = DateTime.now();
    const mockUserId = '00000000-0000-0000-0000-000000000000'; // Use proper UUID format
    return [
      ChatSession(
        id: 1,
        sessionId: 'session_001',
        projectId: projectId,
        userId: mockUserId,
        title: 'RPG Character System Discussion',
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      ChatSession(
        id: 2,
        sessionId: 'session_002',
        projectId: projectId,
        userId: mockUserId,
        title: 'Combat Mechanics Design',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      ChatSession(
        id: 3,
        sessionId: 'session_003',
        projectId: projectId,
        userId: mockUserId,
        title: 'Level Design Principles',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      ChatSession(
        id: 4,
        sessionId: 'session_004',
        projectId: projectId,
        userId: mockUserId,
        title: 'Game Economy Balance',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      ChatSession(
        id: 5,
        sessionId: 'session_005',
        projectId: projectId,
        userId: mockUserId,
        title: 'Narrative Structure Planning',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      ChatSession(
        id: 6,
        sessionId: 'session_006',
        projectId: projectId,
        userId: mockUserId,
        title: null, // Untitled session
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
    ];
  }

  ChatHistoryResponse _mockChatHistory(String sessionId) {
    // Create mock messages in LangChain format based on session
    List<MessageResponse> messages = [];
    
    switch (sessionId) {
      case 'session_001': // RPG Character System Discussion
        messages = [
          MessageResponse(
            id: 1,
            sessionId: sessionId,
            message: '{"type": "human", "data": {"content": "I need help designing a character progression system for my RPG game. What are the key components I should consider?"}}',
          ),
          MessageResponse(
            id: 2,
            sessionId: sessionId,
            message: '{"type": "ai", "data": {"content": "Great question! For an RPG character progression system, you should consider these key components:\\n\\n## Core Mechanics\\n- **Experience Points (XP)**: How players earn progression currency\\n- **Leveling System**: Linear vs. milestone-based advancement\\n- **Attribute Distribution**: Strength, Dexterity, Intelligence, etc.\\n- **Skill Trees**: Branching paths for specialization\\n\\n## Balance Considerations\\n- **Progression Pacing**: Not too fast or slow\\n- **Player Choice**: Meaningful decisions at each level\\n- **End-game Viability**: Multiple viable builds\\n\\nWould you like me to elaborate on any of these areas?"}}',
          ),
          MessageResponse(
            id: 3,
            sessionId: sessionId,
            message: '{"type": "human", "data": {"content": "Yes, could you elaborate on skill trees? I want to create something that offers meaningful choices without overwhelming new players."}}',
          ),
          MessageResponse(
            id: 4,
            sessionId: sessionId,
            message: '{"type": "ai", "data": {"content": "Absolutely! Here\'s how to design player-friendly skill trees:\\n\\n## Tree Structure\\n- **3-4 Main Branches**: Combat, Magic, Utility\\n- **Clear Themes**: Each branch has distinct identity\\n- **Prerequisites**: Logical progression requirements\\n\\n## New Player Friendly Features\\n- **Visual Clarity**: Icons and clear descriptions\\n- **Recommended Builds**: Suggested paths for beginners\\n- **Respec Options**: Allow experimentation without penalty\\n- **Gradual Complexity**: Simple choices early, complex later\\n\\n## Example Structure\\n```\\nCombat Tree:\\n├── Weapon Mastery (Tier 1)\\n├── Critical Strikes (Tier 2)\\n└── Berserker Mode (Tier 3)\\n```\\n\\nThis gives depth while keeping initial choices simple."}}',
          ),
        ];
        break;
        
      case 'session_002': // Combat Mechanics Design
        messages = [
          MessageResponse(
            id: 5,
            sessionId: sessionId,
            message: '{"type": "human", "data": {"content": "I\'m working on turn-based combat mechanics. How do I make them feel engaging and strategic?"}}',
          ),
          MessageResponse(
            id: 6,
            sessionId: sessionId,
            message: '{"type": "ai", "data": {"content": "Turn-based combat can be incredibly engaging with the right design! Here are key strategies:\\n\\n## Action Economy\\n- **Action Points**: 2-3 points per turn for flexibility\\n- **Different Action Costs**: Move (1 AP), Attack (2 AP), Special (3 AP)\\n- **Bonus Actions**: Quick abilities that don\'t consume main actions\\n\\n## Strategic Depth\\n- **Positioning Matters**: Terrain advantages, flanking bonuses\\n- **Resource Management**: Mana, stamina, limited-use abilities\\n- **Status Effects**: Buffs, debuffs, DOT effects\\n- **Combo System**: Abilities that synergize\\n\\n## Pacing\\n- **Quick Animations**: Fast, impactful visual feedback\\n- **Auto-resolve Options**: For trivial encounters\\n- **Tension Building**: Escalating stakes within encounters\\n\\nWhat type of setting/theme are you working with?"}}',
          ),
        ];
        break;
        
      case 'session_003': // Level Design Principles
        messages = [
          MessageResponse(
            id: 7,
            sessionId: sessionId,
            message: '{"type": "human", "data": {"content": "What are the fundamental principles of good level design for action games?"}}',
          ),
          MessageResponse(
            id: 8,
            sessionId: sessionId,
            message: '{"type": "ai", "data": {"content": "Excellent question! Here are the core principles of effective level design:\\n\\n## Player Flow\\n- **Clear Objective**: Players always know where to go\\n- **Breadcrumbing**: Visual cues guide the path\\n- **Landmark Navigation**: Memorable reference points\\n\\n## Pacing & Rhythm\\n- **Tension Curves**: Alternate high and low intensity\\n- **Rest Areas**: Safe spaces to recover and plan\\n- **Escalation**: Gradually increasing challenges\\n\\n## Spatial Design\\n- **Rule of Thirds**: Important elements at intersection points\\n- **Sightlines**: Control what players can see when\\n- **Multiple Paths**: Options for different playstyles\\n\\n## Challenge Progression\\n- **Introduce**: New mechanic in safe environment\\n- **Develop**: Combine with known elements\\n- **Twist**: Subvert expectations\\n- **Conclude**: Final test of mastery\\n\\nWhich aspect would you like to explore further?"}}',
          ),
        ];
        break;
        
      default:
        // Generic conversation for other sessions
        messages = [
          MessageResponse(
            id: 100,
            sessionId: sessionId,
            message: '{"type": "human", "data": {"content": "Hello! I need help with game design."}}',
          ),
          MessageResponse(
            id: 101,
            sessionId: sessionId,
            message: '{"type": "ai", "data": {"content": "Hello! I\'d be happy to help you with game design. What specific area are you working on?"}}',
          ),
        ];
    }

    return ChatHistoryResponse(
      sessionId: sessionId,
      messages: messages,
    );
  }

  ChatSessionCreateResponse _mockCreateChatSession(int projectId, String userId, {String? sessionId}) {
    final now = DateTime.now();
    final finalSessionId = sessionId ?? 'session_${now.millisecondsSinceEpoch}';
    
    // Generate a title based on the session if one exists, otherwise leave untitled
    String? title;
    if (sessionId != null) {
      // When creating a session after a message, assign a meaningful title
      // In a real implementation, this would be generated by the AI based on the conversation content
      final titleOptions = [
        'Character System Design',
        'Combat Mechanics Discussion',
        'Level Design Planning',
        'Narrative Structure Chat',
        'Game Balancing Session',
        'Art Direction Meeting',
        'Technical Architecture Chat',
        'Player Experience Design',
        'Monetization Strategy',
        'UI/UX Design Session',
      ];
      title = titleOptions[DateTime.now().millisecond % titleOptions.length];
    }
    
    return ChatSessionCreateResponse(
      id: now.millisecondsSinceEpoch,
      sessionId: finalSessionId,
      projectId: projectId,
      userId: userId,
      title: title, // Assign title when session is created after conversation
      createdAt: now,
      updatedAt: now,
    );
  }
} 