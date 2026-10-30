"""Fetch and verify the complete Arcane Forge skill shipped with OpenCode."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import stat
import tempfile
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath


SKILL_NAME = "arcane-forge-game-agent"
SOURCE_REPOSITORY = "https://github.com/arcane-forge-ai/arcane-forge-agent-kit"
MANIFEST_NAME = "skill-manifest.json"
SKILL_SUBDIRECTORY = Path("skills") / SKILL_NAME
_SHA = re.compile(r"^[0-9a-f]{40}$")
_HASH = re.compile(r"^[0-9a-f]{64}$")
_UNSAFE_CHARACTERS = re.compile(r'[\x00-\x1f<>"|?*]')
_WINDOWS_DEVICE = re.compile(r"^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)", re.IGNORECASE)
_MAX_ARCHIVE_BYTES = 128 * 1024 * 1024
_MAX_SKILL_BYTES = 64 * 1024 * 1024


class SkillBundleError(ValueError):
    """The skill could not be fetched, validated, or staged safely."""


def _download(url: str, limit: int) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Arcane-Forge-Studio-Packager", "Accept": "application/vnd.github+json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read(limit + 1)
    except Exception as exc:
        raise SkillBundleError(f"Could not download {url}: {exc}") from exc
    if len(data) > limit:
        raise SkillBundleError(f"Download exceeded the size limit: {url}")
    return data


def _relative_path(value: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value or ":" in value or _UNSAFE_CHARACTERS.search(value):
        raise SkillBundleError(f"Unsafe skill path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or any(
        part in ("", ".", "..") or part.endswith((".", " ")) or _WINDOWS_DEVICE.match(part)
        for part in value.split("/")
    ):
        raise SkillBundleError(f"Unsafe skill path: {value!r}")
    return path


def _validate_required_files(files: dict[str, str], skill_directory: Path) -> None:
    if "SKILL.md" not in files:
        raise SkillBundleError("The bundled skill is missing SKILL.md")
    for directory in ("scripts/", "references/"):
        if not any(name.startswith(directory) for name in files):
            raise SkillBundleError(f"The bundled skill is missing supporting files under {directory}")
    try:
        text = (skill_directory / "SKILL.md").read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise SkillBundleError("SKILL.md must be readable UTF-8 text") from exc
    frontmatter = re.match(r"\A---\s*\n(.*?)\n---(?:\s|$)", text, re.DOTALL)
    if frontmatter is None or not re.search(
        rf"(?m)^name:\s*['\"]?{re.escape(SKILL_NAME)}['\"]?\s*$", frontmatter.group(1)
    ):
        raise SkillBundleError(f"SKILL.md frontmatter must name {SKILL_NAME}")
    if not re.search(r"(?m)^description:\s*\S", frontmatter.group(1)):
        raise SkillBundleError("SKILL.md frontmatter must include a description")


def verify_bundled_skill(sidecar_directory: Path) -> dict:
    """Validate provenance and every file; reject incomplete or altered bundles."""
    sidecar_directory = Path(sidecar_directory)
    manifest_path = sidecar_directory / MANIFEST_NAME
    skill_directory = sidecar_directory / SKILL_SUBDIRECTORY
    try:
        if manifest_path.is_symlink() or skill_directory.is_symlink() or skill_directory.parent.is_symlink():
            raise SkillBundleError("Bundled skill files must not be symbolic links")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if (
            not isinstance(manifest, dict)
            or type(manifest.get("schemaVersion")) is not int
            or manifest.get("schemaVersion") != 1
            or manifest.get("skillName") != SKILL_NAME
            or manifest.get("sourceRepository") != SOURCE_REPOSITORY
            or not isinstance(manifest.get("sourceRef"), str)
            or not manifest["sourceRef"].strip()
            or not isinstance(manifest.get("sourceCommit"), str)
            or not _SHA.fullmatch(manifest["sourceCommit"])
        ):
            raise SkillBundleError("Invalid bundled skill provenance")
        files = manifest.get("files")
        if not isinstance(files, dict) or not files:
            raise SkillBundleError("The bundled skill manifest has no file hashes")
        for relative_name, digest in files.items():
            _relative_path(relative_name)
            if not isinstance(digest, str) or not _HASH.fullmatch(digest):
                raise SkillBundleError(f"Invalid SHA-256 hash for {relative_name}")
        if len({name.casefold() for name in files}) != len(files):
            raise SkillBundleError("Bundled skill paths must be unique ignoring case")
        actual: dict[str, str] = {}
        for entry in skill_directory.rglob("*"):
            if entry.is_symlink():
                raise SkillBundleError(f"Bundled skill files must not be symbolic links: {entry}")
            if entry.is_file():
                relative_name = entry.relative_to(skill_directory).as_posix()
                _relative_path(relative_name)
                actual[relative_name] = hashlib.sha256(entry.read_bytes()).hexdigest()
            elif not entry.is_dir():
                raise SkillBundleError(f"Unsupported bundled skill file: {entry}")
        if actual != files:
            raise SkillBundleError("Bundled skill files do not match the manifest hashes")
        _validate_required_files(files, skill_directory)
        return manifest
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SkillBundleError(f"Cannot read bundled skill at {sidecar_directory}: {exc}") from exc


def _extract_skill(archive_bytes: bytes, destination: Path) -> dict[str, str]:
    files: dict[str, str] = {}
    casefolded_names: set[str] = set()
    extracted_bytes = 0
    try:
        with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
            if len(archive.infolist()) > 10000:
                raise SkillBundleError("The skill archive has too many entries")
            roots: set[str] = set()
            for item in archive.infolist():
                name = item.filename.rstrip("/")
                path = _relative_path(name)
                roots.add(path.parts[0])
            if len(roots) != 1:
                raise SkillBundleError("Expected a GitHub archive with one repository root")
            prefix = f"{next(iter(roots))}/skills/{SKILL_NAME}/"
            for item in archive.infolist():
                if not item.filename.startswith(prefix):
                    continue
                if stat.S_ISLNK(item.external_attr >> 16):
                    raise SkillBundleError(f"Skill archive contains a symbolic link: {item.filename}")
                if item.is_dir():
                    continue
                relative_name = item.filename[len(prefix):]
                path = _relative_path(relative_name)
                if relative_name.casefold() in casefolded_names:
                    raise SkillBundleError(f"Duplicate skill archive path: {relative_name}")
                casefolded_names.add(relative_name.casefold())
                extracted_bytes += item.file_size
                if extracted_bytes > _MAX_SKILL_BYTES:
                    raise SkillBundleError("The uncompressed skill exceeded the size limit")
                data = archive.read(item)
                target = destination.joinpath(*path.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                if item.external_attr >> 16 & 0o111:
                    target.chmod(target.stat().st_mode | 0o111)
                files[relative_name] = hashlib.sha256(data).hexdigest()
    except (zipfile.BadZipFile, OSError, RuntimeError) as exc:
        raise SkillBundleError(f"Cannot extract the GitHub skill archive: {exc}") from exc
    _validate_required_files(files, destination)
    return dict(sorted(files.items()))


def stage_game_agent_skill(sidecar_directory: Path, ref: str = "main") -> Path:
    """Resolve a GitHub ref, fetch that commit, and replace only a valid skill."""
    if not isinstance(ref, str) or not ref.strip():
        raise SkillBundleError("The skill source ref must not be empty")
    ref = ref.strip()
    query = urllib.parse.urlencode({"sha": ref, "per_page": 1})
    commit_url = f"https://api.github.com/repos/arcane-forge-ai/arcane-forge-agent-kit/commits?{query}"
    try:
        commits = json.loads(_download(commit_url, 2 * 1024 * 1024))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise SkillBundleError("GitHub returned an invalid commit response") from exc
    source_commit = commits[0].get("sha") if isinstance(commits, list) and commits and isinstance(commits[0], dict) else None
    if not isinstance(source_commit, str) or not _SHA.fullmatch(source_commit):
        raise SkillBundleError("GitHub did not return a full commit SHA")
    archive_url = f"https://codeload.github.com/arcane-forge-ai/arcane-forge-agent-kit/zip/{source_commit}"
    archive_bytes = _download(archive_url, _MAX_ARCHIVE_BYTES)
    sidecar_directory = Path(sidecar_directory)
    sidecar_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".game-agent-skill-", dir=sidecar_directory) as temp:
        staging = Path(temp) / "staged"
        staged_skill = staging / SKILL_SUBDIRECTORY
        staged_skill.mkdir(parents=True)
        files = _extract_skill(archive_bytes, staged_skill)
        manifest = {
            "schemaVersion": 1,
            "skillName": SKILL_NAME,
            "sourceRepository": SOURCE_REPOSITORY,
            "sourceRef": ref,
            "sourceCommit": source_commit,
            "files": files,
        }
        staged_manifest = staging / MANIFEST_NAME
        staged_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        verify_bundled_skill(staging)
        target_skill = sidecar_directory / SKILL_SUBDIRECTORY
        target_manifest = sidecar_directory / MANIFEST_NAME
        target_skill.parent.mkdir(parents=True, exist_ok=True)
        previous_skill = Path(temp) / "previous-skill"
        previous_manifest = Path(temp) / "previous-manifest.json"
        if target_skill.is_symlink() or target_manifest.is_symlink() or target_skill.parent.is_symlink():
            raise SkillBundleError("Refusing to replace a symbolic-link skill bundle")
        moved_skill = moved_manifest = published_skill = published_manifest = False
        try:
            if target_skill.exists():
                target_skill.rename(previous_skill)
                moved_skill = True
            if target_manifest.exists():
                target_manifest.rename(previous_manifest)
                moved_manifest = True
            staged_skill.rename(target_skill)
            published_skill = True
            staged_manifest.rename(target_manifest)
            published_manifest = True
        except OSError as exc:
            if published_skill:
                shutil.rmtree(target_skill)
            if published_manifest:
                target_manifest.unlink()
            if moved_skill:
                previous_skill.rename(target_skill)
            if moved_manifest:
                previous_manifest.rename(target_manifest)
            raise SkillBundleError(f"Could not replace the staged skill bundle: {exc}") from exc
    print(f"Bundled {SKILL_NAME} from {ref} at {source_commit} ({len(files)} files)")
    return sidecar_directory / SKILL_SUBDIRECTORY


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--ref", default=os.environ.get("ARCANE_FORGE_SKILL_REF", "main"))
    args = parser.parse_args()
    try:
        stage_game_agent_skill(args.destination, args.ref)
    except SkillBundleError as exc:
        parser.exit(1, f"Skill packaging failed: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
