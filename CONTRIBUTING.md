# Contributing

Patrol Recorder turns debug-session interactions into short Patrol Dart
statements displayed live in DevTools. Keep the recorder runtime, service
protocol, extension UI, and documentation aligned.

## Repository layout

- `lib/`, `test/`: recorder runtime and its tests.
- `tool/devtools_extension/`: DevTools UI and extension tests.
- `extension/devtools/`: packaged extension assets.
- `example/`: demo app, debug recording entrypoint, and manually maintained tests.
- `tool/tests/`: publication-helper regression tests.

## Local validation

From the repository root:

```sh
flutter pub get
flutter analyze lib test
flutter test
python3 -m unittest discover -s tool/tests -v
```

Then validate the extension and example:

```sh
cd tool/devtools_extension
flutter pub get
flutter analyze
flutter test
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
cd ../../example
flutter pub get
flutter analyze
flutter test
```

Format changed Dart files with the repository's Flutter SDK. CI checks the
minimum supported Flutter SDK as well as the current validation matrix.

## Behavior to preserve

- Copy produces direct Patrol statements, not another artifact to transform.
- Typed text appears as input identifiers, never captured literal input values.
- Resolve targets against the actual action owner and preserve ambiguity rather
  than silently choosing a repeated label or unrelated ancestor.
- `recorder_config.addkey: true` only enables key suggestions. It must not mutate
  application source. Suggested keys must be placed on the correct action owner.
- Expectations distinguish component checks from text checks.
- Keep ordinary app startup and manually maintained tests independent of the
  recording entrypoint.

For a manual smoke test, follow [the demo](doc/DEMO.md), inspect the live output,
copy it into a Patrol test, supply inputs, and run that test. Include runtime and
extension regression coverage for protocol changes.

See [publishing](doc/PUBLISHING.md) for release preparation and upload safeguards.
