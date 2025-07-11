# Arcane Forge - Project Overview

## Project Vision and Purpose

**Arcane Forge** is an AI-powered Game Design Assistant desktop application built with Flutter. It serves as a comprehensive tool for game designers to create, iterate, and manage game design documents through conversational AI interactions, enhanced by project-specific knowledge bases.

### Core Mission
- **Democratize Game Design**: Make professional game design accessible to indie developers and small teams
- **AI-Enhanced Creativity**: Leverage AI to accelerate the creative process while maintaining human creative control
- **Knowledge-Driven Design**: Build contextual understanding through document-based knowledge bases
- **Collaborative Workflow**: Enable seamless iteration and refinement of game design concepts

## Current Architecture

### Frontend (Flutter Desktop)
- **Framework**: Flutter 3.5.3+ for cross-platform desktop (Windows, macOS, Linux)
- **State Management**: Provider pattern for reactive state management
- **UI Components**: Custom responsive design with Material Design 3 theming
- **Authentication**: Supabase Auth with custom UI components
- **AI Chat**: Flutter Gen AI Chat UI with streaming responses and markdown support

### Backend Integration
- **API Backend**: Python FastAPI with Azure OpenAI integration
- **AI Engine**: RAG (Retrieval-Augmented Generation) system using Qdrant vector database
- **Authentication**: JWT token-based authentication through Supabase
- **File Storage**: Project-based knowledge base with PDF, Markdown, and text file support

### Key Technologies
```yaml
# Core Dependencies
flutter: ^3.5.3
google_fonts: ^6.2.1
provider: ^6.1.2
supabase_flutter: ^2.3.4
flutter_gen_ai_chat_ui: ^2.3.0

# AI and Communication
web_socket_channel: ^3.0.3
dio: ^5.8.0+1
flutter_markdown: ^0.7.7+1

# File Management
file_picker: ^10.2.0
uuid: ^4.5.1
shared_preferences: ^2.5.3
```

## Application Structure

### Screen Architecture
The application follows a modular screen-based architecture with the following main areas:

#### 1. **Projects Management** (`ScreenType.projects`)
- **Purpose**: Central hub for managing game design projects
- **Features**: Create, edit, and organize multiple game projects
- **Screen**: `ProjectsScreen` with sidebar navigation

#### 2. **Game Design Assistant** (`ScreenType.gameDesignAssistant`)
- **Purpose**: AI-powered conversational interface for game design
- **Features**: 
  - Real-time streaming chat with AI
  - Project-aware conversations using knowledge bases
  - Automatic document detection and extraction
  - Markdown rendering for rich content
  - Chat history management with sidebar
- **Screen**: `GameDesignAssistantScreen` (fully implemented)

#### 3. **Knowledge Base** (`ScreenType.knowledgeBase`)
- **Purpose**: Manage project-specific documents and resources
- **Features**: Upload, organize, and manage design documents
- **Screen**: `KnowledgeBaseScreen`

#### 4. **Development Tools** (Future Screens)
- **Code Editor** (`ScreenType.codeEditor`)
- **Image Generator** (`ScreenType.imageGenerator`) 
- **Sound Generator** (`ScreenType.soundGenerator`)
- **Music Generator** (`ScreenType.musicGenerator`)
- **Web Server** (`ScreenType.webServer`)

#### 5. **System Management**
- **Dashboard** (`ScreenType.dashboard`)
- **Settings** (`ScreenType.settings`)
- **User Profile** (`ScreenType.user`)

### State Management Architecture

#### Providers
```dart
// Core Navigation
MenuAppController - Screen navigation and state
AuthProvider - Authentication state management
SettingsProvider - App settings and theming
ProjectProvider - Project-specific state management

// Specialized Providers
ChatApiService - AI chat communication
DocumentExtractor - Markdown document extraction
LangchainMessageParser - Message parsing and formatting
```

#### Services
```dart
// API Communication
ChatApiService - WebSocket and REST API for AI chat
ProjectsApiService - Project management API calls

// Document Processing
DocumentExtractor - Extract markdown from AI responses
LangchainMessageParser - Parse and format chat messages
```

## Current Implementation Status

### ✅ **Completed Features**

#### Authentication System
- Supabase integration with custom UI
- JWT token management
- Light/dark theme support
- Environment variable configuration

#### Chat Interface (Primary Feature)
- **Real-time AI Chat**: Full streaming response support via WebSocket
- **Project Context**: AI responses are aware of current project and knowledge base
- **Document Extraction**: Automatically detects and extracts markdown documents from AI responses
- **Knowledge Base Integration**: Upload and manage project-specific documents
- **Chat History**: Sidebar with conversation history and session management
- **Rich Formatting**: Full markdown support with syntax highlighting
- **Example Questions**: Predefined prompts for common game design scenarios

#### UI/UX Implementation
- **Responsive Design**: Adapts to different screen sizes
- **Material Design 3**: Modern, accessible design system
- **Custom Theming**: Light/dark modes with brand colors
- **Keyboard Shortcuts**: Efficient navigation and interaction
- **Error Handling**: Graceful error states and user feedback

### 🚧 **In Progress**

