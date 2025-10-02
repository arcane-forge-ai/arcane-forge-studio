# Arcane Forge - Code Map

**Purpose**: Quick reference guide to locate code and understand the codebase structure  
**Last Updated**: October 2, 2025  
**For**: Developers, AI Agents, and Contributors

---

## 🚀 Quick Start Navigation

### Entry Points
- **Main Entry**: `lib/main.dart` - App initialization, providers, and routing
- **Navigation Controller**: `lib/controllers/menu_app_controller.dart` - Screen navigation enum and logic
- **Constants**: `lib/constants.dart` - Theme colors and UI constants
- **API Config**: `lib/utils/app_constants.dart` - API endpoints and configuration

### Key Configuration Files
- **Dependencies**: `pubspec.yaml` - All package dependencies
- **Environment**: `.env` - Supabase credentials (create from ENVIRONMENT_SETUP.md)
- **Build Config**: Platform-specific configs in `windows/`, `macos/`, `linux/`

---

## 📁 Architecture Overview

```
lib/
├── main.dart                    # App entry + provider setup
├── constants.dart               # UI constants and colors
├── responsive.dart              # Responsive design utilities
│
├── controllers/                 # App-level state controllers
│   └── menu_app_controller.dart # Navigation state manager
│
├── providers/                   # Feature-specific state management
│   ├── auth_provider.dart
│   ├── settings_provider.dart
│   ├── image_generation_provider.dart
│   ├── music_generation_provider.dart
│   ├── sfx_generation_provider.dart
│   └── feedback_provider.dart
│
├── services/                    # Backend API integration
│   ├── projects_api_service.dart
│   ├── mutation_api_service.dart
│   ├── mutation_design_service.dart
│   ├── comfyui_service.dart
│   ├── comfyui_service_manager.dart
│   ├── image_generation_services.dart
│   ├── music_generation_services.dart
│   ├── sfx_generation_services.dart
│   ├── feedback_service.dart
│   ├── feedback_analysis_service.dart
│   └── feedback_discussion_service.dart
│
├── models/                      # Data structures
│   ├── image_generation_models.dart
│   ├── music_generation_models.dart
│   ├── sfx_generation_models.dart
│   ├── feedback_models.dart
│   ├── feedback_analysis_models.dart
│   └── extracted_asset_models.dart
│
├── screens/                     # UI screens (feature-based)
│   ├── [feature]/[feature]_screen.dart
│   ├── [feature]/widgets/       # Feature-specific widgets
│   └── shared/                  # Shared across features
│
├── widgets/                     # Global reusable widgets
│   └── [widget_name].dart
│
└── utils/                       # Utility functions
    └── app_constants.dart
```

---

## 🎯 Feature Location Map

### 🔐 Authentication
**Files**:
- Provider: `lib/providers/auth_provider.dart`
- Screen: `lib/screens/login/login_screen.dart`
- Integration: Supabase Auth (configured in `lib/main.dart:34-38`)

**Dependencies**: `supabase_flutter`, `supabase_auth_ui`

---

### 📊 Projects Management
**Files**:
- Main Screen: `lib/screens/projects/projects_dashboard_screen.dart`
- Projects List: `lib/screens/projects/projects_screen.dart`
- Side Menu: `lib/screens/projects/components/projects_side_menu.dart`
- Service: `lib/services/projects_api_service.dart`

**Navigation**: `ScreenType.projects` in `menu_app_controller.dart`

---

### 🏠 Project Dashboard (Individual Project)
**Files**:
- Main Screen: `lib/screens/project/project_dashboard_screen.dart`
- Home View: `lib/screens/project/components/project_home_screen.dart`
- Side Menu: `lib/screens/project/components/side_menu.dart`
- Release Info: `lib/screens/project/release_info_screen.dart`

**Navigation**: `ScreenType.projectHome`  
**Features**: Asset generation hub, navigation to all generation tools

---

