# Publishing Patrol Recorder 0.0.2

The recorder's `0.0.1` release is already published. The next recorder release
is `0.0.2`, which adds declared compatibility with all Flutter platforms.
Preparation evidence below refers to the original `0.0.1` release.

This checklist prepares two packages. It does not authorize an automated upload.
Publishing makes an archive public; treat the released version as permanent.

## Package layout

| Directory | Package | Publish? |
| --- | --- | --- |
| Repository root | Lightweight `patrol_recorder` | First |
| `tool/patrol_recorder_generator` | Development-only generator CLI | Second |
| `tool/devtools_extension` | Extension source app | No; root ships its compiled assets |
| `example` | Demonstration app | No |

The generator is an app dev dependency, separate from the recorder runtime.
Users install both and run `dart run patrol_recorder_generator:generate`.
Patrol remains a separate test-runner dependency for executing generated tests.
The example and extension source app use a path dependency to the root for
development; the published packages have no local path dependencies.
The generator uses a local `pubspec_overrides.yaml` for checkout development,
excluded from its archive. Its published manifest depends on hosted recorder
`^0.0.1`, so the recorder must be published first.

## Required owner decisions

- [ ] Confirm both package names are available and owned by the intended pub.dev account.
  A name lookup is only a point-in-time check, not a reservation.
- [ ] Sign into pub.dev with the intended Google account. Choose a verified
  publisher if desired; it is not mandatory for an individual first release.
- [ ] Confirm repository visibility, issue tracker access, release version, and
  the right to redistribute all code and assets.
- [ ] Keep BSD-3-Clause as approved. Both package roots contain `LICENSE` with
  the existing Patrol Recorder contributors copyright notice.
- [ ] Review bundled third-party notices, especially Flutter/CanvasKit/font
  assets in `extension/devtools/build/assets/NOTICES`. The root license does not
  relicense those assets. Preserve these notices in distributions.
- [ ] Review the README, changelog, screenshots, and demo for accuracy and
  private content. Use only fictional fixture data.

## Build and validate from the repository root

Use the SDK versions and Node 22 documented in the README. Do not lower SDK
constraints solely to improve a compatibility score without testing that SDK.

```sh
flutter pub get
flutter analyze lib test
flutter test

cd tool/patrol_recorder_generator
flutter pub get
flutter analyze
flutter test
dart run patrol_recorder_generator:generate --help

cd ../devtools_extension
flutter pub get
flutter analyze
flutter test
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..

cd ../../example
flutter pub get
flutter analyze
flutter test

cd ..
flutter pub publish --dry-run
```

Also perform a fresh recording -> stopped YAML -> CLI generation -> implemented
inputs -> Patrol replay with an outcome assertion. Follow [the demo](DEMO.md);
widget tests alone do not prove the full DevTools/DTD/browser workflow.

## Inspect the root archive

Read the entire file listing from `flutter pub publish --dry-run`.

- [ ] Includes `README.md`, `CHANGELOG.md`, `LICENSE`, runtime `lib/`, example source,
  documentation images, and every declared screenshot.
- [ ] Includes **both** `extension/devtools/config.yaml` and its nonempty
  `build/` assets (including local CanvasKit and `assets/NOTICES`).
- [ ] No browser profiles, `.dart_tool`, local overrides/lockfiles, generated
  Patrol bundles, build caches, test reports, or authenticated service URLs.
- [ ] Historical planning docs and demo video are excluded; the video stays in
  the repository/release. README images remain in the archive.
- [ ] Keep referenced example screenshots and their ownership markers together
  so the bundled journey examples still pass screenshot-existence validation.
- [ ] Check archive size against pub's current limits and address all errors.

Commit the reviewed release changes yourself before the final dry run. A dirty
worktree warning is expected during preparation; do not suppress it or publish
unknown edits. No preparation script should commit, tag, or upload implicitly.
Until the source moves/deletions are committed, Pub may also report the
deleted old generator paths as "checked-in files ... ignored by a .gitignore".
Review and commit the moves/deletions, then rerun; do not loosen ignore rules
merely to hide a transitional warning.

## Preparation evidence (2026-10-22)

- Split-package validation: recorder analysis clean with 41 passing tests;
  generator analysis clean with 22 passing tests, including CLI regression tests.
