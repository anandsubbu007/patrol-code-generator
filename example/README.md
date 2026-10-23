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
4.10.0 / CLI 4.8.0. Recorder and generator are separate dev dependencies.
The normal [main entrypoint](lib/main.dart) does not start the recorder.

This repository example uses local recorder/generator paths and a recorder
override so both tools share the checkout rather than resolving a hosted copy.
For a separate app installed from pub.dev, use the
[hosted installation guide](../README.md#install-from-pubdev) instead; compiled
DevTools assets are included in the recorder package.
See the [screenshots and demo walkthrough](../doc/DEMO.md).

## M2 fixtures and expectations

After opening the demo account, choose **Fixture and expectation lab**. The
[page and local store](lib/fixture_lab.dart) let you load/clear a fictional customer,
show enabled state and credit, and inspect zero or two repeated items. No network
or authentication service is involved.

The maintained [m2_fixtures.yml](patrol_recorder/m2_fixtures.yml) demonstrates:

- Two independent cases, `populated` and `empty`, with stable authored step IDs.
- JSON [customer data](patrol_recorder/assets/m2_fixtures/customer.json) and a
  [text fixture](patrol_recorder/assets/m2_fixtures/note.txt), referenced by name.
- String, integer, number, boolean, and JSON inputs in reusable profiles, plus a
  per-case data override. Fixtures are manually authored, not captured input values.
- Shared `seed` setup, an `enter_lab` group, and a key-first selector override for
  the expanded `open_lab_open` step.
- Exact-text assertions for the seeded data and count assertions for two/zero items.

The [shared adapter](patrol_test/m2_fixture_adapter.dart) implements `applyAsset`
and connects validated fixture content to the actual store. Both generated
providers mix it in; these are complete implementations, not throwing TODO stubs.

Run from this example directory:

```sh
dart run patrol_recorder_generator:generate --journey m2_fixtures --preview
dart run patrol_recorder_generator:generate --journey m2_fixtures --inspect-selectors
dart run patrol_recorder_generator:generate --journey m2_fixtures
flutter analyze lib patrol_test/recorded_journeys/m2_fixtures patrol_test/m2_fixture_adapter.dart
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/populated/populated_test.dart --device chrome --web-headless
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/empty/empty_test.dart --device chrome --web-headless
```

The two case targets have been replayed successfully through Patrol web. Let each
use its default profile (`demo` versus `empty`); a global demo-profile override
changes the empty case's data and intentionally invalidates its assertions.
Generated outputs live under
`patrol_test/recorded_journeys/m2_fixtures/cases/<case>/`. Regeneration changes only
the two `.g.dart` files per case, preserving the connected provider and wrapper.

Asset paths are relative to the configured recordings root under `assets/`;
this example uses `patrol_recorder/assets/m2_fixtures/`. The generator embeds
validated text/JSON and bounds file reads to the project/recordings roots.
Absolute/traversal/symlink paths are rejected, with a 1 MiB per-file and 10 MiB
aggregate limit. An asset applies a fixture; it is not an upload or screenshot.

To try live expectations, record a **new** journey name, open the fixture lab,
load the sample, then choose **Add expectation** in DevTools. Tap **Ada Fixture**
in the app and choose **Exact text**: the editable comparison field starts with
`Ada Fixture`. Save, then stop and generate the recording. Do not re-record over
the maintained `m2_fixtures` YAML, which contains manual reusable definitions.

The refreshed [publication walkthrough](../doc/DEMO.md) shows the real app lab at
desktop and narrow browser sizes. A narrow-browser screenshot is not a native
mobile end-to-end support claim.

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

The generator is a separate development dependency of the example app.
Run it from the example directory:

```sh
cd example
dart run patrol_recorder_generator:generate --journey my_login
# Or choose a journey, preview, inspect selectors, or reset interactively:
dart run patrol_recorder_generator:generate
# Generate every recorded *.yml without prompting:
dart run patrol_recorder_generator:generate --all
```

If your terminal is already in `example/`, omit the `cd example` line. From the
repository root, the equivalent one-off invocation is
`dart --directory=example run patrol_recorder_generator:generate`.

The terminal menu returns after validation failures so stale recordings do not
prevent selecting a valid journey. Reset offers YAML-only, YAML plus screenshots,
or those files plus generated code (including user-owned inputs/tests), lists the
exact files, and requires typing `DELETE`. Re-record in DevTools afterward.
Use `--no-interactive` for unattended batch generation; redirected input or
`CI=true` also disables prompts by default.

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
Recorded inputs never contain typed values. Schema 5 additionally accepts
explicitly authored non-secret typed fixtures; arbitrary expressions are not evaluated.

New scaffolds include TODOs for required input/secret wiring and bounded final
outcome assertions. Their Dartdoc includes the journey's Patrol command and
explains that it must run from the app directory, not via the IDE's ordinary
test button. Resolve input TODOs before replay. Existing customized input and
test files are preserved, so regeneration does not insert new comments into them.

The real [yaml_login recording](patrol_recorder/yaml_login.yml), its
[abstract contract](patrol_test/recorded_journeys/yaml_login/yaml_login_inputs.g.dart),
and [manually connected implementation](patrol_test/recorded_journeys/yaml_login/yaml_login_inputs.dart)
demonstrate this. The implementation uses fictional
[Dart fixtures](patrol_test/demo_profiles.dart), not values captured from the app.
Real secrets must come from your private test provider.

## Run and maintain

### Run through Patrol CLI

Run from the example directory, including in VS Code's integrated terminal.
You can configure your own IDE task for this command; the package does not
install a workspace task or change the standard IDE test buttons.

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

Use Patrol CLI even for a single generated test. VS Code's standard **Run Test /
Debug Test** buttons and direct `flutter test` invocation do not start Patrol's
app service and can fail with
`LateInitializationError: Field 'patrolAppService' has not been initialized`.
For a journey named `login_try`, run from this example directory:

```sh
dart pub global run patrol_cli:main test \
  --target patrol_test/recorded_journeys/login_try/login_try_test.dart \
  --dart-define RECORDER_PROFILE=demo --device chrome --web-headless
```

Before replay, implement every getter in that journey's user-owned input provider.
New providers initially throw until connected. The
[yaml_login provider](patrol_test/recorded_journeys/yaml_login/yaml_login_inputs.dart)
shows how to wire fictional demo email and note fixtures for this
non-authenticating local app. For real apps, connect your private test provider;
do not put real credentials in YAML or generated files.

To update a flow, reset the app, re-record under the same name, and rerun the
generator. Only `.g.dart` files are regenerated. Your implementation/assertions
are preserved; implement any new abstract getters reported by the analyzer.
No discoverable suite file imports other discoverable tests.

Legacy schemas 1-4 remain readable, but re-recording writes schema 5.
Old session-named PNG directories are not automatically deleted. Current captures
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
   Scroll the long list to exercise target-based scrolling.

The real [complex_ui YAML](patrol_recorder/complex_ui.yml) records a 16-action path
through animations, repeated Continue controls, dialogs and navigation, with four
named screenshots. Its generated [Patrol test](patrol_test/recorded_journeys/complex_ui/complex_ui_test.dart)
ran successfully using the inferred normal `main()` entrypoint.

Widget tests additionally exercise form values, dropdown selection, bottom-sheet
naming, toggles, and scroll-observation boundaries. This is a representative
coverage matrix, not a guarantee for every Flutter widget or native platform.

## Async and lazy-loading walkthrough

The real [async_flow journey](patrol_recorder/async_flow.yml) starts from the
normal login screen and demonstrates:

1. Open the asynchronous UI lab and activate the inline Terms link in a keyed
   paragraph. The link waits locally before enabling the next action.
2. Select Option 24 from a lazy picker. The list adds ten options after a local
   delayed `Future`; replay scrolls continuously to the keyed target within the
   configured scroll limit.
3. Confirm the choice, long-press the keyed details card, and turn off the
   `loop_animation` switch. The test wrapper waits for and asserts each outcome.
4. Use the named `async_loaded` screenshot as a stable capture of the loaded
   state, not a timestamp/session artifact.

The demo's delays are local fixtures, not external network calls. The recorder
does not intercept arbitrary application `Future`s or infer business completion;
add bounded waits/assertions for application-specific outcomes in the preserved
test wrapper. Continuous animations are not globally settled between generated
actions.

Inline link text must be unique within its keyed paragraph. For duplicate links,
use a uniquely keyed paragraph or a keyed `TextButton`/`WidgetSpan`. Scroll replay
targets a visible item rather than reproducing an exact pixel offset. Drag,
wheel, accessibility, pan/zoom, and consumed-notification scroll paths are
covered, but custom painting, opaque platform views, pinch/slider-specific
gestures, and unsupported custom widgets are not universal guarantees. Stable
keys improve identity but cannot make every gesture observable.

Screenshots cover visible Flutter content, not full-device or stitched whole-page
views. Unsupported gestures remain explicit review steps. Read the
[complete workflow, configuration, and limitations](../README.md).