### 🧠 Game Design Assistant (AI Chat)
**Files**:
- Main Screen: `lib/screens/game_design_assistant/game_design_assistant_screen.dart`
- Chat Service: `lib/screens/game_design_assistant/services/chat_api_service.dart`
- Message Parser: `lib/screens/game_design_assistant/services/langchain_message_parser.dart`
- Document Extractor: `lib/screens/game_design_assistant/services/document_extractor.dart`
- Project Provider: `lib/screens/game_design_assistant/providers/project_provider.dart`

**Widgets**:
- `widgets/chat_history_sidebar.dart` - Chat history UI
- `widgets/game_design_response_widget.dart` - AI response rendering

**Models**:
- `models/chat_message.dart` - Chat message structure
- `models/api_models.dart` - API request/response models
- `models/project_model.dart` - Project data structure

**Navigation**: `ScreenType.gameDesignAssistant`  
**Features**: Streaming chat, markdown rendering, document extraction, project context

---

### 🖼️ Image Generation
**Files**:
- Main Screen: `lib/screens/image_generation/image_generation_screen.dart`
- Overview: `lib/screens/image_generation/image_overview_screen.dart`
- Provider: `lib/providers/image_generation_provider.dart`
- Service: `lib/services/image_generation_services.dart`
- ComfyUI: `lib/services/comfyui_service.dart`, `lib/services/comfyui_service_manager.dart`
- Models: `lib/models/image_generation_models.dart`

**Widgets**:
- `widgets/asset_detail_screen.dart` - Asset details view
- `widgets/image_detail_dialog.dart` - Image detail dialog

**Navigation**: 
- `ScreenType.imageGenerator` - Generation screen
- `ScreenType.imageGenerationOverview` - Overview/gallery

**Integration**: ComfyUI API, A1111 API (see `a1111_reference/` for API examples)

---

### 🎵 Music Generation
**Files**:
- Main Screen: `lib/screens/music_generation/music_generation_screen.dart`
- Overview: `lib/screens/music_generation/music_overview_screen.dart`
- Provider: `lib/providers/music_generation_provider.dart`
- Service: `lib/services/music_generation_services.dart`
- Models: `lib/models/music_generation_models.dart`

**Widgets**:
- `widgets/music_asset_detail_screen.dart` - Music asset details
- `widgets/music_detail_dialog.dart` - Music detail dialog

**Navigation**: 
- `ScreenType.musicGenerator` - Generation screen
- `ScreenType.musicGenerationOverview` - Overview/library

**Audio Playback**: `audioplayers` package

---

### 🔊 SFX Generation
**Files**:
- Main Screen: `lib/screens/sfx_generation/sfx_generation_screen.dart`
- Overview: `lib/screens/sfx_generation/sfx_overview_screen.dart`
- Provider: `lib/providers/sfx_generation_provider.dart`
- Service: `lib/services/sfx_generation_services.dart`
- Models: `lib/models/sfx_generation_models.dart`

**Widgets**:
- `widgets/sfx_asset_detail_screen.dart` - SFX asset details
- `widgets/audio_detail_dialog.dart` - Audio detail dialog

**Navigation**: 
- `ScreenType.soundGenerator` - Generation screen
- `ScreenType.sfxGenerationOverview` - Overview/library

**Audio Playback**: `audioplayers` package

---

### 💬 Feedback System
**Files**:
- Main Screen: `lib/screens/feedback/feedback_screen.dart`
- Analysis: `lib/screens/feedback/feedback_analyze_screen.dart`
- Provider: `lib/providers/feedback_provider.dart`
- Services:
  - `lib/services/feedback_service.dart` - Basic feedback operations
  - `lib/services/feedback_analysis_service.dart` - AI analysis
  - `lib/services/feedback_discussion_service.dart` - Discussion features
- Models:
  - `lib/models/feedback_models.dart` - Feedback data structures
  - `lib/models/feedback_analysis_models.dart` - Analysis models

**Navigation**: `ScreenType.feedbacks`  
**Features**: User feedback collection, AI-powered analysis

---

### 📚 Knowledge Base
**Files**:
- Main Screen: `lib/screens/knowledge_base/knowledge_base_screen.dart`

**Navigation**: `ScreenType.knowledgeBase`  
**Features**: Document upload, management for project-specific context

---

