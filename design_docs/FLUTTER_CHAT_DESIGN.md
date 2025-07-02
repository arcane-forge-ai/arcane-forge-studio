# Game Design Assistant - Chat Module Feature Specification

## Project Context

### What is the Game Design Assistant?
The Game Design Assistant is an AI-powered tool that helps game designers create, iterate, and manage game design documents. It combines conversational AI with knowledge base management to provide contextual assistance for game development projects.

### Current Architecture
- **Backend**: Python FastAPI with Azure OpenAI integration
- **AI Engine**: RAG (Retrieval-Augmented Generation) system using Qdrant vector database
- **Current Frontend**: Streamlit (web-based, being replaced)
- **Target Frontend**: Flutter desktop application (Windows/Mac)

### Core Workflow
1. Users create **Projects** (e.g., "RPG Game", "Puzzle Platformer")
2. Users upload **Documents** (PDFs, markdown files) to project **Knowledge Bases**
3. Users **Chat** with AI assistant that has access to project-specific knowledge
4. AI generates **Game Design Documents** which can be saved back to knowledge base
5. Knowledge base grows over time, making AI responses more contextual and relevant

## Feature Requirements

### Primary Objective
Develop a chat module for an existing Flutter desktop application that replicates all functionality currently available in a Streamlit-based interface, while providing superior user experience through native Flutter UI components and Flutter AI Toolkit integration.

### Core Features to Implement

#### 1. **Real-time Chat Interface**
- **Requirement**: Conversational interface supporting user and AI assistant messages
- **Behavior**: Messages appear in chronological order with clear role differentiation
- **Technology**: Flutter AI Toolkit ChatView component
- **Performance**: Smooth scrolling, 60fps animations, responsive input

#### 2. **Project-Aware Conversations**
- **Requirement**: Chat is contextually aware of the currently selected project
- **Display**: Project name and description prominently shown in chat interface
- **Knowledge Base Integration**: When project has knowledge base, AI responses include relevant document excerpts
- **Visual Indicator**: Clear indication when knowledge base is active for current project

#### 3. **Streaming AI Responses**
- **Requirement**: Real-time streaming of AI responses as they're generated
- **Technology**: WebSocket connection to FastAPI backend
- **User Experience**: Typewriter effect showing response as it's generated
- **Fallback**: Graceful degradation to polling if WebSocket fails

#### 4. **Automatic Document Detection & Extraction**
- **Requirement**: Automatically detect when AI generates game design documents
- **Detection Logic**: Scan AI responses for markdown code blocks containing substantial content
- **Content Validation**: Verify extracted content appears to be game design related
- **User Notification**: Prominent banner/notification when document detected

#### 5. **One-Click Document Saving**
- **Requirement**: Save extracted documents to project knowledge base with single click
- **User Flow**: Document detected → Save banner appears → User clicks save → Document added to KB
- **File Handling**: Create temporary markdown file, upload via API, clean up temp file
- **Feedback**: Clear success/error messaging to user

#### 6. **Knowledge Base File Management**
- **Requirement**: View and manage files in project knowledge base
- **Interface**: Modal dialog with file list and upload capabilities
- **Features**: File upload (drag & drop + file picker), file deletion, file type icons
- **Supported Formats**: PDF, Markdown (.md), Text (.txt)

#### 7. **Error Handling & Recovery**
- **Network Errors**: Graceful handling of connection failures with retry mechanisms
- **File Upload Errors**: Clear error messages, progress indicators for large files
- **API Errors**: User-friendly error messages, no data loss during failures
- **Offline Capability**: Cache recent conversations for offline viewing

## Technical Specifications

### Backend API Integration

#### Base Configuration
- **API Base URL**: Configurable (typically `http://localhost:8000` for development)
- **Authentication**: JWT token-based (existing system)
- **Content Type**: JSON for requests, WebSocket for streaming

#### Required API Endpoints

##### Chat Endpoints
- **POST** `/api/v1/chat/stateless`
  - **Purpose**: Send message with full conversation history
  - **Request**: `{ messages: ChatMessage[], knowledgeBaseName?: string }`
  - **Response**: `{ content: string, role: "assistant", timestamp: datetime }`

- **WebSocket** `/ws/chat/stateless`
  - **Purpose**: Real-time streaming chat responses
  - **Message Format**: `{ type: "stateless_chat", current_message: string, message_history: ChatMessage[], knowledge_base_name?: string }`
  - **Response Stream**: `{ type: "message_chunk", content: string }` followed by `{ type: "message_complete" }`

##### Knowledge Base Endpoints
- **GET** `/api/v1/projects/{projectId}/files`
  - **Purpose**: List files in project knowledge base
  - **Response**: `{ data: KnowledgeBaseFile[] }`

