# Publishing Patrol Recorder

Only the `patrol_recorder` package is published. Its built DevTools extension
must be included in the package archive.

## Prepare

```sh
python3 tool/prepare_release.py 0.0.8
python3 tool/prepare_release.py 0.0.8 --apply
```

The first command previews a stable semantic-version bump; `--apply` updates the
root manifest and adds a changelog placeholder. Complete that release's notes,
review all changes, and commit them before publishing. Version preparation never
uploads, commits, or tags.

Run the checks in [CONTRIBUTING.md](../CONTRIBUTING.md), including rebuilding and
validating the packaged DevTools extension. Inspect the package archive with:

```sh
flutter pub publish --dry-run
```

Confirm the archive contains the recorder runtime and current extension assets,
not stale local artifacts. A dry run does not upload a package.

## Interactive publication

```sh
python3 tool/publish_packages.py --dry-run-only
python3 tool/publish_packages.py
```

The helper requires a clean worktree and a completed changelog section, checks
that the version is not already hosted, resolves dependencies, runs recorder
analysis/tests, and dry-runs the archive. Upload additionally requires explicit
confirmation and typing `patrol_recorder@VERSION`. Pub.dev authentication is
managed by the Dart/Flutter tools. Never commit credentials.

## GitHub Actions

The release workflow accepts `vMAJOR.MINOR.PATCH` tags and matching release
branches. A release branch prepares the version and creates the same-named tag;
configure `RELEASE_TAG_TOKEN` with repository Contents read/write permission so
the pushed tag triggers the publication run. Alternatively push a reviewed tag
yourself.

The tag run validates the recorder, extension, example, and release helpers,
builds the packaged extension, and publishes the recorder using pub.dev OIDC.
Configure trusted publishing for this repository and workflow on pub.dev before
using it. Already hosted versions are immutable and are skipped on reruns.
Never move a published release tag.

After publication, install the hosted package in a clean consumer app, open its
DevTools panel, record interactions, copy the direct Dart output, supply input
variables, and run a manually maintained Patrol test. Passing local checks or
an accepted upload alone does not establish that consumer workflow.