### ⚙️ Settings
**Files**:
- Main Screen: `lib/screens/settings/settings_screen.dart`
- Provider: `lib/providers/settings_provider.dart`

**Navigation**: `ScreenType.settings`  
**Features**: Theme toggle, API configuration, user preferences

---

### 📈 Dashboard
**Files**:
- Main Screen: `lib/screens/dashboard/dashboard_screen.dart`
- Header: `lib/screens/dashboard/components/header.dart`

**Navigation**: `ScreenType.dashboard`

---

### 👤 User Profile
**Files**:
- Main Screen: `lib/screens/user/user_screen.dart`

**Navigation**: `ScreenType.user`

---

### 💻 Development Tools
**Files**:
- Command Line: `lib/screens/development/command_line_screen.dart`

**Navigation**: `ScreenType.codeEditor`, `ScreenType.webServer`  
**Status**: Planned/In Development

---

## 🔄 State Management Map

### Provider Pattern Architecture

All providers extend `ChangeNotifier` and are registered in `lib/main.dart:87-121`.

| Provider | Responsibility | Key Methods | Dependencies |
|----------|---------------|-------------|--------------|
| `MenuAppController` | Screen navigation | `changeScreen()` | None |
| `AuthProvider` | Authentication state | `signIn()`, `signOut()`, `isAuthenticated` | Supabase |
| `SettingsProvider` | App settings, theme | `toggleTheme()`, `isDarkMode` | SharedPreferences |
| `ProjectProvider` | Current project state | `setCurrentProject()`, `currentProject` | None |
| `ImageGenerationProvider` | Image generation state | `generateImage()`, `images` | `image_generation_services.dart` |
| `MusicGenerationProvider` | Music generation state | `generateMusic()`, `tracks` | `music_generation_services.dart` |
| `SfxGenerationProvider` | SFX generation state | `generateSfx()`, `sounds` | `sfx_generation_services.dart` |
| `FeedbackProvider` | Feedback management | `submitFeedback()`, `feedbacks` | `feedback_service.dart` |

### Accessing Providers in Widgets

```dart
// Read once (doesn't rebuild on change)
final provider = context.read<ProviderName>();

// Watch for changes (rebuilds on change)
final provider = context.watch<ProviderName>();

// Listen to specific properties
context.select<ProviderName, SpecificType>((p) => p.property);
```

---

## 🌐 Services Map

### API Services

| Service | Purpose | Base URL Config | Key Methods |
|---------|---------|-----------------|-------------|
| `projects_api_service.dart` | Project CRUD operations | `ApiConfig.baseUrl` | `createProject()`, `getProjects()`, `updateProject()` |
| `mutation_api_service.dart` | Mutation system API | `ApiConfig.baseUrl` | Game design mutations |
| `mutation_design_service.dart` | Design mutation logic | `ApiConfig.baseUrl` | Design transformations |
| `chat_api_service.dart` | AI chat communication | WebSocket + REST | `sendMessage()`, `streamChat()` |
| `image_generation_services.dart` | Image generation API | ComfyUI/A1111 | `generateImage()`, `getStatus()` |
| `music_generation_services.dart` | Music generation API | Backend API | `generateMusic()`, `getMusicTracks()` |
| `sfx_generation_services.dart` | SFX generation API | Backend API | `generateSfx()`, `getSfxLibrary()` |
| `feedback_service.dart` | Feedback CRUD | Backend API | `submitFeedback()`, `getFeedback()` |
| `feedback_analysis_service.dart` | AI feedback analysis | Backend API | `analyzeFeedback()` |
| `comfyui_service.dart` | ComfyUI integration | ComfyUI API | `submitWorkflow()`, `getImage()` |
| `comfyui_service_manager.dart` | ComfyUI lifecycle | N/A | Service management singleton |

### Service Factory Pattern

Many services use factory pattern for flexibility:
```dart
// Example from lib/main.dart
SfxAssetServiceFactory.create(
  apiBaseUrl: ApiConfig.baseUrl,
  useApiService: ApiConfig.enabled,
)
```

---

## 📦 Models Map

