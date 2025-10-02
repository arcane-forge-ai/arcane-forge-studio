# Image Generation Feature Design Document

## Overview

This document outlines the development plan for implementing image generation functionality in the Arcane Forge Flutter application. The feature will provide a UI similar to StabilityMatrix's generation screen, with ComfyUI integration for backend processing.

## Core Requirements

- **Side Menu Integration**: Add image generation as an expansion tile with "Overview" and "Generation" children
- **Overview Screen**: Display all generated image assets for the current project, grouped by original generation request
- **Generation Screen**: Provide a comprehensive UI for image generation with model selection, parameters, and preview
- **Asset Grouping**: Multiple generations from the same prompt should be grouped as one asset in the overview
- **ComfyUI Integration**: Automated ComfyUI startup, prompt submission, and result subscription
- **Status Monitoring**: ComfyUI status display and log viewing functionality

## Architecture Overview

### Data Models

```dart
// Core data models for image generation
class ImageAsset {
  final String id;
  final String projectId;
  final String name;
  final String description; // What this asset represents (e.g., "Main character portrait", "Castle background")
  final DateTime createdAt;
  final List<ImageGeneration> generations;
  final String? thumbnail; // Path to best/first generation
  final String? favoriteGenerationId; // ID of the user's preferred generation for this asset
}

class ImageGeneration {
  final String id;
  final String assetId;
  final String imagePath;
  final Map<String, dynamic> parameters; // JSON storage for extensibility with Postgres
  final DateTime createdAt;
  final GenerationStatus status;
  final bool isFavorite; // User can mark this specific generation as their favorite for the asset
}

// Helper class for type-safe parameter access
class GenerationParameters {
  final Map<String, dynamic> _params;
  
  GenerationParameters(this._params);
  
  // Core parameters with getters
  String get model => _params['model'] ?? '';
  String get positivePrompt => _params['positive_prompt'] ?? '';
  String get negativePrompt => _params['negative_prompt'] ?? '';
  int get width => _params['width'] ?? 512;
  int get height => _params['height'] ?? 512;
  int get steps => _params['steps'] ?? 20;
  double get cfgScale => _params['cfg_scale'] ?? 7.0;
  String get sampler => _params['sampler'] ?? 'euler';
  int get seed => _params['seed'] ?? -1;
  
  // LoRA parameters
  List<Map<String, dynamic>> get loras => List<Map<String, dynamic>>.from(_params['loras'] ?? []);
  
  // Extensible: any other parameters
  dynamic operator [](String key) => _params[key];
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_params);
}

class ComfyUIStatus {
  final bool isRunning;
  final bool isConnected;
  final String? error;
  final String host; // For remote connections (default: 127.0.0.1)
  final int? port;
  final List<String> logs;
}
```

### Service Architecture

```dart
// Services structure
abstract class ComfyUIService {
  Stream<ComfyUIStatus> get statusStream;
  Future<bool> startComfyUI();
  Future<void> stopComfyUI();
  Future<void> sendPrompt(GenerationRequest request);
  Future<List<String>> getLogs();
}

abstract class ImageGenerationService {
  Future<ImageAsset> createAsset(String projectId, String name, String prompt);
  Future<ImageGeneration> generateImage(ImageAsset asset, GenerationParameters params);
  Stream<GenerationProgress> subscribeToGeneration(String generationId);
}

abstract class ImageAssetService {
  Future<List<ImageAsset>> getProjectAssets(String projectId);
  Future<ImageAsset> getAsset(String assetId);
  Future<void> deleteAsset(String assetId);
  Future<void> deleteGeneration(String generationId);
}
```

## UI Structure & Navigation

### Side Menu Integration

```dart
// Update existing side menu to include image generation
class ProjectSideMenu extends StatefulWidget {
  // Add expansion tile for Image Generation
  ExpansionTile(
    title: Text('Image Generation'),
    children: [
      ListTile(
        title: Text('Overview'),
        onTap: () => context.go('/project/${projectId}/images/overview'),
      ),
      ListTile(
        title: Text('Generation'),
        onTap: () => context.go('/project/${projectId}/images/generation'),
      ),
    ],
  )
}
```

### Screen Structure

```dart
// New screens to implement
class ImageOverviewScreen extends StatefulWidget {
  // Grid view of grouped image assets
  // Search and filter functionality
  // Asset management (delete, rename, etc.)
}

class ImageGenerationScreen extends StatefulWidget {
  // Generation UI similar to StabilityMatrix
  // Model selection, parameters, preview
  // Generation progress and results
}

class ComfyUIStatusWidget extends StatefulWidget {
  // Shows ComfyUI status with indicator
  // Button to open logs popup
  // Start/stop functionality
}
```

