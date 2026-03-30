# Release Packaging and Publishing

This document explains how Arcane Forge packages, verifies, and publishes
release artifacts now that the app ships a managed OpenCode sidecar.

The current release tooling lives in this folder:

- `utils/opencode_sidecar_manifest.json`
- `utils/opencode_sidecar.py`
- `utils/package_release.py`
- `utils/package_release_macos.py`
- `utils/update.py`
- `utils/update.bat`

## What We Ship

Arcane Forge release artifacts now include:

- the Flutter desktop app build
- a pinned OpenCode CLI sidecar
- a small sidecar `manifest.json` next to the bundled binary
- Windows updater scripts for the Windows zip release

Arcane Forge installs the bundled OpenCode sidecar into app-managed storage on
first use and prefers that installed copy over any system `opencode`.

## Source Of Truth

The OpenCode version is pinned in `utils/opencode_sidecar_manifest.json`.
The manifest contains a single `version` field and a `urlTemplate` that
constructs download URLs at runtime. Bumping the version is a single edit.

If you want to upgrade the bundled OpenCode version:

1. Update `version` in `utils/opencode_sidecar_manifest.json`.
2. Rebuild and smoke-test Arcane Forge with that pinned version.
3. Only then package and publish release artifacts.

Do not commit raw OpenCode binaries into this repo. The sidecar prep script
stages them into `utils/release_dependencies/` (which is gitignored).

## Sidecar Prep Step

Before running either packaging script, stage the sidecar binary:

```bash
python3 utils/opencode_sidecar.py <platform>
```

Available platforms: `darwin-arm64`, `darwin-x64`, `windows-x64`.

This downloads the pinned archive from GitHub and extracts the binary into
`utils/release_dependencies/opencode_sidecar/`.

## Sidecar Asset Resolution

`utils/opencode_sidecar.py` resolves the sidecar binary in this order:

1. If `OPENCODE_LOCAL_REPO` is set, look for the binary or archive there.
2. Otherwise, download the pinned archive from the GitHub release URL.

## Local OpenCode Build Inputs

If you want to package from a local OpenCode checkout instead of downloading
release assets, set the `OPENCODE_LOCAL_REPO` environment variable to point at
your local checkout. Make sure it has already produced a matching standalone CLI
build under `dist/`.

```bash
export OPENCODE_LOCAL_REPO=/path/to/your/opencode
```

The script looks for platform builds such as:

```text
$OPENCODE_LOCAL_REPO/dist/opencode-darwin-arm64/bin/opencode
$OPENCODE_LOCAL_REPO/dist/opencode-windows-x64/bin/opencode.exe
```

If those files are not present, the script falls back to the GitHub download.

## Windows Packaging

Build the Windows app first:

```bash
flutter build windows --release
```

Prep the sidecar and then package:

```bash
python3 utils/opencode_sidecar.py windows-x64
python3 utils/package_release.py
```

What the packaging script does:

- reads the app version from `pubspec.yaml`
- copies updater files into `build/windows/x64/runner/Release`
- copies everything from `utils/release_dependencies/` (including the sidecar)
  into `build/windows/x64/runner/Release/`
- verifies that `opencode_sidecar/manifest.json` and `opencode.exe` exist
- zips the release directory into
  `build/release/arcane-forge-studio-windows-v<version>.zip`

Windows release naming matters because `utils/update.py` expects the archive to
follow this exact pattern:

```text
arcane-forge-studio-windows-v<version>.zip
```

## macOS Packaging

Build the macOS app first:

```bash
flutter build macos --release
```

Prep the sidecar and then package:

```bash
python3 utils/opencode_sidecar.py darwin-arm64
python3 utils/package_release_macos.py
```

What the packaging script does:

- reads the app version from `pubspec.yaml`
- locates `build/macos/Build/Products/Release/Arcane Forge Studio.app`
- copies the sidecar from `utils/release_dependencies/opencode_sidecar/` into
  `Arcane Forge Studio.app/Contents/Resources/opencode_sidecar/`
- verifies that the sidecar manifest and binary are present
- creates a DMG at
  `build/release/Arcane-Forge-Studio-macOS-v<version>.dmg`

## Publishing Checklist

Use this checklist before publishing a release:

1. Bump the app version in `pubspec.yaml`.
2. If needed, update `version` in `utils/opencode_sidecar_manifest.json`.
3. Run local validation:
   `dart analyze lib/screens/development/coding_agent test`
4. Run targeted sidecar tests:
   `flutter test test/opencode_server_manager_test.dart test/coding_agent_config_service_test.dart test/coding_agent_screen_widget_test.dart`
5. Build the desktop artifact for the platform you are releasing.
6. Run `python3 utils/opencode_sidecar.py <platform>` to stage the sidecar.
7. Run the matching packaging script from `utils/`.
8. Inspect the packaged artifact and confirm the sidecar exists:
   - Windows: `opencode_sidecar/manifest.json` and `opencode.exe`
   - macOS: `Contents/Resources/opencode_sidecar/manifest.json` and `opencode`
9. Smoke-test on a machine without a system `opencode` installed.
10. Publish the artifact to GitHub Releases.

## Contributor Notes

- The app-managed OpenCode config is generated at runtime by Arcane Forge and is
  not stored in workspace `.opencode` folders.
- Packaging the sidecar is not the same as shipping the OpenCode desktop app.
  We bundle the standalone CLI used by `opencode serve`.
- Windows sidecar packaging is already in place even though the embedded
  Windows UI remains separately gated.
- If the sidecar helper cannot find local build output and cannot download the
  pinned asset, packaging should fail fast instead of silently creating a
  sidecar-less release.