| Model File | Purpose | Key Classes |
|------------|---------|-------------|
| `image_generation_models.dart` | Image data structures | `ImageAsset`, `ImageGenerationRequest`, `ImageGenerationResponse` |
| `music_generation_models.dart` | Music data structures | `MusicAsset`, `MusicGenerationRequest`, `MusicTrack` |
| `sfx_generation_models.dart` | SFX data structures | `SfxAsset`, `SfxGenerationRequest`, `SoundEffect` |
| `feedback_models.dart` | Feedback structures | `Feedback`, `FeedbackItem`, `FeedbackSubmission` |
| `feedback_analysis_models.dart` | Analysis data | `FeedbackAnalysis`, `Sentiment`, `Insights` |
| `extracted_asset_models.dart` | Asset extraction | `ExtractedAsset`, `AssetMetadata` |
| `game_design_assistant/models/chat_message.dart` | Chat messages | `ChatMessage`, `MessageType` |
| `game_design_assistant/models/api_models.dart` | API data transfer | `ChatRequest`, `ChatResponse` |
| `game_design_assistant/models/project_model.dart` | Project structure | `Project`, `ProjectMetadata` |

---

## 🎨 UI Components Map

### Shared Components
- **Base Side Menu**: `lib/screens/shared/components/base_side_menu.dart`
  - Reusable side menu template
  - Used by: Projects, Project Dashboard
  
- **API Status Indicator**: `lib/screens/shared/components/api_status_indicator.dart`
  - Shows API connection status
  - Used across generation screens

### Feature-Specific Widgets
Located in `lib/screens/[feature]/widgets/`

**Image Generation**:
- `asset_detail_screen.dart` - Full asset details
- `image_detail_dialog.dart` - Quick view dialog

**Music Generation**:
- `music_asset_detail_screen.dart` - Music asset details
- `music_detail_dialog.dart` - Quick music preview

**SFX Generation**:
- `sfx_asset_detail_screen.dart` - SFX asset details
- `audio_detail_dialog.dart` - Audio preview dialog

**Game Design Assistant**:
- `chat_history_sidebar.dart` - Chat conversation history
- `game_design_response_widget.dart` - Formatted AI responses

### Global Widgets
Located in `lib/widgets/`
- Add globally reusable widgets here

---

## 📐 Responsive Design

**File**: `lib/responsive.dart`

```dart
Responsive.isDesktop(context)  // >= 1024px
Responsive.isTablet(context)   // >= 768px && < 1024px
Responsive.isMobile(context)   // < 768px
```

Use in layouts to adapt UI for different screen sizes.

---

## 🎨 Theming

### Theme Configuration
**File**: `lib/main.dart:126-261`

- Light theme: `ThemeData.light().copyWith(...)`
- Dark theme: `ThemeData.dark().copyWith(...)`
- Toggle: `SettingsProvider.toggleTheme()`

### Color Constants
**File**: `lib/constants.dart`

```dart
primaryColor      // Main brand color
secondaryColor    // Secondary UI color
bgColor          // Background color
```

Use these constants for consistent theming throughout the app.

---

## 🔌 External Integrations

### Supabase (Authentication & Database)
- **Config**: `.env` file
- **Required Vars**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- **Docs**: `ENVIRONMENT_SETUP.md`
- **Provider**: `lib/providers/auth_provider.dart`

### ComfyUI (Image Generation)
- **Service**: `lib/services/comfyui_service.dart`
- **Manager**: `lib/services/comfyui_service_manager.dart`
- **Models**: `lib/models/image_generation_models.dart`

### A1111 API (Alternative Image Generation)
- **Reference**: `a1111_reference/request.json`
- **Docs**: `design_docs/A1111_integration.md`

### Backend API (Python FastAPI)
- **Base URL**: Configured in `lib/utils/app_constants.dart`
- **Toggle**: `ApiConfig.enabled` (true = use backend, false = mock/local)

---

## 🛠️ Common Development Tasks

### Adding a New Screen

1. **Create screen file**: `lib/screens/[feature]/[feature]_screen.dart`
2. **Add to navigation enum**: `lib/controllers/menu_app_controller.dart`
   ```dart
   enum ScreenType {
     ...
     yourNewScreen,
   }
   ```