## ComfyUI Integration

### Process Management

```dart
class ComfyUIProcessManager {
  Process? _comfyProcess;
  final StreamController<String> _logController = StreamController.broadcast();
  
  Future<bool> startComfyUI({
    String? modelPath,
    int port = 8188,
    Map<String, String>? extraArgs,
  });
  
  Future<void> stopComfyUI();
  bool get isRunning => _comfyProcess != null;
  Stream<String> get logStream => _logController.stream;
}
```

### API Integration

```dart
class ComfyUIApiClient {
  final Dio _dio;
  
  Future<ComfyPromptResponse> postPrompt(ComfyPromptRequest request);
  Future<void> interrupt();
  Future<ComfyHistoryResponse> getHistory(String promptId);
  Future<Uint8List> getImage(String filename, String subfolder);
  Stream<ComfyWebSocketEvent> subscribeToEvents();
}
```

## Generation UI Implementation

### Generation Screen Layout

```dart
class GenerationScreen extends StatefulWidget {
  // 3-Column Layout:
  
  // Left panel: Parameters & Models
  // - Asset selection dropdown (with create new option)
  // - Model selection (checkpoints, LoRAs)
  // - Generation parameters (size, steps, cfg, etc.)
  // - Generate button
  
  // Middle panel: Prompts (Dedicated)
  // - Positive prompt text area (large)
  // - Negative prompt text area
  // - Prompt suggestions/templates
  // - Prompt strength/emphasis controls
  
  // Right panel: Preview & Results
  // - Current asset info
  // - Generation progress
  // - Generated images grid
  // - Image actions (save, delete, regenerate, favorite)
}
```

### Key UI Components

```dart
class AssetSelectionWidget extends StatefulWidget {
  // Dropdown with existing assets + "Create New" option
  // Text input for new asset name
  // Asset info display
}

class ModelSelectionWidget extends StatefulWidget {
  // Checkpoint model dropdown
  // LoRA selection with strength controls
  // Model info display
  // Refresh models button (scans ComfyUI model directory)
}

class PromptInputWidget extends StatefulWidget {
  // Large positive prompt text area
  // Negative prompt text area
  // Prompt suggestions/templates
  // Prompt strength/emphasis controls
}

class GenerationParametersWidget extends StatefulWidget {
  // Size presets and custom input
  // Steps, CFG scale sliders
  // Sampler selection
  // Seed input with random button
}

class GenerationProgressWidget extends StatefulWidget {
  // Simple loading indicator (no detailed progress)
  // Cancel generation button
  // Status text
}
```

## Asset Management

### Overview Screen Implementation

```dart
class ImageOverviewScreen extends StatefulWidget {
  // Grid layout with asset cards
  // Each card shows:
  // - Thumbnail (best/first generation)
  // - Asset name
  // - Generation count
  // - Creation date
  // - Actions (view, delete, rename)
}

class ImageAssetCard extends StatefulWidget {
  // Clickable card that opens asset detail view
  // Shows grouped generations
  // Quick actions menu
}
```

### Asset Detail View

```dart
class AssetDetailScreen extends StatefulWidget {
  // Shows all generations for an asset
  // Grid of generated images
  // Generation parameters for each
  // Actions: regenerate, delete, export
}
```

## State Management & Integration

### State Management Structure

```dart
// Using Provider or Riverpod
class ImageGenerationState extends ChangeNotifier {
  List<ImageAsset> _assets = [];
  ComfyUIStatus _comfyStatus = ComfyUIStatus.stopped();
  GenerationProgress? _currentGeneration;
  
  // Getters and methods
  List<ImageAsset> get assets => _assets;
  ComfyUIStatus get comfyStatus => _comfyStatus;
  GenerationProgress? get currentGeneration => _currentGeneration;
}

// Providers
final imageGenerationProvider = ChangeNotifierProvider<ImageGenerationState>((ref) {
  return ImageGenerationState();
});

final comfyUIServiceProvider = Provider<ComfyUIService>((ref) {
  return ComfyUIServiceImpl();
});
```

### Integration Points

```dart
// Integration with existing project system
class ProjectProvider extends ChangeNotifier {
  // Add image generation methods
  Future<void> loadProjectAssets(String projectId);
  Future<void> createImageAsset(String name, String prompt);
}
```

## ComfyUI Monitoring & Logs

