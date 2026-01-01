# Image Generation Feature Design Document

## Overview

This document outlines the development plan for implementing image generation functionality in the Arcane Forge Flutter application. The feature will provide a UI similar to StabilityMatrix's generation screen, with ComfyUI integration for backend processing.

## Core Requirements

~~- **Side Menu Integration**: Add image generation as an expansion tile with "Overview" and "Generation" children~~
- **Overview Screen**: Display all generated image assets for the current project, grouped by original generation request
~~- **Generation Screen**: Provide a comprehensive UI for image generation with model selection, parameters, and preview~~
- **Asset Grouping**: Multiple generations from the same prompt should be grouped as one asset in the overview
~~- **ComfyUI Integration**: Automated ComfyUI startup, prompt submission, and result subscription~~ (We are doing A1111 now)
~~- **Status Monitoring**: ComfyUI status display and log viewing functionality~~

## UI Structure & Navigation

### Screen Structure

```dart
// New screens to implement
class ImageOverviewScreen extends StatefulWidget {
  // Grid view of grouped image assets
  // Search and filter functionality
  // Asset management (delete, rename, etc.)
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
class ImageAssetDetailScreen extends StatefulWidget {
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

### UI Development Guidelines

**Asset Creation Flow:**
- User creates asset with: **Name** + **Description** (e.g., "Main character portrait")
- Then generates with: **Positive Prompt** + **Negative Prompt** + **Parameters**

**Favorite System:**
- Each asset has multiple generations
- User can mark ONE generation as "favorite" per asset
- Asset thumbnail shows favorite generation (or first if none marked)

## Key Design Decisions to Discuss

1. **Project Integration**: How should image assets relate to your existing project structure?
// BG: Each project may have some image assets that need to be generated. When a game design is completed, in game design doc, it should have covered art assets need to be generated. In MVP, we just have user manually create these assets by hand. However, in future, we want this process to be automated: once the GDD is decided, when user switch to image generation, the software should read the gdd and create empty art assets. And user would click on one art asset, and start working on one (by choosing models, prompts, etc.). We would also want user to be able to pick the one they like the best and download it for future usage.

1. **Model Management**: Do you want to implement model downloading like StabilityMatrix, or assume users manage models separately?
// BG: yes, but this would be our next task

1. **Platform Considerations**: Different approach for desktop vs mobile?
// BG: No we only stay with desktop now. 

1. **User Flow**: Should users create an "asset" first before generating, or should assets be created automatically from the first generation?
// BG: great question! I think users should create an asset before generating. But I'm not sure if having an additional screen of creating asset is a good idea since it adds one extra "hop". Maybe we could have a dropdown with text input? where user could either select an existing asset name or put a new name in it. A generation must attach to an asset

## Implementation Decisions (Based on Feedback)

### ✅ **Resolved Design Decisions**

1. **Asset Creation Flow**: 
   - Assets must be created before generation
   - Use dropdown with text input (select existing or create new)
   - Avoid extra screen navigation

2. **Multi-Project Support**: 
   - Image assets isolated per project
   - Project-specific storage folders
   - No cross-project asset sharing

3. **Platform Support**: 
   - Desktop-only implementation
   - Windows-first approach
   - Mobile support not required

4. **Storage Strategy**: 
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