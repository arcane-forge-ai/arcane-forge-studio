from __future__ import annotations

import json
import os
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "utils" / "opencode_sidecar_manifest.json"
DEFAULT_LOCAL_REPO = Path.home() / "gbtemp" / "opencode"
CACHE_DIR = ROOT / "build" / "opencode_sidecar_cache"


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def resolve_platform_entry(platform_key: str) -> tuple[dict, dict]:
    manifest = load_manifest()
    platforms = manifest.get("platforms", {})
    if platform_key not in platforms:
        raise SystemExit(
            f"Unsupported OpenCode sidecar platform '{platform_key}'. "
            f"Available platforms: {', '.join(sorted(platforms))}"
        )
    return manifest, platforms[platform_key]


def stage_sidecar(platform_key: str, destination_dir: Path) -> Path:
    manifest, entry = resolve_platform_entry(platform_key)
    binary_name = entry["binaryName"]
    destination_dir.mkdir(parents=True, exist_ok=True)

    binary_path = _resolve_binary(platform_key, manifest["version"], entry)
    target_binary = destination_dir / binary_name
    shutil.copy2(binary_path, target_binary)
    if not binary_name.endswith(".exe"):
        target_binary.chmod(target_binary.stat().st_mode | 0o111)

    packaged_manifest = {
        "version": manifest["version"],
        "platform": platform_key,
        "assetName": entry["assetName"],
        "binaryName": binary_name,
        "url": entry["url"],
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


def _resolve_binary(platform_key: str, version: str, entry: dict) -> Path:
    direct_binary = _resolve_local_binary(entry)
    if direct_binary is not None:
        return direct_binary

    archive_path = _resolve_archive(platform_key, version, entry)
    return _extract_binary_from_archive(platform_key, version, archive_path, entry["binaryName"])


def _resolve_local_binary(entry: dict) -> Path | None:
    source_dir = os.environ.get("ARCANE_FORGE_OPENCODE_SOURCE_DIR")
    if source_dir:
      for candidate in _binary_candidates(Path(source_dir), entry):
        if candidate.exists():
            return candidate

    local_repo = Path(os.environ.get("OPENCODE_LOCAL_REPO", DEFAULT_LOCAL_REPO))
    for candidate in _binary_candidates(local_repo, entry):
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


def _resolve_archive(platform_key: str, version: str, entry: dict) -> Path:
    source_dir = os.environ.get("ARCANE_FORGE_OPENCODE_SOURCE_DIR")
    if source_dir:
        candidate = Path(source_dir) / entry["assetName"]
        if candidate.exists():
            return candidate

    local_repo = Path(os.environ.get("OPENCODE_LOCAL_REPO", DEFAULT_LOCAL_REPO))
    local_archive = local_repo / "dist" / entry["assetName"]
    if local_archive.exists():
        return local_archive

    cache_dir = CACHE_DIR / version / platform_key
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive_path = cache_dir / entry["assetName"]
    if archive_path.exists():
        return archive_path

    try:
        with urllib.request.urlopen(entry["url"]) as response:
            archive_path.write_bytes(response.read())
    except Exception as exc:
        raise SystemExit(
            "Unable to fetch the pinned OpenCode sidecar archive. "
            f"Tried {entry['url']} and local repo {local_repo}. Error: {exc}"
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


def stage_sidecar_to_temp(platform_key: str) -> tuple[Path, Path]:
    temp_dir = Path(tempfile.mkdtemp(prefix="arcane-forge-opencode-"))
    binary_path = stage_sidecar(platform_key, temp_dir)
    return temp_dir, binary_path
