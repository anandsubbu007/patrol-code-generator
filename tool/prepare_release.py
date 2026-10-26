#!/usr/bin/env python3
"""Prepare a Patrol Recorder version without publishing or committing."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECORDER_PUBSPEC = ROOT / "pubspec.yaml"
VERSION_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def version_tuple(value: str) -> tuple[int, int, int]:
    match = VERSION_RE.fullmatch(value)
    if match is None:
        raise ValueError("Use a stable semantic version in MAJOR.MINOR.PATCH form.")
    return tuple(map(int, match.groups()))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="New stable MAJOR.MINOR.PATCH version")
    parser.add_argument("--apply", action="store_true", help="Write the prepared changes")
    parser.add_argument(
        "--from-ref", action="store_true",
        help="Read vMAJOR.MINOR.PATCH and allow the current version for CI",
    )
    args = parser.parse_args()
    try:
        requested = args.version
        if args.from_ref:
            if not requested.startswith("v"):
                raise ValueError("Release refs must be named vMAJOR.MINOR.PATCH.")
            requested = requested[1:]
        target = version_tuple(requested)
        text = RECORDER_PUBSPEC.read_text()
        pattern = re.compile(r"^version:\s*['\"]?([^'\"\s]+)['\"]?\s*$", re.M)
        matches = list(pattern.finditer(text))
        if len(matches) != 1:
            raise ValueError("Expected exactly one package version.")
        current = matches[0].group(1)
        if target < version_tuple(current) or (requested == current and not args.from_ref):
            raise ValueError(f"{requested} must be greater than {current}.")

        changes = {RECORDER_PUBSPEC: pattern.sub(f"version: {requested}", text, count=1)}
        changelog = ROOT / "CHANGELOG.md"
        notes = changelog.read_text()
        if not re.search(rf"(?m)^## {re.escape(requested)}(?:\s.*)?$", notes):
            notes = f"## {requested}\n\n- TODO: Describe the changes in this release.\n\n{notes}"
        changes[changelog] = notes
        for path, updated in changes.items():
            if updated != path.read_text():
                print(f"{'Updating' if args.apply else 'Would update'} {path.relative_to(ROOT)}")
                if args.apply:
                    path.write_text(updated)
        if not args.apply:
            print("Preview only; pass --apply to write changes.")
        return 0
    except (OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
