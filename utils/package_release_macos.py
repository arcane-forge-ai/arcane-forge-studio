from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
MACOS_BUILD_DIR = ROOT / "build" / "macos" / "Build" / "Products" / "Release"
RELEASE_OUTPUT_DIR = ROOT / "build" / "release"
APP_NAME = "Arcane Forge Studio.app"
ASSET_NAME_TEMPLATE = "Arcane-Forge-Studio-macOS-v{version}"


def read_version() -> str:
    if not PUBSPEC.exists():
        raise SystemExit(f"pubspec.yaml not found at {PUBSPEC}")

    for line in PUBSPEC.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("version:"):
            _, value = line.split(":", 1)
            version = value.strip()
            if version:
                return version
    raise SystemExit("Unable to determine version from pubspec.yaml")


def ensure_build_directory() -> Path:
    app_path = MACOS_BUILD_DIR / APP_NAME
    if not app_path.exists():
        raise SystemExit(
            f"macOS build directory not found at {app_path}. "
            "Run `flutter build macos --release` first."
        )
    return app_path


def create_dmg(app_path: Path, version: str) -> Path:
    RELEASE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    dmg_name = ASSET_NAME_TEMPLATE.format(version=version) + ".dmg"
    dmg_path = RELEASE_OUTPUT_DIR / dmg_name
    
    # Remove existing DMG if it exists
    if dmg_path.exists():
        dmg_path.unlink()
        print(f"Removed existing DMG: {dmg_path}")
    
    # Create DMG using hdiutil
    print(f"Creating DMG: {dmg_path}")
    try:
        subprocess.run(
            [
                "hdiutil",
                "create",
                "-volname", "Arcane Forge Studio",
                "-srcfolder", str(app_path),
                "-ov",
                "-format", "UDZO",
                str(dmg_path)
            ],
            check=True,
            capture_output=True,
            text=True
        )
    except subprocess.CalledProcessError as e:
        raise SystemExit(f"Failed to create DMG: {e.stderr}")
    
    return dmg_path


def get_dmg_size(dmg_path: Path) -> str:
    """Get human-readable size of the DMG file."""
    size_bytes = dmg_path.stat().st_size
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} TB"


def main() -> int:
    version = read_version()
    print(f"Building release package for version {version}")
    
    app_path = ensure_build_directory()
    print(f"Found app bundle at: {app_path}")
    
    dmg_path = create_dmg(app_path, version)
    dmg_size = get_dmg_size(dmg_path)
    
    print(f"✓ Release DMG created: {dmg_path}")
    print(f"✓ Size: {dmg_size}")
    print(f"\nTo distribute, share the DMG file at: {dmg_path}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

