import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_release_macos as macos


class MacOSSigningTests(unittest.TestCase):
    app = Path("/release/Arcane Forge Studio.app")

    def test_reseals_outer_bundle_and_deep_verifies_with_metadata_preserved(self):
        with patch.dict(os.environ, {"MACOS_CODESIGN_IDENTITY": ""}), \
             patch.object(macos.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, "", "Signature=adhoc\n")
            macos.sign_and_verify_app(self.app)
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[1][1:4], ["--force", "--sign", "-"])
        self.assertNotIn("--deep", commands[1])
        self.assertIn(
            "--preserve-metadata=identifier,entitlements,requirements,flags,runtime",
            commands[1],
        )
        self.assertEqual(commands[2], ["codesign", "--verify", "--deep", "--strict", str(self.app)])
        self.assertTrue(all(call.kwargs["check"] for call in run.call_args_list))

    def test_refuses_to_silently_replace_developer_identity_with_ad_hoc_signature(self):
        with patch.dict(os.environ, {"MACOS_CODESIGN_IDENTITY": ""}), \
             patch.object(macos.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, "", "Authority=Developer ID Application: Example\n")
            with self.assertRaisesRegex(SystemExit, "MACOS_CODESIGN_IDENTITY"):
                macos.sign_and_verify_app(self.app)
            self.assertEqual(run.call_count, 1)

    def test_uses_explicit_signing_identity(self):
        with patch.dict(os.environ, {"MACOS_CODESIGN_IDENTITY": "Developer ID Application: Example"}), \
             patch.object(macos.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, "", "Authority=Developer ID Application: Example\n")
            macos.sign_and_verify_app(self.app)
        self.assertEqual(run.call_args_list[1].args[0][3], "Developer ID Application: Example")

    def test_signing_and_verification_errors_stop_packaging(self):
        for failure_index in (1, 2):
            with self.subTest(failure_index=failure_index), \
                 patch.dict(os.environ, {"MACOS_CODESIGN_IDENTITY": ""}), \
                 patch.object(macos.subprocess, "run") as run:
                calls = [subprocess.CompletedProcess([], 0, "", "Signature=adhoc\n")] * failure_index
                calls.append(subprocess.CalledProcessError(1, ["codesign"], stderr="invalid signature"))
                run.side_effect = calls
                with self.assertRaisesRegex(SystemExit, "invalid signature"):
                    macos.sign_and_verify_app(self.app)
                self.assertEqual(run.call_count, failure_index + 1)

    def test_packaging_signs_after_copy_and_never_creates_dmg_when_signing_fails(self):
        order = []
        with patch.object(macos, "read_version", return_value="1.7.0"), \
             patch.object(macos, "ensure_build_directory", return_value=self.app), \
             patch.object(macos, "verify_staged_sidecar"), \
             patch.object(macos, "stage_game_agent_skill", side_effect=lambda *args: order.append("stage")), \
             patch.object(macos, "copy_opencode_sidecar", side_effect=lambda *args: order.append("copy")), \
             patch.object(macos, "sign_and_verify_app") as sign, \
             patch.object(macos, "create_dmg") as dmg:
            def fail_signing(*args):
                order.append("sign")
                raise SystemExit("signature verification failed")
            sign.side_effect = fail_signing
            with self.assertRaisesRegex(SystemExit, "signature verification failed"):
                macos.main()
        self.assertEqual(order, ["stage", "copy", "sign"])
        dmg.assert_not_called()


if __name__ == "__main__":
    unittest.main()
