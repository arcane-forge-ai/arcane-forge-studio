<!-- c9b6d0d7-036a-410d-a852-9ef530ca8943 13cf103e-3b8a-4a5c-8718-f50e803c6374 -->
# Add A1111 Download/Install from Supabase (Settings)

### What we'll build

- A resumable background download of the A1111 zip from Supabase into `./packages/`.
- Automatic unzip to `./packages/automatic1111/` on completion (in a background isolate).
- Progress UI (with percent and state) in `lib/screens/settings/settings_screen.dart` under the A1111 section.
- On success: set `working directory` to `./packages/automatic1111/` and show a snackbar.

### New dependencies

- Add to `pubspec.yaml`:
  - `archive: ^3.6.1` (zip extraction)
  - `path: ^1.9.0` (path join, safer separators)

### New files

1) `lib/models/download_models.dart`

- Define small enums/data objects for installer state used by Provider/UI:
```dart
enum InstallerStatus { idle, downloading, extracting, completed, error }
class InstallerProgress {
  final InstallerStatus status; // downloading/extracting/etc
  final double? fraction;       // 0..1 during downloading
  final int? received;          // bytes downloaded
  final int? total;             // total bytes if known
  final String? message;        // optional error/info
  const InstallerProgress(this.status, {this.fraction, this.received, this.total, this.message});
}
```


2) `lib/services/a1111_installer_service.dart`

- Implements resumable download via `dio` with HTTP Range, saves to `./packages/<file>.zip.part` then renames to `.zip`.
- Extraction via `archive` into `./packages/automatic1111/` using `await Isolate.run(...)`.
- Public API (emits progress updates via callback):
```dart
class A1111InstallerService {
  Future<void> downloadAndInstall({
    required String url,
    required Directory baseDir,           // defaults to Directory('packages') from caller
    required void Function(InstallerProgress) onProgress,
    CancelToken? cancelToken,
  });
}
```

- Behavior:
  - Ensure `baseDir` exists.
  - Determine filename from URL (expects .zip when you update the link).
  - If `*.zip.part` exists, resume from its size using `Range: bytes=<size>-`.
  - Stream to file with `onReceiveProgress` to report `fraction`.
  - On completion, rename to `*.zip`.
  - Extract into `./packages/automatic1111/` (overwrite existing files if present).
  - Report status transitions: idle → downloading → extracting → completed, or error with message.

### Edits to existing files

1) `lib/providers/settings_provider.dart`

- Import new models and service; add installer state fields and API:
  - Fields: `InstallerStatus a1111Status`, `double a1111Progress`, `int a1111Received`, `int a1111Total`, `String? a1111Error`.
  - `CancelToken? _a1111CancelToken` for cancel support.
  - Method: `Future<void> startA1111Install({String? urlOverride})` which:
    - Uses URL constant (see below) unless override provided.
    - Calls `A1111InstallerService.downloadAndInstall(...)` with `baseDir = Directory('packages')`.
    - Updates state via `notifyListeners` from callback.
    - On completed: calls `setWorkingDirectory(ImageGenerationBackend.automatic1111, './packages/automatic1111/')` and resets error.
  - Optional: `void cancelA1111Install()`.

2) `lib/utils/app_constants.dart`

- Add a constant for the (updatable) Supabase zip URL so we don’t hardcode in UI:
```dart
class ImageGenerationConstants { /* ...existing... */
  static const String a1111ZipUrl = 'https://<will-be-updated-to-zip>'; // placeholder
}
```


3) `lib/screens/settings/settings_screen.dart`

- Inside `_buildBackendConfigCard(...)`, when `backend == ImageGenerationBackend.automatic1111`, add a new `Card` above the fields with a button and progress UI:
  - Idle: `ElevatedButton.icon( icon: Icons.download, label: Text('Download A1111 from Supabase'), onPressed: provider.startA1111Install )`
  - Downloading: `LinearProgressIndicator(value: provider.a1111Progress)` with percent text; add a `TextButton('Cancel')` wired to `cancelA1111Install()`.
  - Extracting: Indeterminate `LinearProgressIndicator()` with label “Extracting…”.
  - Completed: `Icon(Icons.check_circle, color: Colors.green)` and a caption “Installed to ./packages/automatic1111/”.
- When `a1111Status` transitions to `completed`, show `SnackBar('A1111 installed successfully')`.

### Notes on behavior

- The download is resumable: re-clicking the button (or app relaunch) will detect the `.part` file and continue from the last byte.
- No Supabase SDK needed; we use the public object URL with HTTP range.
- We do not modify existing defaults; we only set the working directory on successful completion as requested.
- All heavy extraction runs in a background isolate to keep UI responsive.

### Minimal code touchpoints

- `pubspec.yaml`: add `archive`, `path`.
- `lib/utils/app_constants.dart`: add `a1111ZipUrl`.
- `lib/models/download_models.dart`: new enums/data.
- `lib/services/a1111_installer_service.dart`: implement download+extract.
- `lib/providers/settings_provider.dart`: expose state + start/cancel.
- `lib/screens/settings/settings_screen.dart`: add button + progress UI + snackbar.

### To-dos

- [ ] Add archive and path dependencies to pubspec.yaml
- [ ] Create download models enums in lib/models/download_models.dart
- [ ] Implement A1111InstallerService with resumable download and unzip
- [ ] Add installer state and start/cancel APIs to SettingsProvider
- [ ] Add download button and progress UI to A1111 section
- [ ] Set working dir to ./packages/automatic1111/ on completion and show snackbar