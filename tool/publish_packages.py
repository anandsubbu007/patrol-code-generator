#!/usr/bin/env python3
"""Interactively prepare and publish the recorder, then its generator."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GENERATOR = ROOT / "tool/patrol_recorder_generator"
RECORDER_PUBSPEC = ROOT / "pubspec.yaml"
GENERATOR_PUBSPEC = GENERATOR / "pubspec.yaml"
GENERATOR_ARCHIVE_FILES = (
    "bin",
    "lib",
    "test",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "pubspec.yaml",
    "analysis_options.yaml",
    ".pubignore",
)
VERSION_RE = re.compile(r"^version:\s*['\"]?([^'\"\s]+)['\"]?\s*$", re.M)
RECORDER_NAME = "patrol_recorder"
GENERATOR_NAME = "patrol_recorder_generator"


def read_version(path: Path) -> str:
    matches = VERSION_RE.findall(path.read_text())
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one version field in {path.relative_to(ROOT)}.")
    return matches[0]


def ask_yes_no(question: str) -> bool:
    while True:
        answer = input(f"{question} [y/N] ").strip().lower()
        if answer in ("", "n", "no"):
            return False
        if answer in ("y", "yes"):
            return True
        print("Please answer y or n.")


def confirmed_upload(package: str, version: str) -> bool:
    if not ask_yes_no(f"Publish {package} {version} now?"):
        return False
    expected = f"{package}@{version}"
    return input(f"Type {expected} to authorize the upload: ").strip() == expected


def hosted_version_exists(package: str, version: str) -> bool:
    url = f"https://pub.dev/api/packages/{package}/versions/{version}"
    request = urllib.request.Request(url, headers={"User-Agent": "patrol-release-helper"})
    try:
        with urllib.request.urlopen(request, timeout=20):
            return True
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise RuntimeError(f"Pub.dev version check failed for {package}: HTTP {error.code}") from error
    except OSError as error:
        raise RuntimeError(f"Could not check pub.dev for {package}: {error}") from error


def hosted_version_is_resolvable(package: str, version: str) -> bool:
    request = urllib.request.Request(
        f"https://pub.dev/api/packages/{package}",
        headers={
            "User-Agent": "patrol-release-helper",
            "Cache-Control": "no-cache",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            metadata = json.load(response)
        versions = metadata["versions"]
        if not isinstance(versions, list):
            raise ValueError("Expected a versions list.")
        return any(entry["version"] == version for entry in versions)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise RuntimeError(f"Pub.dev package index check failed: HTTP {error.code}") from error
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise RuntimeError(f"Could not read pub.dev package index for {package}: {error}") from error


def wait_until_hosted(package: str, version: str) -> bool:
    for attempt in range(61):
        if hosted_version_exists(package, version) and hosted_version_is_resolvable(package, version):
            print(f"Confirmed on pub.dev: {package} {version}")
            return True
        if attempt < 60:
            print(f"Waiting for {package} {version} in pub.dev's dependency-resolution index...")
            time.sleep(10)
    while ask_yes_no(f"{package} {version} is not visible yet. Retry the pub.dev check?"):
        if hosted_version_exists(package, version) and hosted_version_is_resolvable(package, version):
            print(f"Confirmed on pub.dev: {package} {version}")
            return True
    return False


def run(command: list[str], *, cwd: Path, env: dict[str, str] | None = None) -> bool:
    print(f"\n$ {' '.join(command)}")
    return subprocess.run(command, cwd=cwd, env=env, check=False).returncode == 0


def resolve_generator_dependencies(cwd: Path, version: str) -> None:
    for attempt in range(61):
        print("\n$ flutter pub get", flush=True)
        result = subprocess.run(
            ["flutter", "pub", "get"],
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        print(result.stdout, end="", flush=True)
        if result.returncode == 0:
            return
        output = " ".join(result.stdout.split())
        if not re.search(
            r"Because patrol_recorder_generator depends on patrol_recorder "
            r".+? which doesn't match any versions[,.]",
            output,
        ):
            raise RuntimeError(
                f"Staged generator dependency resolution failed (exit {result.returncode}); "
                "this is not a recorder propagation error. No generator was published."
            )
        if attempt < 60:
            print(
                f"Waiting for Flutter to resolve hosted {RECORDER_NAME} {version} "
                f"(attempt {attempt + 1}/61); retrying in 10 seconds...",
                flush=True,
            )
            time.sleep(10)
    raise RuntimeError(
        f"Flutter still cannot resolve hosted {RECORDER_NAME} {version} after "
        "ten minutes of retries. No generator was published. Check pub.dev and "
        "rerun the release; do not re-upload the recorder or downgrade its constraint."
    )


def generator_test_environment() -> dict[str, str]:
    return {
        **os.environ,
        "PATROL_RECORDER_TEST_EXAMPLE": str(ROOT / "example"),
    }


def changelog_is_ready(path: Path, version: str) -> bool:
    text = path.read_text()
    heading = re.search(rf"(?m)^## {re.escape(version)}(?:\s.*)?$", text)
    if heading is None:
        return False
    next_heading = re.search(r"(?m)^## ", text[heading.end() :])
    end = heading.end() + next_heading.start() if next_heading else len(text)
    section = text[heading.end() : end]
    return "TODO:" not in section


def prepare_version_if_requested(current: str) -> tuple[str, bool]:
    if not ask_yes_no(f"Increment both package versions? Current version is {current}."):
        return current, True

    requested = input(f"New version (stable MAJOR.MINOR.PATCH; current {current}): ").strip()
    if not requested or requested == current:
        print("No version change selected.")
        return current, True

    result = subprocess.run(
        [sys.executable, str(ROOT / "tool/prepare_release.py"), requested, "--apply"],
        cwd=ROOT,
        check=False,
    )
    if result.returncode != 0:
        return current, False
    print(
        "\nVersion preparation completed. Complete the generated changelog TODOs, "
        "update the release notes/status, run the checks, review and commit the "
        "changes, then rerun this publishing script. No package was published."
    )
    return requested, False


def clean_worktree() -> bool:
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("Error: unable to inspect git worktree.", file=sys.stderr)
        return False
    if result.stdout.strip():
        print(
            "Refusing to publish from a dirty worktree. Review, commit, or discard "
            "the changes, then rerun. This avoids the modified-files warning and "
            "ensures the archive matches the reviewed source.",
            file=sys.stderr,
        )
        return False
    return True


def stage_generator(destination: Path) -> None:
    for name in GENERATOR_ARCHIVE_FILES:
        source = GENERATOR / name
        target = destination / name
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Optionally prepare a version bump, then interactively dry-run and "
            "publish the recorder followed by the generator."
        )
    )
    parser.add_argument(
        "--dry-run-only",
        action="store_true",
        help="Run both package checks without asking to upload",
    )
    args = parser.parse_args()

    try:
        recorder_version = read_version(RECORDER_PUBSPEC)
        generator_version = read_version(GENERATOR_PUBSPEC)
        if recorder_version != generator_version:
            raise ValueError(
                f"Package versions differ: recorder {recorder_version}, generator {generator_version}."
            )

        version, continue_release = prepare_version_if_requested(recorder_version)
        if not continue_release:
            return 0 if version != recorder_version else 1

        if not clean_worktree():
            return 1

        for changelog in (
            ROOT / "CHANGELOG.md",
            GENERATOR / "CHANGELOG.md",
        ):
            if not changelog_is_ready(changelog, version):
                raise ValueError(
                    f"Complete the {version} changelog section before publishing: "
                    f"{changelog.relative_to(ROOT)}"
                )

        recorder_is_hosted = hosted_version_exists(RECORDER_NAME, version)
        if hosted_version_exists(GENERATOR_NAME, version):
            raise ValueError(
                f"{GENERATOR_NAME} {version} already exists on pub.dev. "
                "Choose a higher coordinated version."
            )

        recorder_commands = [
            ["flutter", "analyze", "lib", "test"],
            ["flutter", "test"],
        ]
        if not recorder_is_hosted:
            recorder_commands.append(["flutter", "pub", "publish", "--dry-run"])
        for command in recorder_commands:
            if not run(command, cwd=ROOT):
                print(
                    "Recorder validation failed; no package was published.",
                    file=sys.stderr,
                )
                return 1

        if not args.dry_run_only:
            if recorder_is_hosted:
                print(
                    f"{RECORDER_NAME} {version} is already hosted; "
                    "skipping its upload and continuing with generator validation."
                )
                if not wait_until_hosted(RECORDER_NAME, version):
                    print("Recorder index propagation is incomplete; generator stopped.", file=sys.stderr)
                    return 1
            else:
                if not confirmed_upload(RECORDER_NAME, version):
                    print("Recorder upload not authorized; nothing was published.")
                    return 0
                if not run(["flutter", "pub", "publish"], cwd=ROOT):
                    print("Recorder publication failed; generator was not published.", file=sys.stderr)
                    return 1
                if not wait_until_hosted(RECORDER_NAME, version):
                    print(
                        "Recorder upload may have completed, but its hosted version "
                        "could not be confirmed. Generator publication was stopped.",
                        file=sys.stderr,
                    )
                    return 1

        with tempfile.TemporaryDirectory(prefix="patrol-recorder-generator-release-") as temp:
            staged = Path(temp)
            stage_generator(staged)
            resolve_generator_dependencies(staged, version)
            for command in (
                ["flutter", "analyze"],
                ["flutter", "test"],
                ["flutter", "pub", "publish", "--dry-run"],
            ):
                if not run(command, cwd=staged, env=generator_test_environment()):
                    print(
                        "Staged generator validation failed; generator was not published.",
                        file=sys.stderr,
                    )
                    return 1

            if not args.dry_run_only:
                if not confirmed_upload(GENERATOR_NAME, version):
                    print(
                        "Generator upload not authorized. Recorder publication, "
                        "if completed above, remains published."
                    )
                    return 0
                if not run(["flutter", "pub", "publish"], cwd=staged):
                    print("Generator publication failed.", file=sys.stderr)
                    return 1
                if not wait_until_hosted(GENERATOR_NAME, version):
                    print(
                        "Generator upload may have completed, but its hosted "
                        "version could not be confirmed.",
                        file=sys.stderr,
                    )
                    return 1

        if args.dry_run_only:
            print("\nBoth release archives validated. No package was published.")
        else:
            print(
                "\nBoth package versions are confirmed on pub.dev. "
                "Run the clean hosted consumer workflow next."
            )
        return 0
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
