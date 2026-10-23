# Contributing

Patrol Recorder is experimental and the complete recording/replay workflow has
been validated on Flutter Web only. Please report reproducible defects and
limits rather than assuming support from Flutter or Patrol's platform coverage.

## Requirements

- Flutter 3.47.7 / Dart 3.13.5 is the pinned project toolchain. Package
  and example constraints allow Flutter >=3.32.0 / Dart >=3.8.0 <4.0.0,
  including Dart 3.11. Building the extension from source requires
  Flutter >=3.35.0 / Dart >=3.9.0 <4.0.0; consumers use bundled assets.
  Keep the minimum-SDK and Dart 3.11 checks passing, including generator
  dependency downgrades. The recorded full Web workflow still uses 3.47.7.
- Node.js is used by Patrol's web test tooling. Node 22.23.4 completed the
  recorded clean web setup. An earlier clean Playwright browser installation
  stalled under Node 26.12.0; a cached replay on that host is not clean-setup
  evidence. This repository does not define a Node minimum.
- A Chrome-compatible browser is needed for the Patrol Web replay.

The source example intentionally uses local path dependencies and a local
generator override. It is not a clean hosted consumer test. For the planned
0.0.6 release, publish the recorder before the generator, then verify both
package pages before running the full hosted consumer workflow without path
overrides. Never present a local-path replay as hosted-package validation.

## Set up the repository

From the repository root:

```sh
flutter pub get
cd tool/patrol_recorder_generator
flutter pub get
cd ../devtools_extension
flutter pub get
cd ../../example
flutter pub get
cd ..
```

## Prepare a coordinated package version

For automatic releases from a pushed `vMAJOR.MINOR.PATCH` tag or branch, use
the [automated release guide](doc/PUBLISHING.md#automated-releases-from-a-version-tag-or-branch).
It explains the required pub.dev OIDC setup, the optional branch-to-tag token,
automatic version synchronization, validation, and partial-release recovery.
The commands below remain available for manual preparation and publication.

The release helper updates both package versions, adjusts the generator's
recorder constraint and matching documentation ranges, and adds changelog
placeholders. It does not publish or commit. Run a preview first:

```sh
python3 tool/prepare_release.py 0.0.7
python3 tool/prepare_release.py 0.0.7 --apply
```

The helper accepts stable `MAJOR.MINOR.PATCH` versions greater than the current
package version. Its generated dependency range permits later compatible
patches within the current 0.x minor series, while excluding the next minor
release (or, once the package reaches 1.x, the next major). Review and complete
every printed TODO before a release. Publish the recorder first; only proceed
with the generator after confirming the recorder version is hosted.

To run the interactive release workflow:

```sh
python3 tool/publish_packages.py
```

The script's questions and stopping points are described in the
[release-process guide](doc/PUBLISHING.md#interactive-release-script).
In brief, the version-bump prompt defaults to **No**. If you enter a different
version, the script updates both manifests and the compatible recorder range,
adds changelog TODOs, then exits without publishing; complete the release notes,
run checks, commit the reviewed changes, and rerun it. With no bump, it requires
a clean worktree, checks hosted availability and skips an already-hosted
recorder, runs
recorder analysis/tests and an archive dry-run, and requests a typed confirmation
before each upload. It resolves and validates the generator from a temporary
copy without the local override, and only proceeds after the recorder version
is visible on pub.dev. `--dry-run-only` skips upload prompts but still requires
the recorder version to be hosted for generator dependency resolution.

## Format, analyze, and test

Run formatting checks and package tests from the repository root:

```sh
dart format --language-version=latest --output=none --set-exit-if-changed \
  lib test \
  tool/patrol_recorder_generator/lib tool/patrol_recorder_generator/bin tool/patrol_recorder_generator/test \
  tool/devtools_extension/lib tool/devtools_extension/test tool/devtools_extension/tool \
  example/lib example/test example/patrol_test

flutter analyze lib test
flutter test

cd tool/patrol_recorder_generator
flutter analyze
flutter test
dart run patrol_recorder_generator:generate --help

cd ../devtools_extension
flutter analyze
flutter test
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..

cd ../../example
flutter analyze
flutter test
```

These checks cover the recorder package, generator CLI, DevTools extension, and
example widgets. They do not prove a live recording session or Patrol replay.
Run repository formatting with the pinned release SDK and
`--language-version=latest` to keep one formatting style independent of each
package's older SDK floor. CI also runs package checks on Flutter 3.32.0 /
Dart 3.8.0 and Flutter 3.41.0 / Dart 3.11.0. The minimum job downgrades only
`analyzer` and `dart_style`; globally downgrading transitive dependencies can
select old packages whose published SDK ranges incorrectly admit newer SDKs.

## Validate the example end to end

From `example/`, after installing a compatible Patrol CLI and Node.js:

```sh
dart run patrol_recorder_generator:generate --journey m2_fixtures
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/populated/populated_test.dart --device chrome --web-headless
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/empty/empty_test.dart --device chrome --web-headless
```

The checked-in example uses local dependencies. For release validation, also
create a clean consumer app with hosted dependencies and no `path` entries or
`dependency_overrides`, then follow the recording, stop, generation,
user-owned-input, assertion, replay, and regeneration steps in the root README.
Until the 0.0.6 packages are published, hosted validation is expected to fail
and must not be represented as a passing release check.

## Submit a bug report or pull request

- File bugs and feature requests in the
  [GitHub issue tracker](https://github.com/anandsubbu007/patrol-code-generator/issues).
- Include Flutter/Dart, DevTools, Patrol, browser and Node versions, exact
  commands, sanitized YAML, expected/actual behavior, and the relevant output.
- Never attach credentials, private screenshots, application data, or
  authenticated VM Service/DTD URLs.
- Keep changes focused. Add regression coverage for confirmed defects and
  update the directly related documentation.
- Before opening a pull request, run the applicable checks above and describe
  which commands passed. Do not publish packages or make release claims from a
  local-path validation.
