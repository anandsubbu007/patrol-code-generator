# Publishing Patrol Recorder and its generator

## 0.0.6 release plan

<!-- publication-history:start -->
Publication status checked on 2026-10-23: recorder **0.0.4** is present in both
the pub.dev version API and dependency-resolution index. Generator **0.0.4**
was not hosted at this check. Do not re-upload recorder 0.0.4.
This is a point-in-time record, not an assertion about future releases.

Both 0.0.5 versions were absent from pub.dev when this release was prepared.
Recorder 0.0.4 remains published and immutable; this release intentionally
advances both packages to 0.0.5.
<!-- publication-history:end -->

- Version 0.0.6 omits a platform allowlist rather than declaring Web-only or
  claiming every Flutter target. The package uses Flutter APIs and is not a
  standalone Dart package; end-to-end behavior beyond Web still needs testing.
- This checkout prepares `patrol_recorder` **0.0.6** and
  `patrol_recorder_generator` **0.0.6**. Publish the recorder first, then the
  generator. Do not describe either package as hosted until verified on
  pub.dev.
- This release lowers recorder/generator minimums to Dart >=3.8.0 <4.0.0
  and Flutter >=3.32.0, including Dart 3.11. Generator formatter/analyzer
  ranges permit SDK-compatible resolution. Validate minimum-SDK and
  downgraded dependencies as well as the pinned release toolchain.
  The extension source requires Flutter >=3.35.0 / Dart >=3.9.0; consumers
  receive compiled assets. Older-SDK package checks are not full DevTools
  recording/Patrol replay proof.
- The generator dependency uses `patrol_recorder: '>=0.0.6 <0.1.0'`. This
  admits compatible patch releases but excludes older versions (including
  0.0.4) and 0.1.0.
- Consumer instructions use the same range for both Patrol Recorder packages.
  Patrol 4.10.0 and Patrol CLI 4.8.0 remain pinned to the versions used by the
  validated example.
- The source tree may be ahead of the hosted release. Publishing makes the
  package archives permanent; review the exact staged contents first.

Publishing makes an archive public; treat the released version as permanent.
The interactive script requires confirmation; after the one-time setup below,
pushing a version tag authorizes automatic publication.

## Automated releases from a version tag or branch

The [release workflow](../.github/workflows/release.yml) accepts only stable
`vMAJOR.MINOR.PATCH` refs, for example `v0.0.6`. GitHub's trigger glob selects
candidate refs; the Python helper then validates the exact semantic version
(no leading zeroes, prerelease suffix, or extra path components).

### One-time setup

1. Publish each package once manually using the intended pub.dev account.
   In particular, finish the initial generator publication before attempting
   OIDC automation: its package Admin page does not exist until then.
2. On **each** package's pub.dev Admin page, enable automated publishing from
   GitHub Actions. Set repository to `anandsubbu007/patrol-code-generator` and
   tag pattern to `v{{version}}` for both packages. They intentionally share a
   tag because this repository releases them together. No long-lived pub.dev
   credential is stored in GitHub.
3. To publish from a **branch**, also create a fine-grained GitHub token with
   access only to this repository and **Contents: read/write**, then save it as
   repository Actions secret `RELEASE_TAG_TOKEN`. Organization policy may
   require approving the token. It is used only to push the prepared branch
   commit and tag. GitHub's default `GITHUB_TOKEN` cannot trigger another
   push-triggered workflow, so it cannot replace this token. A direct tag push
   does not require this secret.
4. Restrict who can push version branches and tags using repository rules.
   Anyone allowed to push one can initiate a release. The workflow has no
   interactive upload confirmation; the push is the approval. Do not enable
   pub.dev's optional required deployment environment without also adding the
   same environment to the workflow's publishing job.

### Releasing

After reviewing the code and release notes, choose **one** route:

```sh
# Tag route: push an immutable release tag from the reviewed source.
git tag v0.0.6
git push origin v0.0.6
```

```sh
# Branch route: the workflow prepares a commit and creates the matching tag.
git switch -c v0.0.6
git push -u origin v0.0.6
```

Merely creating a local ref does not start GitHub Actions; push it to GitHub.
Do not create both refs yourself: the branch route fails if the tag already
exists rather than moving it. Use a new version for a new release.

The branch job writes a version-preparation commit back to that release
branch and atomically pushes the matching tag. Its generated
`chore: prepare v...` commit does not repeat branch preparation. The new tag
starts the publishing job, authenticated with pub.dev using short-lived OIDC
credentials (`id-token: write`).

