<!-- eef9b594-da3b-4fca-b2cd-aa6b487cabc9 76e1125f-f8c3-4cdd-ad22-03ecac7accc8 -->
# Remove ProjectProvider and Use Fresh API Data

## Overview

Remove `ProjectProvider` entirely and replace with:

- Direct API calls to fetch project info when needed
- Pass projectId/projectName as screen parameters
- Use MutationDesignService for mutation design data (already exists)
- Fetch knowledge base files from API (don't cache)

## Implementation Steps

### 1. Update GameDesignAssistantScreen to Accept Parameters

**File: `lib/screens/game_design_assistant/game_design_assistant_screen.dart`**

- Add required parameters to constructor:
  - `final String projectId`
  - `final String projectName`
- Remove `ProjectProvider` import
- Add state variable: `Project? _projectDetails`
- Add method `_fetchProjectDetails()` that calls `ProjectsApiService.getProjectById()`
- Call `_fetchProjectDetails()` in `initState()`
- In `_sendMessage()` and `_sendMessageWithTitle()`:
  - Use `int.parse(widget.projectId)` instead of `projectProvider.currentProject?.id`
  - Use `_projectDetails?.knowledgeBaseName` for knowledge base name
  - If `_projectDetails` is null, call `_fetchProjectDetails()` and wait
- In `_saveLastResponse()`:
  - Use `widget.projectId` directly
  - Remove `projectProvider.addExtractedDocument()` call (API handles this)
- In `_uploadFiles()`:
  - Use `widget.projectId` directly
  - Remove `projectProvider.addExtractedDocument()` call
- In `_showSessionInfo()`:
  - Use `widget.projectName` and `widget.projectId` directly
- In `_showKnowledgeBase()`:
  - Remove (or fetch files from API directly if needed)

### 2. Update KnowledgeBaseScreen to Accept Parameters

**File: `lib/screens/knowledge_base/knowledge_base_screen.dart`**

- Convert to StatefulWidget with parameters:
  - `final String projectId`
  - `final String projectName`
- Remove `ProjectProvider` import
- In all methods (`_loadFiles`, `_uploadFiles`, `_deleteFile`, `_downloadFile`):
  - Replace `projectProvider.currentProject?.id` with `widget.projectId`
  - Remove the null check and delay logic

### 3. Update ChatHistorySidebar Widget

**File: `lib/screens/game_design_assistant/widgets/chat_history_sidebar.dart`**

- Add required parameter: `final String projectId`
- Remove `ProjectProvider` import
- In `_loadChatSessions()`:
  - Replace `projectProvider.currentProject?.id` with `widget.projectId`

### 4. Update GameDesignResponseWidget

**File: `lib/screens/game_design_assistant/widgets/game_design_response_widget.dart`**

- Add required parameters:
  - `final String projectId`
  - `final String projectName`
- Remove `ProjectProvider` import
- In `_extractDocument()`:
  - Use `widget.projectId` and `widget.projectName` directly
  - Remove `projectProvider.addExtractedDocument()` call

### 5. Update ProjectDashboardScreen

**File: `lib/screens/project/project_dashboard_screen.dart`**

- Remove `ProjectProvider` import
- For `ScreenType.gameDesignAssistant`:
  - Replace `ChangeNotifierProvider` with direct widget:
  ```dart
  return GameDesignAssistantScreen(
    projectId: projectId,
    projectName: projectName,
  );
  ```

- For `ScreenType.knowledgeBase`:
  - Replace `ChangeNotifierProvider` with direct widget:
  ```dart
  return KnowledgeBaseScreen(
    projectId: projectId,
    projectName: projectName,
  );
  ```


### 6. Update Main.dart

**File: `lib/main.dart`**

- Remove `ProjectProvider` import
- Remove `ChangeNotifierProvider(create: (context) => ProjectProvider())` from the providers list

### 7. Delete ProjectProvider Files

**Files to delete:**

- `lib/screens/game_design_assistant/providers/project_provider.dart`
- `lib/screens/game_design_assistant/models/project_model.dart` (if only used by ProjectProvider)
  - Actually, keep this - it's used by ProjectsApiService

### 8. Verify MutationDesignService

**File: `lib/services/mutation_design_service.dart`**

- Confirm it already handles mutation design pending data (no changes needed)

## Files Changed

- `lib/screens/game_design_assistant/game_design_assistant_screen.dart`
- `lib/screens/knowledge_base/knowledge_base_screen.dart`
- `lib/screens/game_design_assistant/widgets/chat_history_sidebar.dart`
- `lib/screens/game_design_assistant/widgets/game_design_response_widget.dart`
- `lib/screens/project/project_dashboard_screen.dart`
- `lib/main.dart`

## Files Deleted

- `lib/screens/game_design_assistant/providers/project_provider.dart`