3. **Add navigation logic**: Where you need to navigate
   ```dart
   context.read<MenuAppController>().changeScreen(ScreenType.yourNewScreen);
   ```
4. **Route in main dashboard**: Update the screen router to handle new screen type

### Adding a New Provider

1. **Create provider**: `lib/providers/[feature]_provider.dart`
   ```dart
   class YourProvider extends ChangeNotifier {
     // State variables
     // Methods that call notifyListeners()
   }
   ```
2. **Register in main.dart**: Add to `MultiProvider` in `lib/main.dart:87-121`
   ```dart
   ChangeNotifierProvider(create: (context) => YourProvider()),
   ```
3. **Use in widgets**:
   ```dart
   final provider = context.watch<YourProvider>();
   ```

### Adding a New Service

1. **Create service**: `lib/services/[feature]_service.dart`
   ```dart
   class YourService {
     final String baseUrl;
     YourService(this.baseUrl);
     
     Future<Response> yourApiCall() async {
       // Implementation
     }
   }
   ```
2. **Inject into provider**: Pass service to provider constructor
3. **Configure**: Add any API endpoints to `lib/utils/app_constants.dart`

### Adding a New Model

1. **Create model file**: `lib/models/[feature]_models.dart`
2. **Define data classes**:
   ```dart
   class YourModel {
     final String id;
     final String name;
     
     YourModel({required this.id, required this.name});
     
     // JSON serialization
     factory YourModel.fromJson(Map<String, dynamic> json) => YourModel(
       id: json['id'],
       name: json['name'],
     );
     
     Map<String, dynamic> toJson() => {
       'id': id,
       'name': name,
     };
   }
   ```
3. **Use in provider and service**: Import and use the model

### Adding Assets

1. **Add files**: Place in appropriate `assets/` subdirectory
   - Icons: `assets/icons/`
   - Images: `assets/images/`
   - Other: `assets/[type]/`
2. **Register in pubspec.yaml**: Add to `flutter.assets` section
   ```yaml
   flutter:
     assets:
       - assets/your_folder/
   ```
3. **Use in code**:
   ```dart
   Image.asset('assets/images/your_image.png')
   SvgPicture.asset('assets/icons/your_icon.svg')
   ```

---

## 📝 Design Documentation

Located in `design_docs/`:

| Document | Purpose |
|----------|---------|
| `PROJECT_OVERVIEW.md` | Complete project architecture and vision |
| `FLUTTER_CHAT_DESIGN.md` | AI chat system design and implementation |
| `IMAGE_GENERATION_DESIGN.md` | Image generation feature specs |
| `IMAGE_GENERATION_DESIGN_updated.md` | Updated image generation specs |
| `A1111_integration.md` | Automatic1111 API integration guide |
| `A1111_switch_model.md` | Model switching implementation |
| `mutation_game_design.md` | Game design mutation system |
| `feedback_integration.md` | Feedback system design |
| `auto_image_assets_creation.md` | Auto asset generation design |
| `openapi.json` | API specification |
| `sample-feedback.json` | Feedback data examples |

Also see:
- `IMPLEMENTATION_SUMMARY.md` - Implementation progress tracker
- `ENVIRONMENT_SETUP.md` - Environment configuration guide
- `requirements_asset_backend_api.md` - Backend API requirements

---

## 🔍 Finding Specific Code

### By Feature
Use this guide's [Feature Location Map](#-feature-location-map) section

### By Screen Name
Look in `lib/screens/[feature]/[feature]_screen.dart`

### By Provider/State
Check `lib/providers/[feature]_provider.dart`

### By API Integration
See `lib/services/[feature]_service.dart`

### By Data Structure
Look in `lib/models/[feature]_models.dart`

### By Screen Type
Search for `ScreenType.yourScreen` in:
1. `lib/controllers/menu_app_controller.dart` - Definition
2. Navigation code where `changeScreen()` is called

---

## 🧪 Testing

Located in `test/`:
- `widget_test.dart` - Widget tests
- `unit_test.dart` - Unit tests
- `login_screen_test.dart` - Login screen tests

