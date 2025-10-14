<!-- 4649ba65-e243-4c0d-8a92-5dc3de51ce96 0a19cfa6-6d86-4b72-82d7-05e0641be87b -->
# Add Auto Prompt Generation to Image/Music/SFX

## What we'll build

- A new UI button "Generate Prompt with AI" on each of:
- `lib/screens/image_generation/image_generation_screen.dart`
- `lib/screens/music_generation/music_generation_screen.dart`
- `lib/screens/sfx_generation/sfx_generation_screen.dart`
- Button calls backend `/generate-prompt` endpoint (per asset type) and inserts the returned prompt into the corresponding prompt field.

## Service changes

- Extend service interfaces to support prompt generation:
- `ImageAssetService.generateAutoPrompt(projectId, assetInfo, generatorInfo)`
- `MusicAssetService.generateAutoPrompt(projectId, assetInfo, generatorInfo)`
- `SfxAssetService.generateAutoPrompt(projectId, assetInfo, generatorInfo)`
- Implement in API services:
- `lib/services/image_generation_services.dart`: POST `api/v1/{project_id}/assets/generate-prompt`
- `lib/services/music_generation_services.dart`: POST `api/v1/{project_id}/music-assets/generate-prompt`
- `lib/services/sfx_generation_services.dart`: POST `api/v1/{project_id}/sfx-assets/generate-prompt`
- Return the `prompt` string from `AutoPromptGenerationResponse`.
- Implement simple mock responses in Mock services to keep app usable without backend.

## Provider changes

- Add thin wrappers that forward to services:
- `ImageGenerationProvider.generateAutoPrompt(assetInfo, generatorInfo)` (uses `currentProjectId`)
- `MusicGenerationProvider.generateAutoPrompt(projectId, assetInfo, generatorInfo)`
- `SfxGenerationProvider.generateAutoPrompt(projectId, assetInfo, generatorInfo)`

## UI changes

- Add a small button next to the prompt label or below the prompt input on each screen.
- While requesting, show loading state (disable button, spinner in icon).
- On success, set prompt controller text:
- Image: `_positivePromptController.text = prompt`
- Music: `_promptController.text = prompt`
- SFX: `_promptController.text = prompt`
- On failure, show an error SnackBar.

## Payloads

- asset_info: minimal context of current selected asset (id, name, description).
- generator_info: name and current parameters from UI:
- Image: name=`Automatic1111` (or `provider.currentBackendName`).
- Music: name=`elevenlabs`.
- SFX: name=`elevenlabs`.

### To-dos

- [ ] Add generateAutoPrompt to ImageAssetService; implement API+Mock; wire POST to /assets/generate-prompt
- [ ] Add generateAutoPrompt to MusicAssetService; implement API+Mock; POST /music-assets/generate-prompt
- [ ] Add generateAutoPrompt to SfxAssetService; implement API+Mock; POST /sfx-assets/generate-prompt
- [ ] Add generateAutoPrompt wrapper in ImageGenerationProvider using currentProjectId
- [ ] Add generateAutoPrompt wrapper in MusicGenerationProvider taking projectId
- [ ] Add generateAutoPrompt wrapper in SfxGenerationProvider taking projectId
- [ ] Add AI button to image screen; compose payload; set positive prompt
- [ ] Add AI button to music screen; compose payload; set prompt
- [ ] Add AI button to sfx screen; compose payload; set prompt