### Status Monitoring

```dart
class ComfyUIStatusIndicator extends StatefulWidget {
  // Traffic light style indicator (green/yellow/red)
  // Shows current status text
  // Click to open detailed status
}

class ComfyUILogViewer extends StatefulWidget {
  // Popup dialog with scrollable log view
  // Auto-scroll to bottom
  // Copy logs button
  // Clear logs button
}
```

## UI-First Development Approach

**Strategy**: Build and perfect the UI/UX flows first with mock data and services, then integrate with real backend systems.

### Mock Services Required
- **MockImageAssetService**: Returns sample assets with fake generations
- **MockComfyUIService**: Simulates ComfyUI startup, generation process, and logs
- **MockModelService**: Returns list of fake models (checkpoints, LoRAs)
- **MockStorageService**: Simulates image storage and retrieval

### Benefits
- Rapid UI iteration without backend complexity
- Perfect user flows before integration
- Easier testing and debugging
- Clear separation of concerns

### UI Development Guidelines

**Asset Creation Flow:**
- User creates asset with: **Name** + **Description** (e.g., "Main character portrait")
- Then generates with: **Positive Prompt** + **Negative Prompt** + **Parameters**

**Favorite System:**
- Each asset has multiple generations
- User can mark ONE generation as "favorite" per asset
- Asset thumbnail shows favorite generation (or first if none marked)

**Mock Images:**
- Use placeholder images: colored boxes with "Generated Image" text
- No need to find sample images online
- Keep it simple with text labels

**Technical Standards:**
- Follow existing Flutter project patterns (providers, routing, etc.)
- Use the same styling/theming as current app
- File organization: Place logic/screens based on existing app structure

## Refined Implementation Plan

Based on feedback, here's the updated implementation approach:

### Phase 1: UI Foundation & Mock Services (Week 1-2)
- [ ] Implement data models (in-memory for now)
- [ ] Create mock service interfaces
- [ ] Set up mock data (sample assets, generations, models)
- [ ] Update side menu with image generation expansion tile
- [ ] Create basic navigation structure

### Phase 2: Overview Screen (Week 3-4)
- [ ] Build overview screen with asset grid
- [ ] Implement asset cards with thumbnails
- [ ] Add search and filter functionality
- [ ] Create asset detail view
- [ ] Add asset management actions (delete, rename)

### Phase 3: Generation Screen Layout (Week 5-6)
- [ ] Build 3-column generation screen layout
- [ ] Implement asset selection dropdown with create-new
- [ ] Create model selection UI (checkpoints + LoRAs)
- [ ] Build dedicated prompt panel
- [ ] Add generation parameters controls

### Phase 4: Generation Flow & Interactions (Week 7-8)
- [ ] Implement mock generation flow
- [ ] Add ComfyUI status indicator
- [ ] Create generation progress UI
- [ ] Add generation history display
- [ ] Implement favorite generation marking

### Phase 5: Advanced UI Features (Week 9-10)
- [ ] Add ComfyUI log viewer popup
- [ ] Implement image export functionality
- [ ] Add generation parameter presets
- [ ] Create batch generation UI
- [ ] Polish responsive design

### Phase 6: Backend Integration (Week 11-12)
- [ ] Replace mock services with real implementations
- [ ] Set up PostgreSQL database
- [ ] Implement ComfyUI process management
- [ ] Add real model discovery
- [ ] Implement local + Supabase storage

### Phase 7: Testing & Polish (Week 13-14)
- [ ] End-to-end testing
- [ ] Error handling and edge cases
- [ ] Performance optimization
- [ ] UI/UX improvements and bug fixes

## Key Design Decisions to Discuss

1. **Project Integration**: How should image assets relate to your existing project structure?
// BG: Each project may have some image assets that need to be generated. When a game design is completed, in game design doc, it should have covered art assets need to be generated. In MVP, we just have user manually create these assets by hand. However, in future, we want this process to be automated: once the GDD is decided, when user switch to image generation, the software should read the gdd and create empty art assets. And user would click on one art asset, and start working on one (by choosing models, prompts, etc.). We would also want user to be able to pick the one they like the best and download it for future usage.

2. **ComfyUI Distribution**: Should we bundle ComfyUI with the app or require separate installation?
// BG: refer to what Stabiliy matrix is doing now: it uses a package management system to download and start comfyUI. We should do similar things but maybe in the future. For now, let's just assume comfyui is installed somewhere. For example, we have ComfyUI here: `H:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable` and usually we start with the `H:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\run_nvidia_gpu_fast_fp16_accumulation.bat` script.

