"""Release automation regressions; never contact pub.dev or upload packages."""

import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import publish_packages
import release_ci


class VersionPreparationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "tool/patrol_recorder_generator").mkdir(parents=True)
        (self.root / "doc").mkdir()
        shutil.copy2(
            Path(__file__).resolve().parents[1] / "prepare_release.py",
            self.root / "tool/prepare_release.py",
        )
        (self.root / "pubspec.yaml").write_text("name: patrol_recorder\nversion: 0.0.4\n")
        (self.root / "tool/patrol_recorder_generator/pubspec.yaml").write_text(
            "name: patrol_recorder_generator\nversion: 0.0.4\n"
            "dependencies:\n  patrol_recorder: '>=0.0.4 <0.1.0'\n"
        )
        for name in ("README.md", "tool/patrol_recorder_generator/README.md", "doc/PUBLISHING.md"):
            (self.root / name).write_text("Release 0.0.4 uses '>=0.0.4 <0.1.0'.\n")
        (self.root / "CONTRIBUTING.md").write_text("Preparing 0.0.4.\n")
        for name in ("CHANGELOG.md", "tool/patrol_recorder_generator/CHANGELOG.md"):
            (self.root / name).write_text("## 0.0.4\n\n- Existing release.\n")

    def prepare(self, ref):
        return subprocess.run(
            [sys.executable, "tool/prepare_release.py", ref, "--from-ref", "--apply"],
            cwd=self.root, capture_output=True, text=True, check=False,
        )

    def test_bump_updates_packages_ranges_and_current_docs(self):
        result = self.prepare("v0.1.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ("pubspec.yaml", "tool/patrol_recorder_generator/pubspec.yaml"):
            self.assertIn("version: 0.1.0", (self.root / name).read_text())
        self.assertIn("'>=0.1.0 <0.2.0'", (self.root / "README.md").read_text())
        self.assertIn("0.1.0", (self.root / "CONTRIBUTING.md").read_text())
        changelog = (self.root / "CHANGELOG.md").read_text()
        self.assertTrue(changelog.startswith("## 0.1.0\n"))
        self.assertIn("## 0.0.4\n\n- Existing release.", changelog)
        self.assertNotIn("TODO:", changelog)

    def test_same_version_is_idempotent(self):
        for _ in range(2):
            result = self.prepare("v0.0.4")
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "CHANGELOG.md").read_text().count("## 0.0.4"), 1)

    def test_unreleased_notes_are_promoted(self):
        changelog = self.root / "CHANGELOG.md"
        changelog.write_text("## Unreleased\n\n- Fix a real bug.\n\n## 0.0.4\n\n- Old.\n")
        self.assertEqual(self.prepare("v0.0.5").returncode, 0)
        self.assertTrue(changelog.read_text().startswith("## 0.0.5\n\n- Fix a real bug."))

    def test_upper_bound_prose_and_history_are_consistent(self):
        document = self.root / "doc/PUBLISHING.md"
        document.write_text(
            "Release 0.0.4. Excludes 0.1.0.\n"
            "<!-- publication-history:start -->\n"
            "Published 0.0.4.\n"
            "<!-- publication-history:end -->\n"
        )
        self.assertEqual(self.prepare("v0.1.0").returncode, 0)
        self.assertIn("Release 0.1.0. Excludes 0.2.0.", document.read_text())
        self.assertIn("Published 0.0.4.", document.read_text())

    def test_invalid_or_lower_ref_does_not_write(self):
        original = (self.root / "pubspec.yaml").read_text()
        for ref in ("0.0.5", "v0.0.3", "v01.0.0", "v1.2.3-extra", "v1.2.3/invalid"):
            with self.subTest(ref=ref):
                self.assertNotEqual(self.prepare(ref).returncode, 0)
                self.assertEqual((self.root / "pubspec.yaml").read_text(), original)


