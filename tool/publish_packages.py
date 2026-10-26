#!/usr/bin/env python3
"""Validate and interactively publish the Patrol Recorder package."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECORDER_PUBSPEC = ROOT / "pubspec.yaml"
RECORDER_NAME = "patrol_recorder"


def read_version(path: Path) -> str:
    matches = re.findall(r"^version:\s*['\"]?([^'\"\s]+)['\"]?\s*$", path.read_text(), re.M)
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one package version in {path}.")
    return matches[0]


def changelog_is_ready(path: Path, version: str) -> bool:
    text = path.read_text()
    heading = re.search(rf"(?m)^## {re.escape(version)}(?:\s.*)?$", text)
    if heading is None:
        return False
    section = re.split(r"(?m)^## ", text[heading.end():], maxsplit=1)[0].strip()
    return bool(section) and "TODO:" not in section


def hosted_version_exists(package: str, version: str) -> bool:
    request = urllib.request.Request(
        f"https://pub.dev/api/packages/{package}/versions/{version}",
        headers={"User-Agent": "patrol-release-helper"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20):
            return True
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise RuntimeError(f"Pub.dev version check failed: HTTP {error.code}") from error
    except OSError as error:
        raise RuntimeError(f"Could not check pub.dev: {error}") from error


def clean_worktree() -> bool:
    result = subprocess.run(
        ["git", "status", "--porcelain"], cwd=ROOT, check=True,
        capture_output=True, text=True,
    )
    if result.stdout.strip():
        print("Refusing to publish from a dirty worktree.", file=sys.stderr)
        return False
    return True


def confirmed_upload(package: str, version: str) -> bool:
    if input(f"Publish {package} {version}? [y/N] ").strip().lower() not in ("y", "yes"):
        return False
    expected = f"{package}@{version}"
    return input(f"Type {expected} to authorize upload: ").strip() == expected


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run-only", action="store_true", help="Validate without uploading")
    args = parser.parse_args()
    try:
        from prepare_release import version_tuple

        version = read_version(RECORDER_PUBSPEC)
        version_tuple(version)
        if not clean_worktree():
            return 1
        if not changelog_is_ready(ROOT / "CHANGELOG.md", version):
            raise ValueError(f"Complete the {version} changelog before publishing.")
        if hosted_version_exists(RECORDER_NAME, version):
            raise ValueError(f"{RECORDER_NAME} {version} is already hosted; choose a higher version.")
        for command in (
            ["flutter", "pub", "get"],
            ["flutter", "analyze", "lib", "test"],
            ["flutter", "test"],
            ["flutter", "pub", "publish", "--dry-run"],
        ):
            subprocess.run(command, cwd=ROOT, check=True)
        if args.dry_run_only:
            print("Recorder archive validated. No package was published.")
            return 0
        if not confirmed_upload(RECORDER_NAME, version):
            print("Upload not authorized. Nothing was published.")
            return 0
        subprocess.run(["flutter", "pub", "publish"], cwd=ROOT, check=True)
        print("Upload completed. Verify the hosted package in a clean consumer app.")
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