#### Project Management
- Basic project creation and selection
- Project-specific knowledge base management
- File upload and organization system

#### Backend Integration
- API service architecture established
- WebSocket communication for real-time chat
- Document processing pipeline

### 📋 **Planned Features**

#### Enhanced AI Capabilities
- **Multi-modal Input**: Image and file analysis
- **Specialized Agents**: Different AI personalities for different game genres
- **Template System**: Pre-built game design document templates
- **Version Control**: Track document changes and iterations

#### Development Tools Integration
- **Code Generation**: Generate game code from design documents
- **Asset Pipeline**: Integrate with image/sound generation tools
- **Export System**: Export to popular game engines (Unity, Unreal, Godot)

#### Collaboration Features
- **Team Sharing**: Share projects with team members
- **Comment System**: Annotate and discuss design documents
- **Review Workflows**: Structured design review processes

## Key Design Decisions

### 1. **Flutter Desktop Choice**
- **Rationale**: Cross-platform compatibility with native performance
- **Benefits**: Single codebase for Windows, macOS, and Linux
- **Trade-offs**: Larger binary size compared to web apps

### 2. **Provider State Management**
- **Rationale**: Simple, predictable state management suitable for desktop apps
- **Benefits**: Easy to understand and debug
- **Trade-offs**: Less suitable for complex state scenarios vs. Bloc/Riverpod

### 3. **Supabase Authentication**
- **Rationale**: Integrated auth solution with minimal backend complexity
- **Benefits**: Built-in user management, security, and scaling
- **Trade-offs**: Vendor lock-in and additional dependency

### 4. **WebSocket Chat Implementation**
- **Rationale**: Real-time streaming responses for better UX
- **Benefits**: Immediate feedback, typewriter effect, low latency
- **Trade-offs**: Connection management complexity

## Development Workflow

### Environment Setup
1. **Flutter SDK**: 3.5.3 or higher
2. **Environment Variables**: `.env` file with Supabase credentials
3. **Backend Services**: Python FastAPI server (optional for development)
4. **Platform Tools**: Platform-specific build tools for deployment

### Code Organization
```
lib/
├── constants.dart              # App-wide constants and colors
├── main.dart                   # App entry point and providers
├── responsive.dart             # Responsive design utilities
├── controllers/                # Navigation and app state
├── providers/                  # State management providers
├── screens/                    # Feature-based screen organization
│   ├── game_design_assistant/  # AI chat implementation
│   ├── projects/               # Project management
│   ├── settings/               # App configuration
│   └── shared/                 # Shared UI components
├── services/                   # API and external service integration
└── utils/                      # Utility functions and helpers
```

### Key Development Patterns
- **Feature-based Architecture**: Each major feature has its own folder
- **Provider Pattern**: Reactive state management with change notifications
- **Service Layer**: Abstracted API communication
- **Responsive Design**: Adaptive UI based on screen size
- **Error Boundaries**: Graceful error handling throughout the app

## Current Challenges and Considerations

### Technical Challenges
1. **WebSocket Connection Management**: Ensuring stable real-time connections
2. **Large Document Processing**: Efficient handling of large PDF files
3. **Cross-platform Compatibility**: Ensuring consistent experience across desktop platforms
4. **Memory Management**: Optimizing for long-running desktop application

### User Experience Challenges
1. **AI Response Quality**: Balancing creativity with accuracy
2. **Context Management**: Maintaining conversation context across sessions
3. **File Organization**: Intuitive knowledge base management
4. **Performance**: Smooth interactions even with large projects

### Future Scalability
1. **Multi-user Support**: Expanding beyond single-user desktop app
2. **Cloud Integration**: Syncing projects across devices
3. **Plugin System**: Allowing third-party integrations
4. **Enterprise Features**: Team management and collaboration tools

## Getting Started for New Developers

### Prerequisites
```bash
# Install Flutter SDK
flutter --version  # Should be 3.5.3+

# Verify platform support
flutter doctor

# Clone and setup
git clone <repository-url>
cd arcane_forge
flutter pub get
```

### Environment Configuration
```bash
# Create .env file
cp .env.example .env
# Edit with your Supabase credentials
```

### Running the Application
```bash
# Development mode
flutter run -d windows  # or macos/linux

# Debug mode with hot reload
flutter run --debug

# Release build
flutter build windows  # or macos/linux
```

### Key Files to Understand
1. **`lib/main.dart`** - App initialization and provider setup
2. **`lib/controllers/menu_app_controller.dart`** - Navigation logic
3. **`lib/screens/game_design_assistant/game_design_assistant_screen.dart`** - Core AI chat implementation
4. **`design_docs/FLUTTER_CHAT_DESIGN.md`** - Detailed chat feature specification

## Project Status Summary

**Arcane Forge** is currently in **active development** with a solid foundation established. The core AI chat functionality is implemented and working, with project management and knowledge base features in progress. The application demonstrates the potential for AI-enhanced game design tools and provides a strong foundation for expanding into a comprehensive game development assistant.

The project represents a modern approach to desktop application development, leveraging Flutter's capabilities for cross-platform consistency while integrating cutting-edge AI technologies to enhance the creative process. 