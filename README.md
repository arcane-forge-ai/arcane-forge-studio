# arcane_forge

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application that follows the
[simple app state management
tutorial](https://flutter.dev/to/state-management-sample).

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Assets

The `assets` directory houses images, fonts, and any other files you want to
include with your application.

The `assets/images` directory contains [resolution-aware
images](https://flutter.dev/to/resolution-aware-images).

## Windows updater

`utils/update.bat` is bundled with Windows releases to help users stay current
with the latest GitHub release. The script reads the local `version.txt`
shipped alongside the executable, compares it with the most recent release
tag, downloads the matching `arcane-forge-studio-windows-v<version>.zip`
artifact, and replaces the existing installation in place. If GitHub API rate
limits are a concern, set `GITHUB_TOKEN` before running the script so it can
authenticate when requesting release metadata.

## Building releases

Run `make build-release` to produce a distributable archive. The target builds
the Windows binary with production Supabase configuration, copies
`utils/update.bat` and a `version.txt` file into
`build/windows/x64/runner/Release`, and then packages that directory into
`build/release/arcane-forge-studio-windows-v<version>.zip` using
`utils/package_release.py`.

## Localization

This project generates localized messages based on arb files found in
the `lib/src/localization` directory.

To support additional languages, please visit the tutorial on
[Internationalizing Flutter apps](https://flutter.dev/to/internationalization).

## Authentication

The project uses [Supabase](https://supabase.com) for authentication. Provide
`SUPABASE_URL` and `SUPABASE_ANON_KEY` in your `.env` file as described in
`ENVIRONMENT_SETUP.md`.
