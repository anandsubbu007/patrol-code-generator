#!/usr/bin/env python3
"""Prepare coordinated Patrol Recorder package versions without publishing."""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECORDER_PUBSPEC = ROOT / "pubspec.yaml"
GENERATOR_PUBSPEC = ROOT / "tool/patrol_recorder_generator/pubspec.yaml"
CHANGELOGS = (
    ROOT / "CHANGELOG.md",
    ROOT / "tool/patrol_recorder_generator/CHANGELOG.md",
)
DOCS = (
    ROOT / "README.md",
    ROOT / "tool/patrol_recorder_generator/README.md",
    ROOT / "doc/PUBLISHING.md",
)
VERSION_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def version_tuple(value: str) -> tuple[int, int, int]:
    match = VERSION_RE.fullmatch(value)
    if match is None:
        raise ValueError("Use a stable semantic version in MAJOR.MINOR.PATCH form.")
    return tuple(map(int, match.groups()))


def upper_bound(version: tuple[int, int, int]) -> str:
    major, minor, _ = version
    if major == 0:
        return f"0.{minor + 1}.0"
    return f"{major + 1}.0.0"


def read_version(path: Path) -> tuple[str, str]:
    text = path.read_text()
    matches = list(re.finditer(r"^version:\s*['\"]?([^'\"\s]+)['\"]?\s*$", text, re.M))
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one package version in {path.relative_to(ROOT)}.")
    return text, matches[0].group(1)


def write_atomically(path: Path, text: str) -> None:
    mode = path.stat().st_mode
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        delete=False,
    ) as temporary:
        temporary.write(text)
        temporary_path = Path(temporary.name)
    os.chmod(temporary_path, mode)
    os.replace(temporary_path, path)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare a coordinated recorder and generator release. "
            "This never publishes or commits."
        )
    )
    parser.add_argument("version", help="New stable MAJOR.MINOR.PATCH version")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write the version, dependency range, and changelog placeholders",
    )
    args = parser.parse_args()

    try:
        requested = version_tuple(args.version)
        recorder_text, recorder_current = read_version(RECORDER_PUBSPEC)
        generator_text, generator_current = read_version(GENERATOR_PUBSPEC)
        current = version_tuple(recorder_current)

        if recorder_current != generator_current:
            raise ValueError(
                "Recorder and generator versions differ; reconcile them before preparing a release."
            )
        if requested <= current:
            raise ValueError(
                f"{args.version} must be greater than the current package version {recorder_current}."
            )

        old_range = (
            f"'>={recorder_current} <{upper_bound(current)}'"
        )
        new_range = f"'>={args.version} <{upper_bound(requested)}'"
        if generator_text.count(old_range) != 1:
            raise ValueError(
                "The generator manifest dependency range does not match the current package version."
            )

        changes: dict[Path, str] = {}
        changes[RECORDER_PUBSPEC] = re.sub(
            rf"(?m)^version:\s*{re.escape(recorder_current)}\s*$",
            f"version: {args.version}",
            recorder_text,
            count=1,
        )
        generator_text = re.sub(
            rf"(?m)^version:\s*{re.escape(generator_current)}\s*$",
            f"version: {args.version}",
            generator_text,
            count=1,
        )
        changes[GENERATOR_PUBSPEC] = generator_text.replace(old_range, new_range, 1)

        for path in DOCS:
            text = path.read_text()
            if old_range in text:
                changes[path] = text.replace(old_range, new_range)

        for path in CHANGELOGS:
            text = path.read_text()
            if re.search(rf"(?m)^## {re.escape(args.version)}(?:\s|$)", text):
                raise ValueError(
                    f"{args.version} already has a changelog heading in {path.relative_to(ROOT)}."
                )
            changes[path] = (
                f"## {args.version} (release candidate)\n\n"
                "- TODO: Describe the changes included in this release.\n\n"
                + text
            )
    except (OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2

    action = "Would update" if not args.apply else "Updated"
    for path, text in changes.items():
        print(f"{action}: {path.relative_to(ROOT)}")
        if args.apply:
            write_atomically(path, text)

    print(
        f"\nRelease TODO for {args.version}\n"
        "1. Replace both changelog TODO placeholders with accurate release notes.\n"
        "2. Update README publication/install status and the current release section in doc/PUBLISHING.md.\n"
        "3. Review package metadata, platform claims, screenshots, archive contents, and third-party notices.\n"
        "4. Run formatting, analysis, tests, extension validation, and example Patrol Web replays.\n"
        "5. For hosted validation, remove local path overrides in a staged/temporary consumer; do not call a local-path test hosted proof.\n"
        "6. Commit the reviewed changes, rerun both package publish dry-runs from clean release staging, and resolve all warnings.\n"
        "7. Publish the recorder first. Confirm its hosted version, then validate and publish the generator.\n"
        "8. Run the complete clean hosted consumer workflow and update release status only after verification.\n"
        "No commit, tag, release, or upload was performed."
    )
    if not args.apply:
        print("\nNo files changed. Re-run with --apply to write the changes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
