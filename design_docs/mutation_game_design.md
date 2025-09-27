# Start a game design conversation from mutation feedbacks

## Summary
- The core idea is to give user an easy way to start game design conversation from mutation feedbacks
- workflow:
  1. User runs feedback analysis and views mutation briefs results
  2. User selects several mutation brief(s) from the analysis results
  3. User clicks a button `Start Mutation Design`
  4. Screen switch to `Game Design Assistant`
  5. Start a new conversation, and send out first message as user, the message should include:
    - Game Introduction surrounded by `=====Game Introduction=====`. The content of game introduction can be fetched from API like what we have in `Project Home Screen`
    - Code Map surrounded by `=====Code Map=====`. The content of code map can be fetched from API like what we have in `Release Info` screen
    - Mutation Brief Summaries surrounded by `=====Mutation Brief Summaries=====`. This is the mutation briefs user selected in previous step 2.
    - Prompt from [mutation_design_prompt.md](./assets/requests/mutation_design_prompt.md)
- User should be able to continue the conversation just like normal other conversations
- If do-able, let's name the conversation in format `YY-MM-DD-HH-MM Mutation Design`

---

## Implementation Design (Claude Analysis)

### Current System Understanding:

1. **Feedback Screen**: Users can select multiple feedbacks using checkboxes, currently has "Free Discuss" and "Improvement Doc" buttons in action bar
2. **Game Design Assistant**: Uses flutter_gen_ai_chat_ui with session management, supports starting new conversations via `_startNewConversation()`
3. **Project Data**: Game introduction available via `ProjectsApiService.getProjectById()` → `project.gameIntroduction`
4. **Code Map Data**: Available via `project.codeMapUrl` field, requires HTTP request to fetch content
5. **Navigation**: Uses `MenuAppController.changeScreen(ScreenType.gameDesignAssistant)` for navigation

### Proposed Implementation:

#### 1. **UI Changes (feedback_screen.dart)**
- Add "Start Mutation Design" button in action bar next to existing buttons
- Button enabled only when `_selectedFeedbackIds.isNotEmpty`
- Use consistent styling with existing buttons but distinct visual identity

#### 2. **Data Collection Strategy**
- **Game Introduction**: `await _projectsApiService.getProjectById(projectId).gameIntroduction`
- **Code Map**: HTTP GET request to `project.codeMapUrl` to fetch content
- **Feedback Summaries**: Extract messages from selected feedbacks using `_selectedFeedbackIds`
- **Mutation Prompt**: Load from `assets/requests/mutation_design_prompt.md`

#### 3. **Message Composition Format**
```
=====Game Introduction=====
[fetched game introduction content]

=====Code Map=====
[fetched code map content]

=====Feedback Summaries=====
[selected feedback messages with IDs and timestamps]

[mutation design prompt content]
```

#### 4. **Implementation Flow**
1. User selects feedbacks → clicks "Start Mutation Design"
2. Show loading indicator while fetching all required data
3. Navigate to Game Design Assistant using `MenuAppController`
4. Start new conversation and auto-send composed message
5. Session continues as normal conversation

#### 5. **Technical Considerations**
- **Error Handling**: Graceful fallbacks for missing/invalid data
- **Loading UX**: Progress indicator during data fetching
- **Content Formatting**: Handle various code map content types (text/JSON/HTML)
- **Session Naming**: Implement `YY-MM-DD-HH-MM Mutation Design` format if API supports custom names

### Discussion Points:
1. **Error Handling Strategy**: How to handle missing game introduction or invalid code map URLs?

    BG: If any of the 3 info is missing, just use "Not Available at this moment" as value
    ✅ **IMPLEMENTED**: Added fallback values for missing data

2. **Loading UX**: Show loading dialog or navigate first then show loading in chat?

    BG: I like us to show a loading dialog first and then move to the chat
    ✅ **IMPLEMENTED**: Added loading dialog during data collection

3. **Code Map Content**: How to handle different content types returned by code map URL?

    BG: We should treat all types as plain texts
    ✅ **IMPLEMENTED**: All content treated as plain text via HTTP response body

4. **Session Naming**: Does backend API support custom session names?

    BG: Ok I've updated the backend API and you can refer the updated openapi def. Now it supports passing a custom session name when sending through chat endpoint
    ✅ **IMPLEMENTED**: Added title field to ChatRequest model and API call

5. **Button Placement**: Preferred location and styling for the new button?

    BG: no I will let you deside where it is.
    ✅ **IMPLEMENTED**: Added orange button in action bar with auto_fix_high icon

---

## Implementation Status: ✅ COMPLETED

### Files Modified:
1. **`lib/screens/feedback/feedback_analyze_screen.dart`**
   - Added mutation brief selection functionality with checkboxes
   - Added "Start Mutation Design" button to mutation briefs tab action bar
   - Implemented `_startMutationDesign()` method with data collection and navigation
   - Added loading dialog and error handling

2. **`lib/services/mutation_design_service.dart`** (NEW)
   - Created singleton service for data sharing between screens

3. **`lib/screens/game_design_assistant/game_design_assistant_screen.dart`**
   - Added mutation design data check in `initState()`
   - Implemented auto-send functionality for mutation design messages
   - Added custom session title support

4. **`lib/screens/game_design_assistant/models/api_models.dart`**
   - Extended `ChatRequest` model to support custom session titles

### Key Features Implemented:
- ✅ Mutation brief selection with checkboxes in feedback analyze screen
- ✅ "Start Mutation Design" button in mutation briefs tab action bar (orange color, auto_fix_high icon)
- ✅ Data collection (game intro, code map, mutation brief summaries, mutation prompt)
- ✅ Loading dialog with progress indicator
- ✅ Error handling with fallback values
- ✅ Navigation to Game Design Assistant
- ✅ Automatic message sending with composed content
- ✅ Custom session naming (`YY-MM-DD-HH-MM Mutation Design` format)
- ✅ Proper data cleanup after message is sent

### Testing Recommended:
1. Run feedback analysis to generate mutation briefs
2. Navigate to mutation briefs tab in analysis results
3. Select desired mutation briefs using checkboxes
4. Click "Start Mutation Design" button
5. Verify loading dialog appears
6. Check navigation to Game Design Assistant
7. Confirm message is auto-sent with proper formatting including selected mutation briefs
8. Verify session appears with custom title in chat history