class PublicationTest(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
        self.stack.enter_context(patch.dict(os.environ, {
            "GITHUB_ACTIONS": "true", "GITHUB_REF": "refs/tags/v0.0.4",
        }))
        self.stack.enter_context(patch.object(release_ci, "read_version", return_value="0.0.4"))
        self.stack.enter_context(patch.object(release_ci, "changelog_is_ready", return_value=True))
        self.commands = self.stack.enter_context(patch.object(release_ci, "run"))
        self.stage = self.stack.enter_context(patch.object(release_ci, "stage_generator"))
        self.resolve = self.stack.enter_context(
            patch.object(release_ci, "resolve_generator_dependencies")
        )
        self.wait = self.stack.enter_context(patch.object(release_ci, "wait_for_hosted"))
        self.hosted = self.stack.enter_context(
            patch.object(release_ci, "hosted_version_exists", return_value=False)
        )

    def test_recorder_precedes_generator_with_independent_dry_runs(self):
        self.assertEqual(release_ci.main(), 0)
        commands = [call.args for call in self.commands.call_args_list]
        uploads = [i for i, command in enumerate(commands) if command == (
            "flutter", "pub", "publish", "--force",
        )]
        self.assertEqual(len(uploads), 2)
        self.assertEqual(commands[uploads[0] - 1], ("flutter", "pub", "publish", "--dry-run"))
        self.resolve.assert_called_once_with(self.stage.call_args.args[0], "0.0.4")
        self.assertIn(("flutter", "analyze"), commands[uploads[0] + 1:uploads[1]])
        self.assertEqual(commands[uploads[1] - 1], ("flutter", "pub", "publish", "--dry-run"))
        self.stage.assert_called_once()

    def test_partial_release_skips_recorder_upload(self):
        self.hosted.side_effect = lambda package, version: package == "patrol_recorder"
        self.assertEqual(release_ci.main(), 0)
        uploads = [call for call in self.commands.call_args_list if "--force" in call.args]
        self.assertEqual(len(uploads), 1)
        self.assertIn("cwd", uploads[0].kwargs)
        self.resolve.assert_called_once()

    def test_completed_release_is_noop(self):
        self.hosted.return_value = True
        self.assertEqual(release_ci.main(), 0)
        self.commands.assert_not_called()
        self.resolve.assert_not_called()

    def test_failed_resolution_stops_generator_validation_and_upload(self):
        self.resolve.side_effect = RuntimeError("Recorder not resolvable")
        self.assertEqual(release_ci.main(), 1)
        self.assertEqual(
            [call.args for call in self.commands.call_args_list],
            [
                ("flutter", "pub", "publish", "--dry-run"),
                ("flutter", "pub", "publish", "--force"),
            ],
        )

    def test_failed_dry_run_never_uploads(self):
        self.commands.side_effect = subprocess.CalledProcessError(1, "flutter")
        self.assertEqual(release_ci.main(), 1)
        self.assertEqual(self.commands.call_count, 1)
        self.stage.assert_not_called()

    def test_branch_cannot_publish(self):
        with patch.dict(os.environ, {"GITHUB_REF": "refs/heads/v0.0.4"}):
            self.assertEqual(release_ci.main(), 1)
        self.commands.assert_not_called()

    def test_manifest_mismatch_blocks_upload(self):
        with patch.object(release_ci, "read_version", return_value="0.0.3"):
            self.assertEqual(release_ci.main(), 1)
        self.commands.assert_not_called()


class PropagationTest(unittest.TestCase):
    def test_interactive_wait_checks_dependency_index_after_exact_version(self):
        with (
            patch.object(publish_packages, "hosted_version_exists", return_value=True),
            patch.object(
                publish_packages, "hosted_version_is_resolvable", side_effect=[False, True]
            ),
            patch.object(publish_packages.time, "sleep") as sleep,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertTrue(publish_packages.wait_until_hosted("patrol_recorder", "0.0.4"))
        sleep.assert_called_once_with(10)

    def test_interactive_resume_does_not_dry_run_published_recorder(self):
        with (
            patch.object(sys, "argv", ["publish_packages.py"]),
            patch.object(publish_packages, "prepare_version_if_requested", return_value=("0.0.4", True)),
            patch.object(publish_packages, "read_version", return_value="0.0.4"),
            patch.object(publish_packages, "clean_worktree", return_value=True),
            patch.object(publish_packages, "changelog_is_ready", return_value=True),
            patch.object(
                publish_packages, "hosted_version_exists",
                side_effect=lambda package, version: package == "patrol_recorder",
            ),
            patch.object(publish_packages, "wait_until_hosted", return_value=True),
            patch.object(publish_packages, "run", return_value=True) as commands,
            patch.object(publish_packages, "resolve_generator_dependencies") as resolve,
            patch.object(publish_packages, "confirmed_upload", return_value=False),
            patch.object(publish_packages, "stage_generator"),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(publish_packages.main(), 0)
        root_dry_runs = [
            call for call in commands.call_args_list
            if "--dry-run" in call.args[0] and call.kwargs["cwd"] == publish_packages.ROOT
        ]
        self.assertEqual(root_dry_runs, [])
        resolve.assert_called_once()
        self.assertTrue(any("--dry-run" in call.args[0] for call in commands.call_args_list))

    def test_version_endpoint_alone_is_not_resolution_readiness(self):
        with (
            patch.object(release_ci, "hosted_version_exists", return_value=True),
            patch.object(release_ci, "hosted_version_is_resolvable", side_effect=[False, True]),
            patch.object(release_ci.time, "sleep") as sleep,
        ):
            release_ci.wait_for_hosted("patrol_recorder", "0.0.4")
        sleep.assert_called_once_with(10)

    def test_package_index_must_include_exact_version(self):
        for versions, expected in ((["0.0.3"], False), (["0.0.3", "0.0.4"], True)):
            response = io.StringIO(json.dumps({"versions": [{"version": v} for v in versions]}))
            with patch.object(publish_packages.urllib.request, "urlopen", return_value=response):
                self.assertEqual(
                    publish_packages.hosted_version_is_resolvable("patrol_recorder", "0.0.4"),
                    expected,
                )

    def test_generator_staging_excludes_local_overrides(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            publish_packages.stage_generator(destination)
            self.assertTrue((destination / "pubspec.yaml").is_file())
            self.assertTrue((destination / "bin").is_dir())
            self.assertFalse((destination / "pubspec_overrides.yaml").exists())
            self.assertFalse((destination / ".dart_tool").exists())


class HostedResolutionTest(unittest.TestCase):
    missing_recorder = (
        "Because patrol_recorder_generator depends on patrol_recorder\n"
        "  ^0.0.6 which doesn't match any versions, version solving failed.\n"
    )

    def setUp(self):
        stack = contextlib.ExitStack()
        self.addCleanup(stack.close)
        self.output = stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.run = stack.enter_context(patch.object(publish_packages.subprocess, "run"))
        self.sleep = stack.enter_context(patch.object(publish_packages.time, "sleep"))
        self.cwd = Path("/staged-generator")

    def result(self, code=0, output="Got dependencies!\n"):
        return subprocess.CompletedProcess(["flutter", "pub", "get"], code, output)

    def test_success_requires_no_retry_and_uses_staged_hosted_manifest(self):
        self.run.return_value = self.result()
        publish_packages.resolve_generator_dependencies(self.cwd, "0.0.6")
        self.run.assert_called_once_with(
            ["flutter", "pub", "get"], cwd=self.cwd, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, check=False,
        )
        self.sleep.assert_not_called()

    def test_missing_recorder_retries_until_flutter_resolves_it(self):
        self.run.side_effect = [
            self.result(1, self.missing_recorder),
            self.result(1, self.missing_recorder.replace("^0.0.6", ">=0.0.6 <0.1.0")),
            self.result(),
        ]
        publish_packages.resolve_generator_dependencies(self.cwd, "0.0.6")
        self.assertEqual(self.run.call_count, 3)
        self.assertEqual(self.sleep.call_count, 2)
        self.sleep.assert_called_with(10)
        self.assertIn(self.missing_recorder, self.output.getvalue())
        self.assertIn("retrying in 10 seconds", self.output.getvalue())

    def test_unrelated_failures_stop_without_retry(self):
        for output in (
            self.missing_recorder.replace("depends on patrol_recorder\n", "depends on analyzer\n"),
            "The current Dart SDK version is incompatible.\n",
            "Connection failed while resolving dependencies.\n",
        ):
            with self.subTest(output=output):
                self.run.return_value = self.result(1, output)
                with self.assertRaisesRegex(RuntimeError, "not a recorder propagation error"):
                    publish_packages.resolve_generator_dependencies(self.cwd, "0.0.6")
        self.assertEqual(self.run.call_count, 3)
        self.sleep.assert_not_called()

    def test_missing_recorder_times_out_without_hiding_failure(self):
        self.run.return_value = self.result(1, self.missing_recorder)
        with self.assertRaisesRegex(RuntimeError, "No generator was published"):
            publish_packages.resolve_generator_dependencies(self.cwd, "0.0.6")
        self.assertEqual(self.run.call_count, 61)
        self.assertEqual(self.sleep.call_count, 60)
        self.assertEqual(sum(call.args[0] for call in self.sleep.call_args_list), 600)

    def test_resolution_can_succeed_on_last_attempt(self):
        self.run.side_effect = [self.result(1, self.missing_recorder)] * 60 + [self.result()]
        publish_packages.resolve_generator_dependencies(self.cwd, "0.0.6")
        self.assertEqual(self.run.call_count, 61)
        self.assertEqual(self.sleep.call_count, 60)


if __name__ == "__main__":
    unittest.main()
