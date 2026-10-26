#!/usr/bin/env python3
"""Publish Patrol Recorder in a tag-triggered GitHub Actions run."""

from __future__ import annotations

import os
import subprocess
import sys
import time

from prepare_release import version_tuple
from publish_packages import (
    RECORDER_NAME, RECORDER_PUBSPEC, ROOT,
    changelog_is_ready, hosted_version_exists, read_version,
)


def main() -> int:
    try:
        ref = os.environ.get("GITHUB_REF", "")
        if os.environ.get("GITHUB_ACTIONS") != "true" or not ref.startswith("refs/tags/v"):
            raise ValueError("Automatic publishing requires a GitHub Actions vX.Y.Z tag run.")
        version = ref.removeprefix("refs/tags/v")
        version_tuple(version)
        if read_version(RECORDER_PUBSPEC) != version:
            raise ValueError(f"The package version does not match tag {version}.")
        if not changelog_is_ready(ROOT / "CHANGELOG.md", version):
            raise ValueError(f"Complete the {version} changelog before publishing.")
        if hosted_version_exists(RECORDER_NAME, version):
            print(f"{RECORDER_NAME} {version} is already hosted; skipping immutable upload.")
            return 0
        subprocess.run(["flutter", "pub", "publish", "--dry-run"], cwd=ROOT, check=True)
        subprocess.run(["flutter", "pub", "publish", "--force"], cwd=ROOT, check=True)
        for attempt in range(61):
            if hosted_version_exists(RECORDER_NAME, version):
                print(f"{RECORDER_NAME} {version} is hosted. Consumer validation is still required.")
                return 0
            if attempt < 60:
                time.sleep(10)
        raise RuntimeError("Upload may have completed; inspect pub.dev before rerunning.")
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Release failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
