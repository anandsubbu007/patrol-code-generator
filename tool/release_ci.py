#!/usr/bin/env python3
"""Publish the coordinated packages in a tag-triggered GitHub Actions run."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from prepare_release import version_tuple
from publish_packages import (
    GENERATOR_NAME,
    GENERATOR_PUBSPEC,
    RECORDER_NAME,
    RECORDER_PUBSPEC,
    ROOT,
    changelog_is_ready,
    generator_test_environment,
    hosted_version_exists,
    hosted_version_is_resolvable,
    read_version,
    stage_generator,
)


def run(*command: str, cwd: Path = ROOT, env: dict[str, str] | None = None) -> None:
    print(f"$ {' '.join(command)}", flush=True)
    subprocess.run(command, cwd=cwd, env=env, check=True)


def wait_for_hosted(package: str, version: str) -> None:
    for attempt in range(61):
        if hosted_version_exists(package, version) and hosted_version_is_resolvable(package, version):
            return
        if attempt < 60:
            time.sleep(10)
    raise RuntimeError(
        f"{package} {version} is not visible on pub.dev after upload. "
        "Check its package page before rerunning the workflow."
    )


def main() -> int:
    try:
        ref = os.environ.get("GITHUB_REF", "")
        if os.environ.get("GITHUB_ACTIONS") != "true" or not ref.startswith("refs/tags/v"):
            raise ValueError("Automatic publishing is allowed only in a GitHub Actions vX.Y.Z tag run.")
        version = ref.removeprefix("refs/tags/v")
        version_tuple(version)
        for manifest in (RECORDER_PUBSPEC, GENERATOR_PUBSPEC):
            if read_version(manifest) != version:
                raise ValueError(f"{manifest} does not match tag version {version}.")
            if not changelog_is_ready(manifest.parent / "CHANGELOG.md", version):
                raise ValueError(f"Complete the {version} changelog in {manifest.parent}.")

        for package, manifest in (
            (RECORDER_NAME, RECORDER_PUBSPEC),
            (GENERATOR_NAME, GENERATOR_PUBSPEC),
        ):
            if hosted_version_exists(package, version):
                print(f"{package} {version} is already hosted; skipping immutable upload.")
                continue
            if package == RECORDER_NAME:
                run("flutter", "pub", "publish", "--dry-run")
                run("flutter", "pub", "publish", "--force")
            else:
                wait_for_hosted(RECORDER_NAME, version)
                with tempfile.TemporaryDirectory(prefix="patrol-generator-release-") as temporary:
                    staged = Path(temporary)
                    stage_generator(staged)
                    run("flutter", "pub", "get", cwd=staged)
                    run("flutter", "analyze", cwd=staged)
                    run("flutter", "test", cwd=staged, env=generator_test_environment())
                    run("flutter", "pub", "publish", "--dry-run", cwd=staged)
                    run("flutter", "pub", "publish", "--force", cwd=staged)
            wait_for_hosted(package, version)
        print(f"Both {version} packages are hosted. Hosted consumer replay is still required.")
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Release failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
