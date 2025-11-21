from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path
from urllib.request import Request, urlopen
import json
import zipfile

# Configuration
REPO_OWNER = "arcane-forge-ai"
REPO_NAME = "arcane-forge-studio"
RELEASE_ASSET_PREFIX = "arcane-forge-studio-windows-v"
RELEASE_ASSET_SUFFIX = ".zip"

# Paths
SCRIPT_DIR = Path(__file__).resolve().parent
VERSION_FILE = SCRIPT_DIR / "version.txt"


def read_current_version() -> str | None:
    """Read current version from version.txt, or return None if not found."""
    if not VERSION_FILE.exists():
        return None
    
    version = VERSION_FILE.read_text(encoding="utf-8").strip()
    return version if version else None


def get_latest_release() -> tuple[str, str]:
    """
    Query GitHub API for latest release.
    Returns tuple of (download_url, version).
    """
    api_url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest"
    
    headers = {
        "User-Agent": "arcane-forge-updater",
        "Accept": "application/vnd.github.v3+json"
    }
    
    print("[INFO] Checking for latest release...")
    
    request = Request(api_url, headers=headers)
    with urlopen(request) as response:
        release_data = json.loads(response.read().decode())
    
    tag_name = release_data.get("tag_name")
    if not tag_name:
        raise RuntimeError("Latest release missing tag_name")
    
    version = tag_name.lstrip("v")
    asset_name = f"{RELEASE_ASSET_PREFIX}{version}{RELEASE_ASSET_SUFFIX}"
    
    # Find the matching asset
    for asset in release_data.get("assets", []):
        if asset.get("name") == asset_name:
            download_url = asset.get("browser_download_url")
            if not download_url:
                raise RuntimeError(f"Asset {asset_name} missing download URL")
            return download_url, version
    
    raise RuntimeError(f"Asset {asset_name} not found in latest release")


def compare_versions(current: str, latest: str) -> bool:
    """
    Compare version strings.
    Returns True if latest > current.
    """
    def version_tuple(v: str) -> tuple:
        return tuple(map(int, v.lstrip("v").split(".")))
    
    try:
        return version_tuple(latest) > version_tuple(current)
    except Exception:
        # If comparison fails, assume update is needed
        return True


def download_file(url: str, dest: Path) -> None:
    """Download file from URL to destination."""
    print(f"[INFO] Download URL: {url}")
    print("[INFO] Downloading release archive...")
    
    headers = {"User-Agent": "arcane-forge-updater"}
    request = Request(url, headers=headers)
    
    with urlopen(request) as response:
        dest.write_bytes(response.read())
    
    print("[INFO] Download completed.")


def extract_and_apply_update(archive_path: Path, dest_dir: Path) -> None:
    """Extract archive and copy files to destination."""
    print("[INFO] Extracting archive...")
    
    with tempfile.TemporaryDirectory() as temp_extract_dir:
        extract_dir = Path(temp_extract_dir)
        
        with zipfile.ZipFile(archive_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
        
        print("[INFO] Extraction completed.")
        print("[INFO] Applying update files...")
        
        # Copy all files from extracted directory to destination
        for item in extract_dir.iterdir():
            dest_item = dest_dir / item.name
            if item.is_file():
                shutil.copy2(item, dest_item)
            elif item.is_dir():
                if dest_item.exists():
                    shutil.rmtree(dest_item)
                shutil.copytree(item, dest_item)
        
        print("[INFO] Files applied successfully.")


def main() -> int:
    print("=" * 60)
    print("Arcane Forge Studio - Update Manager")
    print("=" * 60)
    print()
    
    # Read current version
    current_version = read_current_version()
    force_update = False
    
    if current_version is None:
        print("[WARNING] Missing version.txt")
        print("Cannot determine current version.")
        response = input("Do you still want to check for updates? (Y/N): ").strip().upper()
        if response != "Y":
            print("Update cancelled.")
            return 0
        force_update = True
        current_version = "unknown"
    
    print()
    
    # Get latest release info
    try:
        download_url, latest_version = get_latest_release()
    except Exception as e:
        print(f"[ERROR] Failed to query latest release: {e}")
        return 1
    
    # Check if update is needed
    if force_update:
        print(f"Latest version available: {latest_version}")
    else:
        print(f"Current version: {current_version}")
        print(f"Latest version: {latest_version}")
        
        if not compare_versions(current_version, latest_version):
            print()
            print(f"You are already on the latest version!")
            return 0
    
    print()
    
    # Download and apply update
    if force_update:
        print(f"Downloading and installing version {latest_version}...")
    else:
        print(f"Updating from {current_version} to {latest_version}...")
    
    print()
    
    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            archive_path = temp_path / "release.zip"
            
            # Download
            download_file(download_url, archive_path)
            
            # Extract and apply
            extract_and_apply_update(archive_path, SCRIPT_DIR)
        
        # Update version file
        VERSION_FILE.write_text(latest_version, encoding="utf-8")
        
        print()
        if force_update:
            print(f"Installation completed successfully. Version {latest_version} installed.")
        else:
            print(f"Update applied successfully. Now on version {latest_version}.")
        
        return 0
    
    except Exception as e:
        print()
        print(f"[ERROR] Update failed: {e}")
        return 1


if __name__ == "__main__":
    try:
        exit_code = main()
    except KeyboardInterrupt:
        print()
        print("Update cancelled by user.")
        exit_code = 1
    except Exception as e:
        print()
        print(f"[ERROR] Unexpected error: {e}")
        exit_code = 1
    
    print()
    input("Press Enter to exit...")
    sys.exit(exit_code)

