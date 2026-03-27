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

The OpenCode version and download URLs are pinned in
`utils/opencode_sidecar_manifest.json`.

If you want to upgrade the bundled OpenCode version:

1. Update `version` and the platform asset URLs in
   `utils/opencode_sidecar_manifest.json`.
2. Rebuild and smoke-test Arcane Forge with that pinned version.
3. Only then package and publish release artifacts.

Do not commit raw OpenCode binaries into this repo. The release scripts stage
them into build output at packaging time.

## Sidecar Asset Resolution

`utils/opencode_sidecar.py` resolves the bundled sidecar in this order:

1. `ARCANE_FORGE_OPENCODE_SOURCE_DIR`
2. `OPENCODE_LOCAL_REPO`
3. default local repo path: `~/gbtemp/opencode`
4. download the pinned archive from the URL in the manifest

The helper accepts either:

- a directory containing the exact release archive, for example
  `opencode-darwin-arm64.zip`
- a directory containing an unpacked build at
  `dist/<asset-stem>/bin/opencode`

This means contributors can package from a locally built OpenCode checkout or
let the packaging helper fetch the pinned release asset automatically.

## Local OpenCode Build Inputs

If you want to package from a local OpenCode checkout instead of downloading
release assets, make sure the repo has already produced a matching standalone
CLI build under `dist/`.

Example local repo location:

```bash
export OPENCODE_LOCAL_REPO=~/gbtemp/opencode
```

The packaging helper looks for platform builds such as:

```text
~/gbtemp/opencode/dist/opencode-darwin-arm64/bin/opencode
~/gbtemp/opencode/dist/opencode-darwin-x64/bin/opencode
~/gbtemp/opencode/dist/opencode-windows-x64/bin/opencode.exe
```

If those files are not present, the helper falls back to the manifest URLs.

## Windows Packaging

Build the Windows app first:

```bash
flutter build windows --release
```

Then package it:

```bash
python3 utils/package_release.py
```

What the script does:

- reads the app version from `pubspec.yaml`
- copies updater files into `build/windows/x64/runner/Release`
- stages the pinned OpenCode sidecar into
  `build/windows/x64/runner/Release/opencode_sidecar/`
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

Then package it:

```bash
python3 utils/package_release_macos.py
```

What the script does:

- reads the app version from `pubspec.yaml`
- locates `build/macos/Build/Products/Release/Arcane Forge Studio.app`
- stages the pinned OpenCode sidecar into
  `Arcane Forge Studio.app/Contents/Resources/opencode_sidecar/`
- verifies that the sidecar manifest and binary are present
- creates a DMG at
  `build/release/Arcane-Forge-Studio-macOS-v<version>.dmg`

The macOS script chooses the OpenCode sidecar platform from the current host
architecture by default.

You can override it explicitly if needed:

```bash
ARCANE_FORGE_OPENCODE_PLATFORM=darwin-x64 python3 utils/package_release_macos.py
```

Supported macOS values today:

- `darwin-arm64`
- `darwin-x64`

## Publishing Checklist

Use this checklist before publishing a release:

1. Bump the app version in `pubspec.yaml`.
2. If needed, update `utils/opencode_sidecar_manifest.json` to the new pinned
   OpenCode version.
3. Run local validation:
   `dart analyze lib/screens/development/coding_agent test`
4. Run targeted sidecar tests:
   `flutter test test/opencode_server_manager_test.dart test/coding_agent_config_service_test.dart test/coding_agent_screen_widget_test.dart`
5. Build the desktop artifact for the platform you are releasing.
6. Run the matching packaging script from `utils/`.
7. Inspect the packaged artifact and confirm the sidecar exists:
   - Windows: `opencode_sidecar/manifest.json` and `opencode.exe`
   - macOS: `Contents/Resources/opencode_sidecar/manifest.json` and `opencode`
8. Smoke-test on a machine without a system `opencode` installed.
9. Publish the artifact to GitHub Releases.

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
