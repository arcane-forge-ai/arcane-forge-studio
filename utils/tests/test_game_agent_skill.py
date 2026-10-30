from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import game_agent_skill as skill
import package_release as windows
import package_release_macos as macos


COMMIT = "1234567890abcdef1234567890abcdef12345678"
FRONTMATTER = b"---\nname: arcane-forge-game-agent\ndescription: Game workflows\n---\nInstructions\n"
FILES = {
    "SKILL.md": FRONTMATTER,
    "scripts/arcane_forge.py": b"print('helper')\n",
    "scripts/nested/config.json": b"{}\n",
    "references/setup.md": b"Setup instructions\n",
    "assets/template.txt": b"template\n",
}


def archive_bytes(files=None, extras=None):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as archive:
        archive.writestr(f"arcane-forge-agent-kit-{COMMIT}/README.md", "Not part of the skill")
        for name, data in (FILES if files is None else files).items():
            archive.writestr(f"arcane-forge-agent-kit-{COMMIT}/skills/{skill.SKILL_NAME}/{name}", data)
        for name, data in extras or []:
            archive.writestr(name, data)
    return output.getvalue()


class SkillBundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.sidecar = Path(self.temp.name) / "deps" / "opencode_sidecar"

    def stage(self, *, files=None, ref="main", archive=None):
        with patch.object(skill, "_download", side_effect=[
            json.dumps([{"sha": COMMIT}]).encode(),
            archive if archive is not None else archive_bytes(files),
        ]) as download:
            directory = skill.stage_game_agent_skill(self.sidecar, ref)
        return directory, download

    def snapshot(self):
        return {entry.relative_to(self.sidecar).as_posix(): entry.read_bytes()
                for entry in self.sidecar.rglob("*") if entry.is_file()}

    def test_resolves_branch_then_fetches_immutable_commit_and_all_supporting_files(self):
        directory, download = self.stage()
        self.assertEqual(download.call_args_list[0].args[0],
                         "https://api.github.com/repos/arcane-forge-ai/arcane-forge-agent-kit/commits?sha=main&per_page=1")
        self.assertTrue(download.call_args_list[1].args[0].endswith(f"/zip/{COMMIT}"))
        self.assertEqual({p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file()}, set(FILES))
        manifest = skill.verify_bundled_skill(self.sidecar)
        self.assertEqual(manifest["sourceRef"], "main")
        self.assertEqual(manifest["sourceCommit"], COMMIT)
        self.assertEqual(manifest["sourceRepository"], skill.SOURCE_REPOSITORY)
        self.assertEqual(manifest["files"], {name: hashlib.sha256(data).hexdigest() for name, data in FILES.items()})

    def test_explicit_source_ref_is_url_encoded_and_recorded(self):
        _, download = self.stage(ref="release/stable")
        self.assertTrue(download.call_args_list[0].args[0].endswith("/commits?sha=release%2Fstable&per_page=1"))
        self.assertEqual(skill.verify_bundled_skill(self.sidecar)["sourceRef"], "release/stable")

    def test_network_failure_does_not_replace_existing_valid_bundle(self):
        self.stage()
        previous = self.snapshot()
        with patch.object(skill, "_download", side_effect=skill.SkillBundleError("offline")):
            with self.assertRaisesRegex(skill.SkillBundleError, "offline"):
                skill.stage_game_agent_skill(self.sidecar)
        self.assertEqual(self.snapshot(), previous)

    def test_incomplete_download_does_not_replace_existing_valid_bundle(self):
        self.stage()
        previous = self.snapshot()
        files = {name: value for name, value in FILES.items() if not name.startswith("references/")}
        with self.assertRaisesRegex(skill.SkillBundleError, "references/"):
            self.stage(files=files)
        self.assertEqual(self.snapshot(), previous)

    def test_publish_failure_restores_existing_skill_and_manifest(self):
        self.stage()
        previous = self.snapshot()
        rename = Path.rename

        def fail_new_manifest(source, target):
            if source.name == skill.MANIFEST_NAME and source.parent.name == "staged":
                raise OSError("simulated rename failure")
            return rename(source, target)

        with patch.object(Path, "rename", fail_new_manifest):
            with self.assertRaisesRegex(skill.SkillBundleError, "simulated rename failure"):
                self.stage(files={**FILES, "assets/new.txt": b"new"})
        self.assertEqual(self.snapshot(), previous)
        skill.verify_bundled_skill(self.sidecar)

    def test_path_traversal_is_rejected_without_writing_outside_staging(self):
        with self.assertRaisesRegex(skill.SkillBundleError, "Unsafe skill path"):
            self.stage(archive=archive_bytes(extras=[("../escaped", b"bad")]))
        self.assertFalse((Path(self.temp.name) / "escaped").exists())

    def test_symbolic_link_in_skill_archive_is_rejected(self):
        buffer = io.BytesIO(archive_bytes())
        with zipfile.ZipFile(buffer, "a") as archive:
            link = zipfile.ZipInfo(f"arcane-forge-agent-kit-{COMMIT}/skills/{skill.SKILL_NAME}/link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(link, "../../outside")
        with self.assertRaisesRegex(skill.SkillBundleError, "symbolic link"):
            self.stage(archive=buffer.getvalue())

    def test_case_colliding_paths_are_rejected_for_windows(self):
        with self.assertRaisesRegex(skill.SkillBundleError, "Duplicate skill archive path"):
            self.stage(files={**FILES, "skill.md": b"collision"})

    def test_trailing_dot_or_space_paths_are_rejected_for_windows(self):
        for name in ("assets/invalid.", "assets/invalid /file.txt", "assets/CON.txt", "assets/question?.txt", "assets/control\n.txt"):
            with self.subTest(name=name), self.assertRaisesRegex(skill.SkillBundleError, "Unsafe skill path"):
                self.stage(files={**FILES, name: b"invalid"})

    def test_symbolic_link_skills_parent_fails_verification(self):
        self.stage()
        skills_parent = self.sidecar / "skills"
        moved_parent = self.sidecar / "other-skills"
        skills_parent.rename(moved_parent)
        skills_parent.symlink_to(moved_parent, target_is_directory=True)
        with self.assertRaisesRegex(skill.SkillBundleError, "symbolic links"):
            skill.verify_bundled_skill(self.sidecar)

    def test_corrupted_or_missing_files_fail_verification(self):
        directory, _ = self.stage()
        target = directory / "scripts" / "arcane_forge.py"
        target.write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(skill.SkillBundleError, "manifest hashes"):
            skill.verify_bundled_skill(self.sidecar)
        target.unlink()
        with self.assertRaisesRegex(skill.SkillBundleError, "manifest hashes"):
            skill.verify_bundled_skill(self.sidecar)

    def test_unlisted_files_fail_verification(self):
        directory, _ = self.stage()
        (directory / "unexpected.py").write_text("unexpected", encoding="utf-8")
        with self.assertRaisesRegex(skill.SkillBundleError, "manifest hashes"):
            skill.verify_bundled_skill(self.sidecar)

    def test_manifest_path_escape_is_rejected(self):
        self.stage()
        manifest_path = self.sidecar / skill.MANIFEST_NAME
        manifest = json.loads(manifest_path.read_text())
        manifest["files"]["../outside"] = "0" * 64
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(skill.SkillBundleError, "Unsafe skill path"):
            skill.verify_bundled_skill(self.sidecar)

    def test_wrong_name_or_missing_frontmatter_is_rejected(self):
        with self.assertRaisesRegex(skill.SkillBundleError, "frontmatter"):
            self.stage(files={**FILES, "SKILL.md": b"# No frontmatter\n"})

    def test_bad_commit_response_is_rejected_before_archive_download(self):
        with patch.object(skill, "_download", return_value=b'[{"sha":"main"}]') as download:
            with self.assertRaisesRegex(skill.SkillBundleError, "full commit SHA"):
                skill.stage_game_agent_skill(self.sidecar)
        self.assertEqual(download.call_count, 1)

    def test_download_failure_has_url_context(self):
        with patch.object(skill.urllib.request, "urlopen", side_effect=OSError("no network")):
            with self.assertRaisesRegex(skill.SkillBundleError, "Could not download https://example.invalid"):
                skill._download("https://example.invalid", 100)

    def test_copy_helpers_include_verified_skill_without_network(self):
        self.stage()
        binary = self.sidecar / "opencode"
        binary.write_bytes(b"fixture")
        (self.sidecar / "manifest.json").write_text(json.dumps({"binaryName": "opencode"}))
        windows_build = Path(self.temp.name) / "windows-build"
        windows_build.mkdir()
        app = Path(self.temp.name) / "Studio.app"
        app.mkdir()
        with patch.object(windows, "RELEASE_DEPENDENCIES_DIR", self.sidecar.parent), \
             patch.object(macos, "RELEASE_DEPS_SIDECAR_DIR", self.sidecar), \
             patch.object(skill, "_download", side_effect=AssertionError("copy must not fetch")):
            windows.copy_release_dependencies(windows_build)
            macos.copy_opencode_sidecar(app)
        skill.verify_bundled_skill(windows_build / "opencode_sidecar")
        skill.verify_bundled_skill(app / macos.SIDECAR_RESOURCE_DIR)

    def test_each_packager_fetches_skill_before_copy_and_honors_ref(self):
        for module, copy_name, archive_name in [
            (windows, "copy_release_dependencies", "create_archive"),
            (macos, "copy_opencode_sidecar", "create_dmg"),
        ]:
            with self.subTest(module=module.__name__), \
                 patch.object(module, "read_version", return_value="1.6.1"), \
                 patch.object(module, "ensure_build_directory", return_value=self.sidecar), \
                 patch.object(module, "verify_staged_sidecar"), \
                 patch.object(module, "stage_game_agent_skill") as stage, \
                 patch.object(module, copy_name) as copy, \
                 patch.object(module, archive_name, return_value=self.sidecar / "release.zip"), \
                 patch.dict(os.environ, {"ARCANE_FORGE_SKILL_REF": COMMIT}):
                calls = []
                stage.side_effect = lambda *args: calls.append("stage")
                copy.side_effect = lambda *args: calls.append("copy")
                if module is windows:
                    with patch.object(module, "copy_update_assets"):
                        self.assertEqual(module.main(), 0)
                else:
                    with patch.object(module, "get_dmg_size", return_value="1 MB"), \
                         patch.object(module, "sign_and_verify_app"):
                        self.assertEqual(module.main(), 0)
                self.assertEqual(stage.call_args.args[1], COMMIT)
                self.assertEqual(calls, ["stage", "copy"])


if __name__ == "__main__":
    unittest.main()