For either route, the tag job:

1. Extracts the version from the ref and updates both publishable manifests,
   the generator's compatible recorder range, current documentation version
   references/ranges, and both changelogs. It accepts the current version or a
   higher version, never a downgrade. An existing `## Unreleased` section at
   the top of each changelog is promoted to the target version; otherwise a
   factual coordinated-release entry is inserted. For useful release notes,
   maintain those Unreleased sections before pushing. Historical changelog
   entries and marked publication-history snapshots are preserved. The
   unpublished example and extension keep their independent app versions;
   local-path lockfiles are refreshed by dependency resolution, not edited
   by search-and-replace.
2. Runs the Python release-helper tests, Dart formatting, analysis and tests
   for all components, and builds/validates the bundled DevTools extension.
3. Saves a `release-source-changes-vX.Y.Z` workflow artifact containing the
   version/build patch, then makes a **runner-local** commit for clean Pub
   archive validation. A direct tag release never moves the tag or writes
   changes back to a branch; download/review the patch if you want to retain
   those generated changes in your development branch.
4. Dry-runs and publishes the recorder first. It waits up to ten minutes for
   both its version API and package-resolution index to contain that version.
5. Stages the generator outside the checkout without local overrides,
   resolves the hosted recorder, analyzes/tests the staged package, then
   dry-runs and publishes it. It verifies hosted availability afterward.
   API visibility alone does not guarantee Flutter can resolve the new version.
   Both CI and interactive publishing retry staged `flutter pub get` every ten
   seconds for up to ten additional minutes, but only when Pub reports that
   the generator's recorder constraint matches no versions. Each failure is
   logged; other dependency errors stop immediately. Validation and generator
   publication start only after real hosted dependency resolution succeeds.
   The two generated-code execution tests use the checked-out example through
   `PATROL_RECORDER_TEST_EXAMPLE`; its dependencies must be set up first. This
   fixture is not a hosted consumer app, while the staged generator's own
   dependency resolution uses the hosted recorder without overrides.

Uploads use `flutter pub publish --force` only after validation. Failures stop
the job; the workflow never downgrades dependency constraints or substitutes
local overrides. Already-hosted versions are skipped, so rerunning a failed
tag job can finish a partial release without republishing immutable packages.
Concurrency serializes repeated runs for the same ref and never cancels
an upload mid-run. A completed upload is not rolled back if a later step fails.
Rerunning an existing tag uses the scripts committed at that tag, not fixes
subsequently merged to the default branch. Do not move a published release tag;
if it predates a release-helper fix, use the updated interactive publishing
helper from a clean checkout of the same package version to finish the partial
release, or prepare a new coordinated version.

### Avoiding duplicate workflow runs

Ordinary CI runs on non-version branch pushes, pull requests, or manual
dispatches. It ignores all tag pushes and `vX.Y.Z` branch pushes, because the
release workflow already validates all components before publishing. Newer
ordinary CI runs cancel superseded CI runs for the same branch or pull request;
release runs are never automatically canceled.

A push to `main` still starts its normal CI. If you also push a version tag,
that tag starts a separate release run; these are different events. To avoid
running both at once, let main CI finish before pushing the tag. The branch
route also has a lightweight preparation run followed by the tag publication
run; only the tag run performs the full release validation.

### Retrying a canceled 0.0.6 release

First check both package pages: cancellation does not undo an upload. If
0.0.6 is not hosted, it can still be released. Do not force-move a version tag
that already exists on GitHub. Rerunning an existing tag workflow uses the
workflow at that tag's commit, not newer workflow fixes on `main`.

For the updated workflows to apply to a new tag, commit the release preparation
and workflow changes first, then create the tag from that commit. If an older
`v0.0.6` tag already exists, use the local interactive publisher from the
reviewed, clean 0.0.6 checkout instead of moving the tag:

```sh
python3 tool/publish_packages.py
```

Answer No to incrementing versions when both manifests already say 0.0.6.
The publisher requires separate confirmation for each missing package and
skips a recorder upload that already succeeded. Initial generator publication
still needs manual account authentication before its OIDC setup is available.

The updater can be previewed locally without uploading:

```sh
python3 tool/prepare_release.py v0.0.6 --from-ref
python3 -m unittest discover -s tool/tests -v
```

