"""Recorder-only publication regressions; never upload or contact pub.dev."""

import contextlib
import importlib
import io
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
prepare = importlib.import_module("prepare_release")
publish = importlib.import_module("publish_packages")
release = importlib.import_module("release_ci")


class PrepareTests(unittest.TestCase):
    def test_stable_versions(self):
        self.assertEqual(prepare.version_tuple("1.2.3"), (1, 2, 3))
        for value in ("v1.2.3", "1.2", "01.2.3", "1.2.3-rc.1"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                prepare.version_tuple(value)

    def test_preview_does_not_write(self):
        current = publish.read_version(publish.RECORDER_PUBSPEC)
        major, minor, patch_number = prepare.version_tuple(current)
        requested = f"{major}.{minor}.{patch_number + 1}"
        with patch.object(sys, "argv", ["prepare_release.py", requested]), \
                patch.object(Path, "write_text") as write, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(prepare.main(), 0)
        write.assert_not_called()

    def test_apply_updates_only_manifest_and_changelog(self):
        with patch.object(sys, "argv", ["prepare_release.py", "999.0.0", "--apply"]), \
                patch.object(Path, "write_text") as write, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(prepare.main(), 0)
        self.assertEqual(write.call_count, 2)
        self.assertIn("version: 999.0.0", write.call_args_list[0].args[0])
        self.assertIn("TODO:", write.call_args_list[1].args[0])

    def test_current_tag_is_idempotent(self):
        current = publish.read_version(publish.RECORDER_PUBSPEC)
        with patch.object(sys, "argv", ["prepare_release.py", f"v{current}", "--from-ref"]), \
                patch.object(Path, "write_text") as write, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(prepare.main(), 0)
        write.assert_not_called()


class PublicationTests(unittest.TestCase):
    def test_changelog_requires_nonempty_completed_section(self):
        for text, expected in (
            ("## 1.2.3\n\n- Ready.\n", True),
            ("## 1.2.3\n\n- TODO: Notes.\n", False),
            ("## 1.2.3\n\n## 1.2.2\n- Old.\n", False),
            ("## 1.2.2\n- Old.\n", False),
        ):
            with self.subTest(text=text), patch.object(Path, "read_text", return_value=text):
                self.assertEqual(publish.changelog_is_ready(Path("CHANGELOG.md"), "1.2.3"), expected)

    def test_upload_requires_both_confirmations(self):
        for answers, expected in ((["n"], False), (["y", "wrong"], False),
                                  (["yes", "patrol_recorder@1.2.3"], True)):
            with self.subTest(answers=answers), patch("builtins.input", side_effect=answers):
                self.assertEqual(publish.confirmed_upload("patrol_recorder", "1.2.3"), expected)

    def test_hosted_404_is_absent_but_other_http_errors_fail(self):
        for code in (404, 403, 500):
            error = urllib.error.HTTPError("https://pub.dev", code, "error", {}, None)
            with self.subTest(code=code), patch.object(publish.urllib.request, "urlopen", side_effect=error):
                if code == 404:
                    self.assertFalse(publish.hosted_version_exists("patrol_recorder", "1.2.3"))
                else:
                    with self.assertRaises(RuntimeError):
                        publish.hosted_version_exists("patrol_recorder", "1.2.3")

    def test_dry_run_never_uploads(self):
        with patch.object(sys, "argv", ["publish_packages.py", "--dry-run-only"]), \
                patch.object(publish, "clean_worktree", return_value=True), \
                patch.object(publish, "changelog_is_ready", return_value=True), \
                patch.object(publish, "hosted_version_exists", return_value=False), \
                patch.object(publish.subprocess, "run") as run, \
                patch.object(publish, "confirmed_upload") as confirm, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(publish.main(), 0)
        confirm.assert_not_called()
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[-1], ["flutter", "pub", "publish", "--dry-run"])
        self.assertNotIn(["flutter", "pub", "publish"], commands)

    def test_dirty_worktree_stops_before_network_or_validation(self):
        with patch.object(sys, "argv", ["publish_packages.py"]), \
                patch.object(publish, "clean_worktree", return_value=False), \
                patch.object(publish, "hosted_version_exists") as hosted, \
                patch.object(publish.subprocess, "run") as run:
            self.assertEqual(publish.main(), 1)
        hosted.assert_not_called()
        run.assert_not_called()

    def test_ci_requires_tag_context(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false", "GITHUB_REF": ""}), \
                patch.object(release.subprocess, "run") as run, \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(release.main(), 1)
        run.assert_not_called()

    def test_ci_skips_hosted_recorder(self):
        current = publish.read_version(publish.RECORDER_PUBSPEC)
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "GITHUB_REF": f"refs/tags/v{current}"}), \
                patch.object(release, "changelog_is_ready", return_value=True), \
                patch.object(release, "hosted_version_exists", return_value=True), \
                patch.object(release.subprocess, "run") as run, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(release.main(), 0)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
