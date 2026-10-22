# Patrol Recorder generator

Development-only companion to `patrol_recorder`. Converts stopped YAML journeys
to ordinary Patrol tests and typed input contracts, preserving user-owned input
providers and test wrappers. It does not record interactions or execute tests.

## Install

After both packages are published:

```sh
flutter pub add patrol_recorder:^0.0.1
flutter pub add --dev patrol_recorder_generator:^0.0.1 patrol:4.10.0
```

If recorder APIs are imported only from a test-only recording entrypoint, both
recorder and generator may be dev dependencies instead. If application widgets
import recorder APIs, only the recorder needs to be a regular app dependency.
The runtime recorder depends only on Flutter; formatter, analyzer, YAML, and
argument parsing dependencies belong to this tooling package.

Requires Dart >=3.13.0 and Flutter >=3.47.0 through the recorder dependency.
Use Flutter for dependency resolution and tests. Recording/replay is verified
on Flutter web; other platforms remain unverified.

## Generate

From the consuming app directory:

```sh
dart run patrol_recorder_generator:generate
dart run patrol_recorder_generator:generate --journey login
dart run patrol_recorder_generator:generate --project /path/to/app
dart run patrol_recorder_generator:generate --help
```

The CLI validates the selected batch before writing: schema 1/2/3, stopped state,
input references, selectors, app bootstrap, screenshot existence, and safe paths.
`--recordings-directory` overrides YAML discovery for one invocation. Invalid
sources and unsafe writes produce explicit failures and nonzero exit status.

Each journey produces:

| File | Ownership |
| --- | --- |
| `*_steps.g.dart` | Generated Patrol actions; regenerated |
| `*_inputs.g.dart` | Abstract typed input contract; regenerated |
| `*_inputs.dart` | User-owned provider, created once and preserved |
| `*_test.dart` | User-owned test/setup/assertions, created once and preserved |

Implement every input getter before replay. The generator intentionally supplies
no real values; obtain secrets from your private test provider. Add bounded
business-outcome assertions to the preserved test wrapper. Run through Patrol
CLI, not `flutter test` or the IDE's ordinary test buttons.

Optional app `recorder_config` settings include `recordings_directory`,
`screenshots_directory`, `output_directory`, `wait_timeout_ms` (100-120000,
default 15000), and `max_scrolls` (1-200, default 60). Normal `lib/main.dart`
startup is inferred; custom test factories can be configured in the app pubspec.
See the [complete recorder guide](https://github.com/anandsubbu007/patrol-code-generator#readme)
for recording, supported interactions, configuration, screenshots, and privacy.

## Development and publishing

The local `pubspec_overrides.yaml` resolves `patrol_recorder` from the checkout.
It is excluded from the published archive. The release manifest uses the hosted
dependency `patrol_recorder: ^0.0.1`; publish that package first. The repository
root excludes `tool/` from its runtime archive, and Pub inherits those exclusions.
For generator publication, stage its source and release metadata outside the
checkout without the local override, then validate hosted-only resolution.
Follow the [release checklist](https://github.com/anandsubbu007/patrol-code-generator/blob/main/doc/PUBLISHING.md)
for the exact staging and publication commands.

```sh
flutter pub get
flutter analyze
flutter test
```

## License and support

Licensed under [BSD-3-Clause](LICENSE). Independent project, not an official
Patrol product. Report sanitized reproduction details and tool versions in the
[issue tracker](https://github.com/anandsubbu007/patrol-code-generator/issues).
Do not share credentials, private screenshots, or authenticated debugging URLs.