- DevTools extension: no analysis issues; 6 workflow tests passed; compiled
  assets rebuilt and `devtools_extensions validate` passed.
- Example: no analysis issues; 8 widget tests passed; the recording-only web
  entrypoint previously built successfully. The extension was rebuilt against
  the split packages and validated successfully.
- A separate consumer with recorder in regular dependencies and generator in
  dev dependencies generated/regenerated successfully and analyzed cleanly.
- A recorder-only widget consumer resolved and analyzed cleanly. Its complete
  resolved package graph contained no generator, analyzer, formatter, YAML, or
  argument parsing packages.
- Four real screenshots and a 17.6-second silent app walkthrough were captured.
  The connected DevTools screenshot is genuine; the video shows app UI only.
- Publish dry run inspected the approximately 15 MB compressed archive. No
  missing screenshots, dependency errors, missing extension assets, or layout
  warnings remained. The repository dry run still exits with warnings for the
  uncommitted release changes/deleted old package paths described above.
- A standalone staged generator archive dry run passed with zero warnings
  (approximately 22 KB). It used a temporary local recorder override because
  the recorder is not yet published; Pub reported that override as a hint.
  Repeat without overrides against the hosted recorder before publishing.

No upload was performed. A fresh complete record -> generate -> Patrol replay
and a post-publication hosted install remain owner release checks; do not
interpret the temporary consumer or app video as proof of those stages.

## Publish explicitly

Only the owner should run these commands after reviewing the dry run:

```sh
# Repository root. This uploads the recorder and can require browser sign-in.
flutter pub publish
```

Wait until `https://pub.dev/packages/patrol_recorder/versions/0.0.1` is available.
Then validate and publish the generator against the hosted recorder.
The root `.pubignore` deliberately excludes `tool/` from the runtime archive.
Pub inherits ancestor ignore rules, so publishing the generator directly from
that nested directory can incorrectly produce an empty archive. Stage only its
release files in a separate temporary directory, without copying local overrides:

```sh
cd tool/patrol_recorder_generator
release_dir="$(mktemp -d "${TMPDIR:-/tmp}/patrol-recorder-generator.XXXXXX")"
cp -R bin lib test README.md CHANGELOG.md LICENSE pubspec.yaml \
  analysis_options.yaml .pubignore "$release_dir/"
cd "$release_dir"
flutter pub get
flutter analyze
flutter test
flutter pub publish --dry-run
# Review every file and warning before this explicit upload:
flutter pub publish
```

Stop if any command fails. Inspect the staged archive for LICENSE, pubspec,
README, changelog, library, CLI, and tests; it must contain no checkout override,
caches, or lockfile. Remove that specific temporary staging directory after
release review is complete. No source checkout files need to be renamed.
Keep `args`, `yaml`, `dart_style`, and `analyzer` as regular dependencies of
the generator, **not** the recorder. The generator itself is a dev dependency
of the consuming app. Do not move the CLI's dependencies into its own
`dev_dependencies`: those would not be resolved for consumers.
The generator dry run before recorder publication may fail hosted resolution;
a successful local override-based check is not proof of a public install.

## After publication

- [ ] Confirm package pages show the intended license, README, screenshots,
  repository/issue links, SDK constraints, and supported platform claims.
- [ ] Add `patrol_recorder` and dev-only `patrol_recorder_generator` in a clean
  external Flutter app with no path overrides. Verify
  `dart run patrol_recorder_generator:generate --help`, enable the packaged DevTools
  extension, and run the demo flow. Add `patrol` separately for test execution.
- [ ] Review pub.dev analysis and generated API documentation. Resolve actual
  findings rather than promising a score before the server analyzes the upload.
- [ ] Create a source tag/release for the exact published commit; attach the demo
  video if useful. Update installation/status wording only after upload succeeds.

## What pub.dev does not require

A demo video, GitHub release, verified publisher, and gallery screenshots are not
mandatory publication prerequisites. A license and legal redistribution rights
are required. Good documentation, examples, package metadata, and accurate
compatibility claims help users and pub.dev's quality analysis.

## Official references

- [Publishing packages](https://dart.dev/tools/pub/publishing)
- [Pubspec fields, including screenshots](https://dart.dev/tools/pub/pubspec)
- [Package layout conventions](https://dart.dev/tools/pub/package-layout)
- [DevTools extensions](https://docs.flutter.dev/tools/devtools/extensions)
