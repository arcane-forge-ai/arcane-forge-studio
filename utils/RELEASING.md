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
- the complete Arcane Forge game-agent skill and a hashed `skill-manifest.json`
- Windows updater scripts for the Windows zip release

Arcane Forge installs the bundled OpenCode sidecar into app-managed storage on
first use and prefers that installed copy over any system `opencode`.

## Bundled Game Agent Skill

Both desktop packaging scripts fetch `skills/arcane-forge-game-agent` from
the public `arcane-forge-ai/arcane-forge-agent-kit` repository's `main` branch.
They resolve the branch to a commit first, then download that exact commit.
The full skill directory, including scripts, references, and assets, is stored
under `opencode_sidecar/skills/arcane-forge-game-agent/`. The adjacent
`skill-manifest.json` records the source ref, full commit, and every file's
SHA-256 hash. Packaging fails if fetching or verification fails.

For a reproducible rebuild, set `ARCANE_FORGE_SKILL_REF` to the recorded commit
before invoking either packaging script. A tag or branch is also accepted.

```bash
ARCANE_FORGE_SKILL_REF=<recorded-commit> python3 utils/package_release_macos.py
```

To stage or inspect the skill separately without creating a release artifact:

```bash
python3 utils/game_agent_skill.py utils/release_dependencies/opencode_sidecar
```

At startup, Studio verifies and installs the shipped skill into its own
application-support directory under `opencode_sidecar/skills/<commit>/`.
It adds this path to its generated OpenCode configuration, then checks
OpenCode's `/skill` response for the exact name and installed location.
The embedded agent's Utilities drawer shows the status and a **Repair skill**
action. Repair uses the shipped copy and restarts the app-managed server.

No download is needed at application startup. Studio does not install into
global agent folders or game repositories. Missing or invalid skill files
produce a status message without disabling the coding agent. Skill
installation does not configure Arcane Forge authentication or authorize game
building or asset generation. The Python helpers require a local Python 3
runtime; Python is not bundled by this change.

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

### Manual Windows Build In GitHub Actions

The **Prepare Windows release** workflow at
`.github/workflows/windows-release.yml` builds a Windows x64 release candidate
on `windows-2022`. Once the workflow is available on the repository's default
branch, open **Actions → Prepare Windows release → Run workflow** and select
the release source branch. Running it uploads a temporary Actions artifact;
publishing that candidate to GitHub Releases remains a separate step.

The workflow uses read-only repository permissions and immutable action
revisions. It pins Flutter 3.38.5 to
`f6ff1529fd6d8af5f706051d9251ac9231c83407` and the game-agent skill to
`2d52432aa65a8706a903d1f8d7b7e5426cf823bf`. OpenCode remains pinned by
`utils/opencode_sidecar_manifest.json`. Update these inputs deliberately when
preparing a later release.

The clean runner creates a sanitized `.env` asset using only the public
Supabase settings from `Makefile`, the production API endpoint, and online
mode settings. It omits `DEFAULT_USER_ID`. The Flutter build uses those same
explicit production values and enforces `pubspec.lock`. The workflow copies
x64 `vcruntime140*.dll` files from the runner's Windows system directory,
because local ignored release dependencies are unavailable in a clean clone.

Before upload, the job runs the Python packaging suite and full Flutter test
suite, builds and packages the app, extracts the ZIP, compares every file hash
with the packaged build, verifies skill provenance and all skill hashes, and
runs the bundled OpenCode `--version` and Python helper `--help` using isolated
configuration and HTTP(S) proxies pointing to a closed loopback port. It then
confirms that the extracted app stays running for 12 seconds and closes when
its window receives a close request. A failed check prevents candidate upload.

Download the resulting Actions artifact and retain all three files:

- `arcane-forge-studio-windows-v<version>.zip`
- `SHA256SUMS`
- `windows-verification.json`

This is an unsigned ZIP candidate. The startup check does not exercise
authentication, authenticated API calls, the embedded WebView, skill
installation through the app, or a complete game-development session. Windows
SmartScreen and additional runtime requirements still need verification on a
normal Windows machine. Python 3 is required for the bundled skill helpers.
Do not describe local workflow validation as a completed Windows build; check
the actual Actions result and its verification report before publishing.

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
- re-signs the outer app bundle after adding resources and requires deep,
  strict code-signature verification to pass
- creates a DMG at
  `build/release/Arcane-Forge-Studio-macOS-v<version>.dmg`

Bundling resources changes the app's resource seal. The packaging script
re-signs only the outer app and preserves its identifier, entitlements,
requirements, flags, and runtime metadata. It leaves nested code signatures,
including the bundled OpenCode executable's signature, intact.

An already ad-hoc-signed app defaults to ad-hoc re-signing. An app with another
signature requires an explicit `MACOS_CODESIGN_IDENTITY`; packaging stops
instead of silently replacing that signature with an ad-hoc signature:

```bash
MACOS_CODESIGN_IDENTITY="Developer ID Application: Your Team (TEAMID)" \
  python3 utils/package_release_macos.py
```

This step does not notarize the app or DMG. An ad-hoc signature supports local
integrity verification but does not establish Developer ID trust for
Gatekeeper. Verify the final DMG's architecture and distribution requirements
before publishing; a `darwin-arm64` sidecar supports Apple Silicon only.

## Publishing Checklist

Use this checklist before publishing a release:

1. Bump the app version in `pubspec.yaml`.
2. If needed, update `version` in `utils/opencode_sidecar_manifest.json`.
3. Run local validation:
   `dart analyze lib/screens/development/coding_agent test`
4. Run targeted sidecar tests:
   `flutter test test/opencode_server_manager_test.dart test/coding_agent_config_service_test.dart test/game_agent_skill_service_test.dart test/coding_agent_screen_widget_test.dart`
   and `python3 -m unittest discover -s utils/tests -v` for skill packaging.
5. Build the desktop artifact for the platform you are releasing.
6. Run `python3 utils/opencode_sidecar.py <platform>` to stage the sidecar.
7. Run the matching packaging script from `utils/`.
8. Inspect the packaged artifact and confirm the sidecar exists:
   - Windows: `opencode_sidecar/manifest.json` and `opencode.exe`
   - macOS: `Contents/Resources/opencode_sidecar/manifest.json` and `opencode`
   - Both: `skill-manifest.json` and the full `skills/arcane-forge-game-agent/`
     directory; retain the recorded source commit for rebuilds.
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
