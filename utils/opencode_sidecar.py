from __future__ import annotations

import json
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "utils" / "opencode_sidecar_manifest.json"
RELEASE_DEPS_SIDECAR_DIR = ROOT / "utils" / "release_dependencies" / "opencode_sidecar"
CACHE_DIR = ROOT / "build" / "opencode_sidecar_cache"


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def resolve_platform_entry(platform_key: str) -> tuple[dict, dict, str]:
    """Return (manifest, platform_entry, resolved_url) for *platform_key*."""
    manifest = load_manifest()
    platforms = manifest.get("platforms", {})
    if platform_key not in platforms:
        raise SystemExit(
            f"Unsupported OpenCode sidecar platform '{platform_key}'. "
            f"Available platforms: {', '.join(sorted(platforms))}"
        )
    entry = platforms[platform_key]
    url = manifest["urlTemplate"].format(
        version=manifest["version"],
        assetName=entry["assetName"],
    )
    return manifest, entry, url


def stage_sidecar(platform_key: str, destination_dir: Path) -> Path:
    manifest, entry, url = resolve_platform_entry(platform_key)
    binary_name = entry["binaryName"]
    destination_dir.mkdir(parents=True, exist_ok=True)

    binary_path = _resolve_binary(platform_key, manifest["version"], entry, url)
    target_binary = destination_dir / binary_name
    shutil.copy2(binary_path, target_binary)
    if not binary_name.endswith(".exe"):
        target_binary.chmod(target_binary.stat().st_mode | 0o111)

    packaged_manifest = {
        "version": manifest["version"],
        "platform": platform_key,
        "assetName": entry["assetName"],
        "binaryName": binary_name,
        "url": url,
    }
    (destination_dir / "manifest.json").write_text(
        json.dumps(packaged_manifest, indent=2) + "\n",
        encoding="utf-8",
    )
    return target_binary


def verify_staged_sidecar(destination_dir: Path) -> None:
    manifest_file = destination_dir / "manifest.json"
    if not manifest_file.exists():
        raise SystemExit(f"Bundled sidecar manifest missing at {manifest_file}")

    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    binary_name = manifest.get("binaryName")
    if not binary_name:
        raise SystemExit(f"Bundled sidecar manifest missing binaryName: {manifest_file}")

    binary_file = destination_dir / binary_name
    if not binary_file.exists():
        raise SystemExit(f"Bundled sidecar binary missing at {binary_file}")


def _resolve_binary(platform_key: str, version: str, entry: dict, url: str) -> Path:
    direct_binary = _resolve_local_binary(entry)
    if direct_binary is not None:
        return direct_binary

    archive_path = _resolve_archive(platform_key, version, entry, url)
    return _extract_binary_from_archive(platform_key, version, archive_path, entry["binaryName"])


def _resolve_local_binary(entry: dict) -> Path | None:
    local_repo = os.environ.get("OPENCODE_LOCAL_REPO", "").strip()
    if not local_repo:
        return None

    for candidate in _binary_candidates(Path(local_repo), entry):
        if candidate.exists():
            return candidate

    return None


def _binary_candidates(source_root: Path, entry: dict) -> list[Path]:
    asset_stem = entry["assetName"].removesuffix(".zip")
    binary_name = entry["binaryName"]
    return [
        source_root / binary_name,
        source_root / asset_stem / "bin" / binary_name,
        source_root / "dist" / asset_stem / "bin" / binary_name,
    ]


def _resolve_archive(platform_key: str, version: str, entry: dict, url: str) -> Path:
    local_repo = os.environ.get("OPENCODE_LOCAL_REPO", "").strip()
    if local_repo:
        local_archive = Path(local_repo) / "dist" / entry["assetName"]
        if local_archive.exists():
            return local_archive

    cache_dir = CACHE_DIR / version / platform_key
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive_path = cache_dir / entry["assetName"]
    if archive_path.exists():
        return archive_path

    print(f"Downloading {url} ...")
    try:
        with urllib.request.urlopen(url) as response:
            archive_path.write_bytes(response.read())
    except Exception as exc:
        raise SystemExit(
            f"Unable to fetch the pinned OpenCode sidecar archive from {url}. "
            f"Error: {exc}"
        )
    return archive_path


def _extract_binary_from_archive(
    platform_key: str,
    version: str,
    archive_path: Path,
    binary_name: str,
) -> Path:
    extract_root = CACHE_DIR / version / platform_key / "extracted"
    binary_path = extract_root / binary_name
    if binary_path.exists():
        return binary_path

    if extract_root.exists():
        shutil.rmtree(extract_root)
    extract_root.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(archive_path) as archive:
        archive.extractall(extract_root)

    for candidate in extract_root.rglob(binary_name):
        if candidate.is_file():
            if not binary_name.endswith(".exe"):
                candidate.chmod(candidate.stat().st_mode | 0o111)
            return candidate

    raise SystemExit(
        f"Archive {archive_path} did not contain {binary_name} after extraction."
    )


def main() -> int:
    if len(sys.argv) < 2:
        manifest = load_manifest()
        platforms = list(manifest.get("platforms", {}).keys())
        print(f"Usage: python {sys.argv[0]} <platform>")
        print(f"Available platforms: {', '.join(sorted(platforms))}")
        return 1

    platform_key = sys.argv[1]
    dest = RELEASE_DEPS_SIDECAR_DIR
    if dest.exists():
        shutil.rmtree(dest)

    binary = stage_sidecar(platform_key, dest)
    verify_staged_sidecar(dest)
    print(f"Staged sidecar for {platform_key}: {binary}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