- **POST** `/api/v1/projects/{projectId}/files`
  - **Purpose**: Upload file to knowledge base
  - **Request**: Multipart form data with file and metadata
  - **Response**: `{ success: boolean, data: KnowledgeBaseFile }`

- **DELETE** `/api/v1/projects/{projectId}/files/{fileId}`
  - **Purpose**: Remove file from knowledge base
  - **Response**: `{ success: boolean }`

#### Data Models

##### ChatMessage
```
{
  role: "user" | "assistant",
  content: string,
  timestamp: datetime (ISO 8601)
}
```

##### KnowledgeBaseFile
```
{
  id: number,
  documentName: string,
  fileType: "pdf" | "md" | "txt",
  createdAt: datetime (ISO 8601),
  metadata?: object
}
```

##### Project (from existing system)
```
{
  id: number,
  name: string,
  description: string,
  hasKnowledgeBase: boolean
}
```

### Flutter Implementation Requirements

#### Dependencies to Add
Use `flutter pub add` to get latest versions:
```bash
flutter pub add flutter_ai_toolkit
flutter pub add web_socket_channel
flutter pub add dio
flutter pub add flutter_markdown
flutter pub add file_picker
flutter pub add uuid
flutter pub add shared_preferences
```

#### Module Structure (Adjusted for Existing Project)
```
lib/screens/game_design_assistant/
├── game_design_assistant_screen.dart (existing - will be replaced)
├── models/
│   ├── chat_message.dart
│   ├── project_model.dart
│   └── api_models.dart
├── services/
│   ├── chat_api_service.dart
│   ├── websocket_service.dart (optional, could be part of chat_api_service)
│   └── document_extractor.dart
├── providers/
│   ├── chat_provider.dart
│   └── game_design_llm_provider.dart
└── widgets/
    ├── chat_interface.dart
    ├── document_save_banner.dart
    ├── project_context_banner.dart
    └── knowledge_base_dialog.dart
```

#### Integration Strategy
- **Complete Screen Replacement**: The entire `GameDesignAssistantScreen` becomes the chat interface
- **Navigation Integration**: Already wired into existing sidebar navigation via `ScreenType.gameDesignAssistant`
- **State Management**: Integrate with existing `MenuAppController` pattern while adding chat-specific providers
- **Development Mode**: Include mock service capability for testing without backend running

#### Key Components Design

##### GameDesignAssistantScreen (Complete Replacement)
- **Layout**: AppBar + Project Banner + Document Save Banner + Chat Interface
- **Full Screen Chat**: Entire screen dedicated to chat experience
- **Project Context**: Show current project selection and allow switching
- **Document Save Banner**: Appears when document detected, dismissible
- **Chat Interface**: Flutter AI Toolkit ChatView with custom provider

##### Integration with Existing Navigation
- Replace current placeholder `GameDesignAssistantScreen` entirely
- Maintain existing navigation flow from sidebar
- Use existing app theming and styling patterns
- Follow existing screen layout patterns (SafeArea, padding, etc.)

##### Development/Mock Mode
- **Purpose**: Allow UI testing without backend dependency
- **Toggle**: Environment variable or debug flag to switch between mock and real API
- **Mock Responses**: Realistic game design responses for testing
- **Gradual Migration**: Easy to switch from mock to real API as backend becomes available

#### State Management

##### ChatProvider
- **Purpose**: Manage chat state and document extraction
- **State Variables**:
  - `List<ChatMessage> messages` - Conversation history
  - `bool isLoading` - Loading state for new messages
  - `String? extractedDocument` - Currently detected document
  - `bool showSaveButton` - Whether to show save banner
- **Methods**:
  - `sendMessage(String content)` - Send user message and get AI response
  - `saveExtractedDocument()` - Save detected document to knowledge base
  - `dismissSaveButton()` - Hide document save banner

##### GameDesignLlmProvider (Flutter AI Toolkit Integration)
- **Purpose**: Custom LLM provider that connects to FastAPI backend
- **Responsibilities**:
  - Convert Flutter AI Toolkit messages to API format
  - Stream responses from WebSocket
  - Trigger document extraction on complete responses
  - Handle errors and connection issues

#### Document Extraction Logic

##### DocumentExtractor Utility
- **Purpose**: Detect and extract game design documents from AI responses
- **Key Method**: `extractMarkdownBlock(String content) -> String?`
- **Logic**:
  1. Search for markdown code blocks (``` ... ```)
  2. Extract content between code blocks
  3. Remove language identifiers (e.g., "markdown")
  4. Validate content length (minimum 100 characters)
  5. Return extracted content or null if not found

##### Validation Criteria
- Content must be within markdown code blocks
- Minimum length of 100 characters
- Should contain game design keywords (optional enhancement)

## User Experience Specifications

