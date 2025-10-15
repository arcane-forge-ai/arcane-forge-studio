<!-- f11a5982-7237-49f9-8105-f776c0a61310 cb1ebd80-167b-4a92-97af-16c1f1e21992 -->
# Add "Discuss with AI" Feature to Image Generation Screen

## Implementation Steps

### 1. Add Chat Dependencies and State Management

Add to `lib/screens/image_generation/image_generation_screen.dart`:

- Import required packages from game_design_assistant_screen.dart:
- `flutter_gen_ai_chat_ui` components
- `ChatApiService`, `ChatMessage` models, `ChatUser`, etc.
- Add state variables:
- `_showChatPanel` (bool) - controls bottom panel visibility
- `_chatController` (ChatMessagesController) - manages chat messages
- `_chatApiService` (ChatApiService) - API service instance
- `_currentChatSessionId` (String?) - tracks active chat session
- `_isChatGenerating` (bool) - loading state for AI responses
- `_currentUser` and `_aiUser` (ChatUser) - chat participants
- `_chatScrollController` (ScrollController) - for chat scrolling

### 2. Initialize Chat Components

In `initState()`:

- Initialize `_chatApiService` with SettingsProvider (similar to game_design_assistant_screen.dart:80-81)
- Initialize `_chatController` and `_chatScrollController`
- Define `_currentUser` and `_aiUser` with appropriate IDs and avatars

In `dispose()`:

- Dispose of `_chatController` and `_chatScrollController`
- Dispose of `_chatApiService`

### 3. Add "Discuss with AI" Button

In `_buildPromptsPanel()` method, after the "Generate Button" section (around line 1216):

- Add a SizedBox(height: 16)
- Add a new button with icon `Icons.chat` and text "Discuss with AI"
- Style it similar to the generate button but with a different color (e.g., purple/indigo)
- OnPressed: call `_openChatPanel()` method

### 4. Create Persistent Bottom Panel

Create `_openChatPanel()` method:

- Check if existing session exists (has messages)
- If no existing session, call `_startNewChatSession()` to create one
- Set `_showChatPanel = true` to show the panel
- Panel persists even when clicking outside (unlike modal)

Create `_startNewChatSession()` method:

- Create new session ID with format: `${_selectedAsset?.name ?? 'image-gen'}-yyyy-mm-dd-hh-mm-ss`
- Set `_currentChatSessionId` to the new session ID
- Clear `_chatController` messages
- Add initial AI greeting message asking "What are you looking for?" or "Any comments on existing generations and setup?"

Create `_buildChatPanel()` widget method:

- Fixed height container (400px) spanning full width below all 3 columns
- Header with "AI Chat Assistant" title, asset name subtitle, "New Discussion" button, and close button
- Use `AiChatWidget` from flutter_gen_ai_chat_ui
- Configure message options, loading config, input options with smaller font sizes
- Set `onSendMessage` to `_sendChatMessage` method

### 4.5 Add AI Model Recommendation Button

In `_buildModelSelection()` after LoRA selection:

- Add full-width button below LoRA section
- Button text: "Ask AI for Model & LoRA Recommendations"
- Icon: `Icons.psychology` (brain icon)
- OnPressed: call `_askAIForModelRecommendation()` method

Create `_askAIForModelRecommendation()` method:

- Check if asset is selected (show warning if not)
- Open chat panel if not already open
- Auto-generate and send message with:
  - Asset details (name, description)
  - Current setup (model, dimensions, prompts)
  - Request for model/LoRA recommendations and prompt suggestions

### 5. Implement Chat Message Sending

Create `_sendChatMessage(ChatMessage message)` method:

- Add user message to `_chatController`
- Gather all current generation parameters into a context string:
- Asset info (name, description)
- Model selection
- Dimensions (width, height)
- Quality settings (sampler, scheduler, steps, CFG scale)
- Seed info
- Batch count
- Positive and negative prompts
- Format as structured text (e.g., JSON or markdown)
- Create ChatRequest with:
- `message`: user's message + "\n\nCurrent Setup:\n" + context
- `projectId` and `userId` from providers
- `sessionId`: `_currentChatSessionId`
- `title`: session name format `${_selectedAsset?.name ?? 'image-gen'}-${timestamp}`
- `agentType`: null (default chat agent)
- Call `_chatApiService.sendChatMessage(request)`
- Update AI message in chat controller with response
- Handle errors with error messages in chat

### 6. Session Management

- First click on "Discuss with AI" creates a new session
- Subsequent clicks reopen the same session (session persistence)
- "New Discussion" button in chat panel header creates fresh session
- Session naming: `${asset_name}-yyyy-mm-dd-hh-mm-ss`
- Sessions are automatically saved by the backend via ChatApiService
- Chat panel can be closed and reopened without losing conversation

### 7. Make Columns Scrollable

Update layout to prevent overflow:

- Wrap `_buildParametersPanel()` content in `SingleChildScrollView`
- Wrap `_buildPromptsPanel()` content in `SingleChildScrollView`
- Keep `_buildRecentImagesPanel()` header fixed, list in `Expanded` widget
- Add `crossAxisAlignment: CrossAxisAlignment.start` to desktop layout Row

### 8. Styling and UX

- Bottom panel (not modal):
  - Fixed 400px height
  - Spans full width below all columns
  - Top border separator
  - Close button (X) to hide panel
  - "New Discussion" button to start fresh session
- Message styling consistent with game_design_assistant_screen.dart
- Loading indicator while AI responds
- Input field with "Ask about your image generation..." hint
- Asset name displayed in header for context

## Files to Modify

1. `lib/screens/image_generation/image_generation_screen.dart` - Add all chat functionality

## Key Implementation Notes

- Reuse ChatApiService from game_design_assistant_screen.dart (already exists in services)
- Use flutter_gen_ai_chat_ui package (already in pubspec.yaml)
- Format generation parameters clearly in the context sent to AI (JSON format)
- Session persistence: reuse existing sessions unless "New Discussion" is clicked
- The chat persists as a fixed bottom panel, not a dismissible modal
- All columns made scrollable to prevent overflow issues
- AI recommendation button provides one-click access to model/LoRA suggestions
- No changes needed to other screens or services

### To-dos

- [x] Add necessary imports for chat functionality (flutter_gen_ai_chat_ui, ChatApiService, models)
- [x] Add state variables for chat panel management (controller, service, session ID, users)
- [x] Initialize chat components in initState and dispose in dispose
- [x] Add 'Discuss with AI' button below Generate Image button in prompts panel
- [x] Create persistent bottom panel (not modal) spanning all columns
- [x] Add "New Discussion" button in chat panel header
- [x] Implement session persistence logic (reuse existing sessions)
- [x] Implement _sendChatMessage method with parameter context gathering and API call
- [x] Add AI recommendation button below LoRA selection
- [x] Implement _askAIForModelRecommendation method for auto-suggestions
- [x] Make all three columns scrollable
- [x] Set crossAxisAlignment to start for column alignment
- [x] Test chat panel opening, messaging, and session creation