**Run tests**:
```bash
flutter test
```

---

## 🏗️ Build & Run

### Development
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### Release Build
```bash
flutter build windows  # or macos/linux
```

### Hot Reload
Press `r` in terminal during `flutter run`

### Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📚 Dependencies Quick Reference

### Core Flutter
- `flutter` - Framework
- `provider` - State management
- `google_fonts` - Typography

### UI Components
- `flutter_svg` - SVG support
- `flutter_markdown` - Markdown rendering
- `flutter_gen_ai_chat_ui` - Chat UI components

### Networking
- `dio` - HTTP client
- `web_socket_channel` - WebSocket support

### Authentication
- `supabase_flutter` - Supabase client
- `supabase_auth_ui` - Auth UI components
- `flutter_dotenv` - Environment variables

### Utilities
- `file_picker` - File selection
- `uuid` - Unique ID generation
- `shared_preferences` - Local storage
- `intl` - Internationalization
- `url_launcher` - URL opening
- `audioplayers` - Audio playback

---

## 🎯 Navigation Flow

```
LoginScreen (if not authenticated)
    ↓
ProjectsDashboardScreen (ScreenType.projects)
    ↓
    ├── Select Project → ProjectDashboardScreen (ScreenType.projectHome)
    │                        ↓
    │                        ├── Game Design Assistant (ScreenType.gameDesignAssistant)
    │                        ├── Image Generation (ScreenType.imageGenerator)
    │                        ├── Music Generation (ScreenType.musicGenerator)
    │                        ├── SFX Generation (ScreenType.soundGenerator)
    │                        ├── Knowledge Base (ScreenType.knowledgeBase)
    │                        └── Settings (ScreenType.settings)
    │
    ├── Dashboard (ScreenType.dashboard)
    ├── Settings (ScreenType.settings)
    └── User Profile (ScreenType.user)
```

---

## 🎨 Asset Generation Workflow

```
User → Generation Screen (Image/Music/SFX)
    ↓
Provider → Service → Backend API
    ↓
Response → Update Provider State
    ↓
UI Updates → Show Generated Asset
    ↓
Overview Screen → View All Assets
    ↓
Detail Dialog/Screen → View/Edit/Download
```

---

## 🤖 AI Agent Tips

When working with this codebase:

1. **Start with the feature**: Check the [Feature Location Map](#-feature-location-map)
2. **Check the provider**: Understand state management for that feature
3. **Review the service**: See how it communicates with backend
4. **Check the models**: Understand data structures
5. **Find the screen**: Locate UI implementation
6. **Read design docs**: Check `design_docs/` for detailed specs

**For navigation**: Always use `MenuAppController.changeScreen(ScreenType.x)`

**For state changes**: Always call `notifyListeners()` after state updates in providers

**For API calls**: Use the appropriate service class, don't make direct HTTP calls in providers

**For new features**: Follow the [Common Development Tasks](#-common-development-tasks) section

---

## 📊 Project Statistics

- **Total Screens**: 15+ unique screens
- **Providers**: 7 state management providers
- **Services**: 11 backend integration services
- **Models**: 9 data model files
- **Main Features**: Image/Music/SFX Generation, AI Chat, Project Management, Feedback System

---

## 🔗 Related Documentation

- **Setup**: `ENVIRONMENT_SETUP.md`
- **Overview**: `design_docs/PROJECT_OVERVIEW.md`
- **Implementation**: `IMPLEMENTATION_SUMMARY.md`
- **Chat Design**: `design_docs/FLUTTER_CHAT_DESIGN.md`

---

## 💡 Pro Tips

1. **Use Cmd/Ctrl+P** in VS Code to quickly open files by name
2. **Use grep/search** to find where a class or method is used
3. **Check git history** (`git log [file]`) to understand why code changed
4. **Read provider code first** when understanding a feature - it's the "brain"
5. **Check main.dart provider setup** to understand dependency injection
6. **Use Flutter DevTools** for debugging state and performance
7. **Reference design docs** before making significant changes

---

**Questions?** Check the `design_docs/` folder or reach out to the development team.

