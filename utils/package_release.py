from __future__ import annotations

import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
WINDOWS_BUILD_DIR = ROOT / "build" / "windows" / "x64" / "runner" / "Release"
RELEASE_OUTPUT_DIR = ROOT / "build" / "release"
UPDATE_SCRIPT = ROOT / "utils" / "update.bat"
VERSION_FILE_NAME = "version.txt"
ASSET_NAME_TEMPLATE = "arcane-forge-studio-windows-v{version}"


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
    if not WINDOWS_BUILD_DIR.exists():
        raise SystemExit(
            f"Windows build directory not found at {WINDOWS_BUILD_DIR}. "
            "Run `flutter build windows` first."
        )
    return WINDOWS_BUILD_DIR


def copy_update_assets(build_dir: Path, version: str) -> None:
    if not UPDATE_SCRIPT.exists():
        raise SystemExit(f"update script missing at {UPDATE_SCRIPT}")

    shutil.copy2(UPDATE_SCRIPT, build_dir / UPDATE_SCRIPT.name)
    (build_dir / VERSION_FILE_NAME).write_text(version, encoding="utf-8")


def create_archive(build_dir: Path, version: str) -> Path:
    RELEASE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    archive_base = RELEASE_OUTPUT_DIR / ASSET_NAME_TEMPLATE.format(version=version)
    shutil.make_archive(str(archive_base), "zip", root_dir=build_dir, base_dir=".")
    return archive_base.with_suffix(".zip")


def main() -> int:
    version = read_version()
    build_dir = ensure_build_directory()
    copy_update_assets(build_dir, version)
    archive = create_archive(build_dir, version)
    print(f"Release archive created: {archive}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
