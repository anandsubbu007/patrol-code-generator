# Runnable YAML recorder example

This is a local demonstration, not authentication. No backend is contacted.
Use only fictional data. The [app](lib/app.dart) contains no recorder imports,
test profiles, or per-action recording callbacks.

## Setup

From the repository root:

```sh
flutter pub get
cd tool/devtools_extension
flutter pub get
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
cd ../../example
flutter pub get
dart pub global activate patrol_cli 4.8.0
flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd
```

Tested with Flutter 3.47.7, Dart 3.13.5, DevTools 2.60.0, Node 22.23.4 and Patrol
4.10.0 / CLI 4.8.0. Both recorder and generator are development dependencies.
The normal [main entrypoint](lib/main.dart) does not start the recorder.

## Record -> YAML

1. Open the printed real DevTools URL and enable **patrol_recorder**.
2. Click **Record**, choose this example project and a journey name such as
   `my_login`, then **Record and save YAML**.
3. Confirm `patrol_recorder/my_login.yml` exists immediately. It starts with no
   steps and `state: recording`.
4. Edit Email/Note and activate **Open demo account**. The file updates automatically
   with `{{email}}` and `{{note}}` references; typed values are not exported.
5. Optionally **Capture visible screen** before/during/after actions. The password
   field is automatically masked. Confirm the suggested page name or a stable
   state name, then **Save screenshot**. There is no session/timestamp directory.
6. **Stop recording**, review any highlighted steps, and confirm **Journey YAML saved**.
7. Copy the generator command and run it from this example directory.

Optional defaults, including `recordings_directory`, `screenshots_directory`, and
the generated Dart `output_directory`, live in [pubspec.yaml](pubspec.yaml).
There is no standalone recorder config file. The YAML is machine-maintained;
recording the same name again replaces it.

New YAML contains neither `session_id` nor an `app` block. The CLI infers the
normal [lib/main.dart](lib/main.dart) entrypoint from the app package and awaits
it before replay. The recording wrapper needs no duplicated import/builder
configuration. A custom test factory can be configured once in pubspec if needed.

## YAML -> Dart

```sh
dart run patrol_recorder_generator:generate --journey my_login
# Or generate every recorded *.yml:
dart run patrol_recorder_generator:generate
```

The output is:

```text
patrol_test/recorded_journeys/my_login/
  my_login_inputs.g.dart     abstract contract and validation
  my_login_steps.g.dart      generated Patrol actions
  my_login_inputs.dart       user implementation, created once
  my_login_test.dart         user test entrypoint, created once
```

Implement the abstract getters in the user-owned input file. `loadInputs()` returns
your implementation; the generated entrypoint passes it to
`runRecordedJourney($, inputs)`. Initial getters throw until wired intentionally.
No input values or expressions are evaluated from YAML.

The real [yaml_login recording](patrol_recorder/yaml_login.yml), its
[abstract contract](patrol_test/recorded_journeys/yaml_login/yaml_login_inputs.g.dart),
and [manually connected implementation](patrol_test/recorded_journeys/yaml_login/yaml_login_inputs.dart)
demonstrate this. The implementation uses fictional
[Dart fixtures](patrol_test/demo_profiles.dart), not values captured from the app.
Real secrets must come from your private test provider.

## Run and maintain

```sh
flutter analyze
dart pub global run patrol_cli:main test \
  --target patrol_test/recorded_journeys/yaml_login/yaml_login_test.dart \
  --dart-define RECORDER_PROFILE=secondary --device chrome --web-headless

# All independently discoverable tests:
dart pub global run patrol_cli:main test --device chrome --web-headless
```

For another journey, substitute its target and profiles that your implementation
supports. Patrol installs its official local Playwright dependencies on first run;
put Node 22 directly on PATH. Do not wrap Patrol in `npx --call`.

To update a flow, reset the app, re-record under the same name, and rerun the
generator. Only `.g.dart` files are regenerated. Your implementation/assertions
are preserved; implement any new abstract getters reported by the analyzer.
No discoverable suite file imports other discoverable tests.

Legacy schema-1 YAML remains readable, but re-recording writes schema 2. Old
session-named PNG directories are not automatically deleted. Current captures
reuse `<screenshots_directory>/<journey>/<name>.png`, with an adjacent hidden
ownership marker to protect unrelated files.

## Complex UI walkthrough

After **Open demo account**, the dashboard offers:

1. **Animation lab**: Animate card, Expand card, Simulate loading, and an expansion
   tile. Capture `animation_lab` before changes and override the second name to
   `animation_expanded`. All animations are finite.
2. **Repeated controls**: choose either Continue button and increment identical
   icon buttons. The cards, rather than each button, supply stable ancestor keys.
3. **Forms and overlays**: try Preview profile with an empty name to see validation;
   enter a fictional name, choose a role, and open the preview bottom sheet.
   Capture `profile_preview_sheet`. Open the information dialog and capture
   `information_dialog`.
4. **Account settings**: toggle notifications/newsletter and confirm/cancel Reset
   preferences. The confirmation capture is named `reset_preferences_dialog`.
   Scrolling the long list demonstrates a known review-required gesture.

The real [complex_ui YAML](patrol_recorder/complex_ui.yml) records a 16-action path
through animations, repeated Continue controls, dialogs and navigation, with four
named screenshots. Its generated [Patrol test](patrol_test/recorded_journeys/complex_ui/complex_ui_test.dart)
ran successfully using the inferred normal `main()` entrypoint.

Widget tests additionally exercise form values, dropdown selection, bottom-sheet
naming, toggles, and the unsupported-drag boundary. This is a representative
coverage matrix, not a guarantee for every Flutter widget or native platform.

Screenshots cover visible Flutter content, not full-device or stitched whole-page
views. Unsupported gestures remain explicit review steps. Read the
[complete workflow, configuration, and limitations](../README.md).