These automation helpers do not prove the hosted recording/replay workflow.
Complete the [post-upload consumer checklist](#after-both-uploads) before
announcing a release.

## Package layout

| Directory                        | Package                        | Publish?                           |
| -------------------------------- | ------------------------------ | ---------------------------------- |
| Repository root                  | Lightweight `patrol_recorder`  | First                              |
| `tool/patrol_recorder_generator` | Development-only generator CLI | Second                             |
| `tool/devtools_extension`        | Extension source app           | No; root ships its compiled assets |
| `example`                        | Demonstration app              | No                                 |

The generator is an app dev dependency, separate from the recorder runtime.
Users install both and run `dart run patrol_recorder_generator:generate`.
Patrol remains a separate test-runner dependency for executing generated tests.
The example and extension source app use a path dependency to the root for
development; the published packages have no local path dependencies.
The generator uses a local `pubspec_overrides.yaml` for checkout development,
excluded from its archive. Its release manifest depends on hosted recorder
`>=0.0.6 <0.1.0`; archive validation must omit the local override and follow
recorder 0.0.6 publication.

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

Use Flutter 3.47.7 / Dart 3.13.5 and Node 22.23.4 for first-time web validation.
An earlier clean Playwright browser installation stalled under Node 26.12.0.
Do not lower SDK constraints solely to improve a compatibility score without
testing that SDK.

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

## Recorder 0.0.3 publication evidence (2026-10-23)

- The example now contains a real fixture lab, text/JSON fixture files, a maintained
  two-case schema-5 journey, generated outputs, and implemented user-owned adapters.
- Both `m2_fixtures` cases passed real Patrol headless web replay. The example's
  9 widget tests passed and its source/generated-case analysis was clean.
- Login/account screenshots were refreshed and desktop/narrow fixture images
  added to the pubspec gallery. The refreshed 9.84-second WebM is an app walkthrough,
  not a video of DevTools, generation, or replay. No fresh live dialog capture is claimed.
- `example/example.md` supplies the pub.dev Example tab; the normal app entrypoint
  stays recorder-free. The generator now requires recorder `^0.0.3` and its local
  CLI checks pass; hosted-only generator resolution remains blocked until its
  first publication.
- The root 0.0.3 dry run includes the new examples/assets/images in an approximately
  15 MB archive. Its remaining warning is the dirty git worktree. Commit reviewed
  release files yourself and rerun the dry run before any explicit upload.

The pub.dev API reports recorder 0.0.3 as published on 2026-10-23. No generator
publication or hosted end-to-end consumer test is evidenced here. Historical
prepublication preparation evidence follows.

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
  (approximately 22 KB). At that time, the recorder was not yet published, so
  it used a temporary local recorder override; Pub reported that override as a
  hint.
  Repeat without overrides against the hosted recorder before publishing.

Historical evidence only: the 2026-10-22 preparation did not perform an upload.
The recorder was subsequently published as 0.0.3. A hosted generator install
and complete hosted record -> generate -> Patrol replay remain release checks;
do not interpret local-path consumer tests or app video as proof of those stages.

## Interactive release script

Run this internal helper from the repository root:

```sh
python3 tool/publish_packages.py
```

It coordinates the two package releases; it does not commit, tag, create a
GitHub release, or bypass the package owner's confirmations. Its flow is:

1. It reads both manifest versions and stops if they differ.
2. It asks whether to increment the coordinated version. **No or Enter is the
   default.** If you answer Yes, enter a stable `MAJOR.MINOR.PATCH` greater
   than the current version. The existing `prepare_release.py` updates both
   package versions, updates the generator's recorder range and matching
   documentation ranges, and inserts changelog TODO sections. The publisher
   then exits without running tests or uploading. Edit the release notes and
   publication-status documentation, complete all TODOs, run the checks,
   review and commit the changes, and rerun the publisher. If the entered
   version is the current version, it continues without making a bump.
3. Before a no-bump release, it requires a clean Git worktree and complete
   version-specific changelogs. It stops if the generator version already
   exists. If the recorder version is already hosted, it treats that upload as
   complete and skips directly to generator validation/publication; this lets
   you resume after a partial release or validate the generator after releasing
   the recorder. This clean-worktree gate prevents Pub's dirty-file archive
   warning and ensures the uploaded package is the reviewed commit.
4. It runs recorder `flutter analyze lib test` and `flutter test` from the
   repository root, plus `flutter pub publish --dry-run` if the recorder is
   not already hosted. Any failure stops the process before an upload.
5. If the recorder version is not already hosted, it asks for a separate
   Yes/No and requires the exact text `patrol_recorder@VERSION` before invoking
   `flutter pub publish`. Declining or entering a different string stops
   without uploading. After an upload, it checks pub.dev until that exact
   version is visible in both the version API and package-resolution index,
   allowing up to ten minutes for propagation. If the check cannot confirm it,
   generator publication stops. Resuming an already-uploaded recorder also
   waits for its package index before attempting generator resolution.
6. It copies only the generator's release files into a temporary directory.
   The local `pubspec_overrides.yaml` is not copied. There it runs `flutter pub
   get` against the hosted recorder range, `flutter analyze`, `flutter test`,
   and the generator archive dry-run. Any failure stops before generator
   upload.
   The example setup above is required for the generated-code execution tests;
   the script passes its absolute path with `PATROL_RECORDER_TEST_EXAMPLE`.
7. It asks for a separate confirmation and exact
   `patrol_recorder_generator@VERSION` text before invoking the generator
   `flutter pub publish` from that temporary directory. It checks that the
   published generator version appears on pub.dev before reporting completion.

The interactive helper aborts if the generator version already exists, because
Pub releases are immutable. If the recorder upload succeeded but generator
validation or upload did not, rerun the script for the same version: it detects
the hosted recorder and resumes at generator validation. Review the console
output carefully; the generator still requires its own separate confirmation.

`--dry-run-only` runs the same preflight and validations, but skips upload
confirmations and uploads. The generator still resolves its recorder dependency
from pub.dev, so this option can validate both archives only when that exact
recorder version is already hosted. Before the first upload, inspect the
recorder with the manual root dry-run below; do not claim that a local override
or local generator copy proves hosted dependency resolution.

## Manual publication and recovery

Make sure the release changes are committed and the worktree is clean first.
The recorder dry-run executed during preparation listed all required files and
ownership markers but exited with a warning because the worktree was dirty.
Repeat it after committing; stop if validation reports anything else.

```sh
# From the repository root; inspect the complete archive listing and validation.
flutter pub publish --dry-run
# After review, publish only with the package owner's approval.
flutter pub publish
```

Wait until `https://pub.dev/packages/patrol_recorder/versions/0.0.6` is
available. Confirm the hosted pubspec, metadata, README, screenshots, and
platform list before proceeding.

The root `.pubignore` deliberately excludes `tool/` from the runtime archive.
Pub inherits ancestor ignore rules, so publishing the generator directly from
that nested directory can incorrectly produce an empty archive. Stage only its
release files in a separate temporary directory, without copying local overrides.
After recorder 0.0.6 is confirmed hosted:

```sh
cd tool/patrol_recorder_generator
export PATROL_RECORDER_TEST_EXAMPLE="$(cd ../../example && pwd)"
release_dir="$(mktemp -d "${TMPDIR:-/tmp}/patrol-recorder-generator.XXXXXX")"
cp -R bin lib test README.md CHANGELOG.md LICENSE pubspec.yaml \
  analysis_options.yaml .pubignore "$release_dir/"
cd "$release_dir"
flutter pub get
flutter analyze
flutter test
flutter pub publish --dry-run
# Review the complete archive. Then publish from the staging directory:
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
The generator dry run must resolve hosted `patrol_recorder` in
`>=0.0.6 <0.1.0` without overrides. A successful local override-based check is
not proof of a public install.

## After both uploads

- [ ] Confirm package pages show the intended license, README, screenshots,
      repository/issue links, SDK constraints, and supported platform claims.
- [ ] In a clean external Flutter app with no path dependencies or overrides,
      install `patrol_recorder` and dev-only `patrol_recorder_generator` using
      the documented range. Add `patrol` separately for test execution.
- [ ] Verify `dart run patrol_recorder_generator:generate --help`, enable the
      packaged DevTools extension, record and stop a fictional-data journey,
      generate it, implement the user-owned input provider and outcome assertion,
      run it through Patrol CLI, and regenerate to confirm user files survive.
- [ ] Review pub.dev analysis and generated API documentation. Resolve actual
      findings rather than promising a score before the server analyzes the upload.
- [ ] Create a source tag/release for the exact published commit; attach the demo
      video if useful. Update any remaining release-candidate wording only after
      both uploads are confirmed.

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