3. **Model Management**: Do you want to implement model downloading like StabilityMatrix, or assume users manage models separately?
// BG: yes, but this would be our next task

4. **Platform Considerations**: Different approach for desktop vs mobile?
// BG: No we only stay with desktop now. 

5. **Asset Storage**: Where should generated images be stored? Project-specific folders?
// BG: you should decide that. We eventually would want to upload it to both Supabase and local. 

6. **Real-time Updates**: How important is real-time generation progress vs simple completion notifications?
// BG: It's actually not that important. We can have user wait during generation with no preview or progress report. Nice to have

7. **User Flow**: Should users create an "asset" first before generating, or should assets be created automatically from the first generation?
// BG: great question! I think users should create an asset before generating. But I'm not sure if having an additional screen of creating asset is a good idea since it adds one extra "hop". Maybe we could have a dropdown with text input? where user could either select an existing asset name or put a new name in it. A generation must attach to an asset

8. **Model Organization**: How should we handle different model types (checkpoints, LoRAs, embeddings, etc.)?
// BG: Yes. Checkpoints and loras are the 2 very minimum we need.

## Technical Specifications

### ComfyUI Integration
- **Installation Path**: `H:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable`
- **Startup Script**: `H:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\run_nvidia_gpu_fast_fp16_accumulation.bat`
- **Model Discovery**: Scan `H:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\ComfyUI\models` directory
- **API Endpoint**: `http://127.0.0.1:8188` (default)

### Database Schema (PostgreSQL)
```sql
-- Image assets table
CREATE TABLE image_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL,
  name VARCHAR(255) NOT NULL,
  original_prompt TEXT,
  is_favorite BOOLEAN DEFAULT false,
  thumbnail_path VARCHAR(500),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Image generations table
CREATE TABLE image_generations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES image_assets(id) ON DELETE CASCADE,
  image_path VARCHAR(500) NOT NULL,
  parameters JSONB NOT NULL, -- Extensible parameters
  status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (asset_id) REFERENCES image_assets(id)
);
```

### Storage Strategy
- **Local Storage**: Project-specific folders under `project_data/{project_id}/images/`
- **Supabase Storage**: Backup and cloud sync (future implementation)
- **Thumbnails**: Generated automatically from first/best generation

### Flutter Packages Required
- `dio` - HTTP client for API calls
- `web_socket_channel` - WebSocket communication with ComfyUI
- `process` - Process management for ComfyUI
- `path_provider` - File system access
- `postgres` - PostgreSQL database connection
- `provider` or `riverpod` - State management
- `cached_network_image` - Image caching and display
- `file_picker` - File selection for model management

### External Dependencies
- ComfyUI installation at specified path
- Python environment for ComfyUI
- Required AI models (checkpoints, LoRAs) in ComfyUI models directory

## Implementation Decisions (Based on Feedback)

### ✅ **Resolved Design Decisions**

1. **Asset Creation Flow**: 
   - Assets must be created before generation
   - Use dropdown with text input (select existing or create new)
   - Avoid extra screen navigation

2. **ComfyUI Management**: 
   - Assume pre-installed at: `H:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable`
   - Parse batch file contents to understand startup parameters, then execute directly
   - Alternative: Direct Python execution with parsed arguments
   - Future: Package management like StabilityMatrix

3. **Model Discovery**: 
   - Scan ComfyUI model directory structure
   - Support checkpoints and LoRAs (minimum viable)
   - Future: Model registry and downloading

4. **Progress Tracking**: 
   - Simple loading indicator (no detailed progress)
   - User waits during generation
   - Future: Real-time progress as nice-to-have

5. **Error Handling**: 
   - Notify user of ComfyUI crashes
   - Allow restart/retry generation
   - Keep error handling simple initially
   - Provide "Show ComfyUI Logs" button for debugging
   - Log viewer popup with scrollable output

6. **Multi-Project Support**: 
   - Image assets isolated per project
   - Project-specific storage folders
   - No cross-project asset sharing

7. **Platform Support**: 
   - Desktop-only implementation
   - Windows-first approach
   - Mobile support not required

8. **Storage Strategy**: 
   - Local storage in project folders
   - Future: Supabase sync and backup
   - User can favorite and download best generations

### 🔄 **Future Enhancements**
- Auto-generate assets from Game Design Document
- Model downloading and package management
- Real-time generation progress
- Mobile platform support
- Advanced prompt templates and suggestions

---

*Design document updated based on user feedback - ready for implementation.* 