### Chat Flow
1. **Entry**: User navigates to chat screen from main app
2. **Context Loading**: Project information displayed at top
3. **Welcome Message**: AI assistant greeting appears
4. **Conversation**: User types message, AI responds with streaming
5. **Document Detection**: When AI generates document, save banner appears
6. **Document Saving**: User clicks save, document added to knowledge base
7. **Continuation**: Chat continues with updated knowledge base context

### Visual Design Requirements

#### Theme Integration
- **Colors**: Use existing app color scheme
- **Typography**: Follow existing app text styles
- **Icons**: Consistent with existing app iconography
- **Spacing**: Match existing app layout patterns

#### Responsive Design
- **Desktop First**: Optimized for desktop usage (Windows/Mac)
- **Window Sizing**: Adaptable to different window sizes
- **Keyboard Navigation**: Full keyboard accessibility
- **Mouse Interactions**: Hover states, right-click context menus

#### Animation Requirements
- **Message Appearance**: Smooth slide-in animation for new messages
- **Typing Indicator**: Animated indicator while AI is responding
- **Banner Transitions**: Smooth show/hide for document save banner
- **Loading States**: Skeleton loading for file lists

### Error Handling UX

#### Network Errors
- **Connection Lost**: "Connection lost, trying to reconnect..." banner
- **Retry Mechanism**: Automatic retry with exponential backoff
- **Offline Mode**: "You're offline. Recent messages are cached."

#### File Upload Errors
- **Large Files**: Progress bar with cancel option
- **Invalid Formats**: "Unsupported file type. Please use PDF, MD, or TXT files."
- **Upload Failures**: "Upload failed. Please try again." with retry button

#### API Errors
- **Server Errors**: "Service temporarily unavailable. Please try again."
- **Authentication**: "Session expired. Please log in again."
- **Rate Limiting**: "Too many requests. Please wait a moment."

## Performance Requirements

### Response Times
- **Chat Interface Load**: < 2 seconds
- **Message Send**: < 500ms to show in UI
- **AI Response Start**: < 2 seconds for first chunk
- **File Upload**: Progress indicator for files > 10MB

### Memory Management
- **Message History**: Limit to 50 messages in memory
- **File Cleanup**: Automatic cleanup of temporary files
- **Image Caching**: Efficient caching of file type icons

### Network Optimization
- **WebSocket Reconnection**: Automatic reconnection with exponential backoff
- **Request Batching**: Batch file operations where possible
- **Compression**: Enable gzip compression for API requests

## Testing Requirements

### Unit Tests (Required)
- **DocumentExtractor**: Test markdown block detection and extraction
- **ChatProvider**: Test state management and message handling
- **API Service**: Test request/response handling and error cases

### Integration Tests (Required)
- **End-to-End Chat**: Complete conversation flow with document saving
- **File Upload**: Upload various file types and handle errors
- **WebSocket Connection**: Test streaming, reconnection, and fallback

### Widget Tests (Required)
- **Chat Bubbles**: Test message rendering and markdown support
- **Dialogs**: Test knowledge base dialog interactions
- **Error States**: Test error message display and recovery

## Deliverables

### Code Deliverables
1. **Complete Chat Module** - All files in specified module structure
2. **Integration Guide** - Documentation for integrating with existing project
3. **API Documentation** - Details of FastAPI endpoints and data models
4. **Test Suite** - Unit, integration, and widget tests
5. **Example Usage** - Sample integration showing how to use the module

### Documentation Deliverables
1. **Setup Instructions** - How to add dependencies and configure module
2. **Configuration Guide** - API endpoints, authentication setup
3. **Troubleshooting Guide** - Common issues and solutions
4. **Performance Guidelines** - Optimization recommendations

### Quality Assurance
1. **Code Review Ready** - Clean, well-documented, production-ready code
2. **Cross-Platform Testing** - Verified on Windows and macOS
3. **Error Handling** - Comprehensive error handling and user feedback
4. **Performance Optimization** - Efficient memory usage and network handling

## Success Criteria

### Functional Requirements
- ✅ All Streamlit features replicated in Flutter
- ✅ Document extraction accuracy > 95%
- ✅ File upload success rate > 99%
- ✅ WebSocket streaming with < 100ms latency
- ✅ Graceful error handling and recovery

### User Experience Requirements
- ✅ Intuitive chat interface matching modern chat applications
- ✅ Smooth animations and responsive interactions
- ✅ Clear visual feedback for all user actions
- ✅ Accessible design following Flutter accessibility guidelines

### Technical Requirements
- ✅ Clean, maintainable code following Flutter best practices
- ✅ Comprehensive test coverage (>80%)
- ✅ Efficient memory usage and performance
- ✅ Easy integration with existing Flutter projects

This specification provides a complete blueprint for implementing a sophisticated chat module that enhances the game design workflow through intelligent document management and conversational AI assistance. 