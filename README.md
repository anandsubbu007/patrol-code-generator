# Patrol Recorder

Record a Flutter journey into **YAML**, generate ordinary **Patrol Dart tests**,
and supply dynamic values through your own **Dart input implementation**.

```text
DevTools Record -> patrol_recorder/<journey>.yml
                         |
              run the local code generator
                         |
              Patrol steps + abstract inputs
                         |
              your input implementation -> Patrol CLI
```

No recording calls are needed in application button/text-field callbacks.
Recording setup stays in a test-only entrypoint, not application `lib/`.
This is an **unpublished prototype**, not a universal or production-certified
recorder. Tested: Flutter 3.47.7 / Dart 3.13.5, DevTools 2.60.0, Patrol 4.10.0,
Patrol CLI 4.8.0, Node 22.23.4, Flutter web.

## Guide

1. [Setup and record](#setup-and-record)
2. [Generate Patrol code](#generate-patrol-code)
3. [Implement dynamic inputs](#implement-dynamic-inputs)
4. [Run the tests](#run-the-tests)
5. [Re-record and maintain journeys](#re-record-and-maintain-journeys)
6. [Configuration and screenshots](#configuration-and-screenshots)
7. [Use in your own app](#use-in-your-own-app)
8. [Limits and troubleshooting](#limits-and-troubleshooting)

## Architecture reference: Maestro

The workflow follows the useful ideas documented by
[Maestro Flows](https://docs.maestro.dev/maestro-flows/readme):
declarative ordered YAML actions, identifier-based targets, external input
references, and a separate execution stage. Its
[selectors](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/how-to-use-selectors)
also demonstrate using context to disambiguate repeated controls.

This package is **not Maestro-compatible YAML and does not integrate Maestro**.
Maestro uses `${VARIABLE}` parameters; this recorder uses the requested
`{{input_name}}` references and generates typed Dart getters. It does not evaluate
JavaScript/templates or ship a custom runner. **Patrol remains the execution engine.**
Maestro's platform coverage and maturity do not imply equivalent support here.

## Setup and record

### 1. Install and build

Use a Flutter-supported Chrome-compatible browser and Node 22 on PATH. Check
`flutter doctor`, `flutter devices`, and `node --version`.

From this repository root:

```sh
flutter pub get
dart pub global activate patrol_cli 4.8.0
cd tool/devtools_extension
flutter pub get
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
cd ../../example
flutter pub get
```

These commands finish in the example app. The extension uses packaged local
CanvasKit assets, not a renderer CDN. The generator package is resolved as an app
**development dependency**; formatter/YAML dependencies stay out of the runtime
recorder package.

### 2. Launch the test-only recording entrypoint

From the example directory:

```sh
flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd
```

Open the printed DevTools URL, select **patrol_recorder**, and enable the extension.
Wait for **Connected - ready**. Keep the app running. Do not share authenticated
VM Service/DTD URLs.

Ordinary `flutter run` uses the normal app entrypoint and does not install the
recorder. The example's [app](example/lib/app.dart) has no recorder imports,
profiles, or per-action callbacks.

### 3. Record a named journey

1. Put the app at its initial screen. Click **Record**.
2. Confirm the **app project**. DTD supplies permitted destinations; the package
   can be selected automatically when one Flutter app declares the recorder as a
   development dependency. Otherwise choose it explicitly; duplicate roots are collapsed.
3. Enter a journey name such as `login`, description, YAML directory, and screenshot
   directory. Optional defaults come from the app's `recorder_config` pubspec section.
4. Click **Record and save YAML**. The file
   `patrol_recorder/login.yml` is created immediately with `state: recording`.
5. Interact normally with supported app controls. In the example, edit Email and
   Note, then click **Open demo account**. No input values are requested in DevTools.
   The recorder stores `{{email}}` / `{{note}}`, not the text you typed.
6. Click **Capture visible screen** whenever needed, including during recording.
   Confirm the suggested page-based name (or enter a stable state name), then
   **Save screenshot**. The PNG and its YAML reference are saved immediately.
7. Click **Stop recording**. This flushes the latest snapshot and marks the YAML
   `stopped`. Check **Journey YAML saved** and the full path.
8. Review highlighted actions. Uncheck an action only when it is not needed;
   `include: false` is persisted, and the generator will not replay it.
9. Use **Copy generator command** and run it from the indicated app directory.

Actions are autosaved approximately once a second. Stop and capture operations
also save explicitly. A write failure shows **YAML NOT UP TO DATE** and **Retry
YAML save**; keep DevTools open until saving succeeds. An interrupted recording
remains marked `recording`, and the generator refuses to pretend it is complete.

Using the **same journey name replaces the previous recorder-owned YAML**.
That is the normal way to update a flow. No manual YAML edits are required.
Unrecognized files or concurrent external edits are not silently overwritten.

## YAML source

All journey source files live in one directory by default:

```text
patrol_recorder/
  login.yml
  accounts.yml
```

Here is a step excerpt; the recorder also writes journey/state metadata.
New YAML has **no session ID and no app import/builder block**:

```yaml
steps:
  - id: "step_0001"
    action: "enterText"
    target:
      key: "user_name"
    source: "focusedController"
    include: true
    input: "{{user_name}}"
    secret: false
  - id: "step_0002"
    action: "tap"
    target:
      text: "Continue"
      within:
        key: "shipping_form"
    source: "pointerGesture"
    include: true
```

See the actual [recorded YAML example](example/patrol_recorder/yaml_login.yml).
Every text action uses a whole-string `{{name}}` reference, including secrets.
There are no raw input defaults, passwords, arbitrary expressions, or coordinate
selectors in YAML. `secret: true` classifies a reference; it is not a value.
New recordings use schema 3; the generator continues to read schemas 1 and 2.

Targets prefer keys, then semantics identifiers/labels, field labels/text, then
supported public widget types. Repeated targets can use a unique ancestor
`within` scope. Ambiguous actions retain a review reason rather than selecting
`.first` or an index. The generated test asserts a single match before acting.

## Generate Patrol code

From the app directory:

```sh
# Generate all *.yml journeys in the configured source directory.
dart run patrol_recorder_generator:generate

# Generate one named journey.
dart run patrol_recorder_generator:generate --journey login

# Other supported options.
dart run patrol_recorder_generator:generate --project /path/to/app
dart run patrol_recorder_generator:generate --journey login \
  --recordings-directory custom_recordings
dart run patrol_recorder_generator:generate --help
```

The CLI validates the selected batch before writing: supported schema, matching
journey filename, a resolvable app entrypoint, stopped recording, valid references/selectors, reviewed
incomplete actions, and referenced screenshots. Errors return a nonzero exit
status. YAML with no included actions is not turned into an empty passing test.

Default output:

```text
patrol_test/recorded_journeys/login/
  login_test.dart
  login_inputs.dart
  login_inputs.g.dart
  login_steps.g.dart
```

| File | Ownership |
| --- | --- |
| `*_inputs.g.dart` | Generated abstract `JourneyInputs` contract and validation |
| `*_steps.g.dart` | Generated normal Patrol actions, current test name and case tag |
| `*_inputs.dart` | One-time user implementation scaffold; **never overwritten** |
| `*_test.dart` | One-time Patrol entrypoint for setup/assertions; **never overwritten** |

The CLI prints every generated/preserved path and the next commands.
Generation does not execute the test and does not inject real data.

## Implement dynamic inputs

For YAML referencing `{{user_name}}`, the generated contract has a getter like
`String get inputUserName;`. Implement it in the separate user-owned input file:

```dart
import 'login_inputs.g.dart';

class MyLoginInputs extends JourneyInputs {
  const MyLoginInputs();

  @override
  String get inputUserName => 'demo@example.invalid';
}

Future<JourneyInputs> loadInputs() async => const MyLoginInputs();
```

Implement **every getter actually declared** in your generated contract. The
initial scaffold deliberately throws a clear error until wired; it does not
invent defaults. Required values must be nonempty.

The generated test passes the instance to:

```dart
final inputs = await loadInputs();
await runRecordedJourney($, inputs);
```

You may instead call that generated function from your own Patrol test and pass
any implementation of `JourneyInputs`. Use `loadInputs()` for asynchronous fixture
setup, profile selection, or private-provider access. Keep this code under the test
directory; do not move test credentials into application `lib/` or YAML.

The example [input implementation](example/patrol_test/recorded_journeys/yaml_login/yaml_login_inputs.dart)
connects the abstract getters to fictional test fixtures. `RECORDER_PROFILE` is
an optional compile-time profile selector in the scaffold; add your own profiles
and validate them in that user-owned file.

**Secrets:** connect secret getters to your private test provider. Do not hardcode
credentials in either generated or user-owned source. There is no required JSON
input format. If you choose `String.fromEnvironment` with Patrol's
`--dart-define-from-file`, remember that values are embedded in test binaries:
it is not a vault. Protect the private file, binaries, and app logs. Generated
input actions disable Patrol value logging.

## Run the tests

After implementing inputs, from the app project:

```sh
dart format patrol_test/recorded_journeys/login
flutter analyze

# One generated file.
dart pub global run patrol_cli:main test \
  --target patrol_test/recorded_journeys/login/login_test.dart \
  --device chrome --web-headless

# One case tag, with a profile implemented by your provider.
dart pub global run patrol_cli:main test \
  --target patrol_test/recorded_journeys/login/login_test.dart \
  --tags recorder_login_sign_in --dart-define RECORDER_PROFILE=secondary \
  --device chrome --web-headless

# All independently discovered test files.
dart pub global run patrol_cli:main test --device chrome --web-headless
```

Use your actual path/tag. `patrol` is equivalent to `dart pub global run
patrol_cli:main` if the global executable is on PATH. The first web run installs
official Node/Playwright dependencies. Use the tested Node 22 directly on PATH;
do not wrap Patrol in `npx --call`.

Run individual generated tests through Patrol CLI with `--target`, not VS Code's
standard **Run Test / Debug Test** buttons or direct `flutter test`. Patrol CLI
initializes the app service required by `patrolTest`; bypassing it can cause
`LateInitializationError: Field 'patrolAppService' has not been initialized`.
Widget tests in `test/` still use the normal Flutter test runner.

For this repository's example, open the repository root in VS Code and make a
journey's `*_test.dart` file active. Press **Cmd+Shift+B** (macOS) or
**Ctrl+Shift+B** (Windows/Linux) to run **Patrol: Run current test**. The
[workspace task](.vscode/tasks.json) supplies the active file to Patrol CLI,
uses the example directory, and runs headless Chrome with the `demo` profile.
Save changes first and keep Dart/Flutter/Node 22 on VS Code's PATH. Results appear
in the task terminal; input-provider wiring is still required.

Patrol launches a separate app. The recording connection is not assumed to
survive; results remain in the terminal, not an automatic DevTools result feed.
Do not add a discoverable suite file importing other discoverable tests.
Recording success is not a business assertion: add assertions to the user-owned
test after `runRecordedJourney()` and supply any necessary setup/cleanup.

## Re-record and maintain journeys

1. Reset the app to the initial state provided by its normal entrypoint or configured test bootstrap.
2. Record the new flow under the **same journey name**. The YAML is replaced.
3. Stop and review it, then run the generator again.
4. The generated steps/abstract contract update automatically; your implementation
   and custom test wrapper are preserved byte-for-byte.
5. If the flow adds an input, implement the new abstract getter. `flutter analyze`
   makes missing implementation visible.
6. Run the changed test and relevant profiles, then the suite.

Do not edit `.g.dart` files you intend to regenerate. There is no arbitrary-Dart
merge or parsing custom Dart back into the recorder. Old JSON session exports and
pre-YAML test layouts are historical fixtures, not automatically migrated sources;
record a new named YAML journey to adopt this workflow.

Screenshots use stable journey/name paths. Re-recording and taking the same named
capture replaces that recorder-owned PNG. Removed capture references do not delete
old files. If you need a historical baseline, preserve it separately before
replacement; no screenshot comparison/history engine is provided.
Deleting a YAML source does not automatically delete its generated test.

## Configuration and screenshots

Optional app `pubspec.yaml` settings:

```yaml
recorder_config:
  recordings_directory: patrol_recorder
  screenshots_directory: artifacts/recorder_captures
  output_directory: patrol_test/recorded_journeys
  journey_id: login
  case_id: sign_in
  case_name: Sign in with demonstration profile
  profile: demo
  wait_timeout_ms: 15000
  max_scrolls: 60
```

All paths are relative to the selected app project, with no `..`, absolute paths,
or unsafe characters. Names use lowercase letters, digits, and underscores,
starting with a letter. Unknown config fields/types are rejected.

The Record dialog can override the YAML/screenshot directories for that recording.
Its copied generator command includes the chosen YAML directory. For CLI-wide
defaults, keep `recordings_directory` in pubspec consistent. `output_directory`
is read by the CLI when generating Dart. Existing screenshots are not relocated
when settings change.

Images save as:

```text
<screenshots_directory>/<journey>/login_page.png
<screenshots_directory>/<journey>/account_overview.png
<screenshots_directory>/<journey>/account_expanded.png
```

- A suggestion is derived from the active page's scoped semantics identifier,
  scoped semantics label, named route, or public page widget type. Generic pages
  fall back to a safe name. You can override it before saving.
- Repeated captures of one page suggest `_2`, `_3`, etc. Prefer meaningful state
  names such as `animation_expanded` for long-lived alignment; capture order and
  translated labels are not guaranteed stable identifiers.
- Names must be unique within a journey. To retake an existing named capture,
  remove its reference and capture again with that name.
- There are no timestamp/session folders or session IDs in new YAML. A private
  in-memory transport token still detects app restarts; it is not exported.
- A small hidden `.name.recorder` ownership marker beside each PNG permits safe
  replacement of recorder-owned images and prevents overwriting unrelated PNGs.
  Keep these markers with generated screenshots. Legacy session directories are
  left untouched rather than deleting existing evidence.
- Capture covers the **visible Flutter viewport**, not a stitched whole page,
  OS keyboard, notifications, native dialogs, or guaranteed platform-view pixels.
- `obscureText`, `RecorderSensitive`, and `RecorderIgnore` regions are masked
  before PNG encoding/transport. `RecorderIgnore` also excludes interactions.
- Other visible text can appear in images. Mark sensitive content and inspect
  previews; the recorder cannot identify every secret drawn by an application.
- Limits: 8 megapixels/4 MiB per PNG, 10 captures per journey, 20 MiB in-memory
  capture data. Invalid privacy geometry fails explicitly.

DTD only writes within authorized project roots on the **DTD host**, which may be
remote. Text YAML writes are read back and compared. This host cannot read back
arbitrary PNG bytes through DTD; PNG writes are acknowledged and existence checked.
The CLI performs local sibling-temp-file replacement for generated files and
rejects symlinked source/output paths. Neither workflow is a multi-file transaction.
Avoid concurrent recording/generation/editing of the same journey.

## Use in your own app

Add both local packages as development dependencies (neither is published):

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol_recorder:
    path: /absolute/path/to/patrol-code-generator
  patrol_recorder_generator:
    path: /absolute/path/to/patrol-code-generator/tool/patrol_recorder_generator
  patrol: 4.10.0

patrol:
  test_directory: patrol_test
```

Build the extension once as above. Create `patrol_test/recorder_main.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:your_app/app.dart' as app;

void main() {
  if (!kDebugMode) {
    throw StateError('Use the normal app entrypoint outside recording.');
  }
  final recorder = RecorderController();
  runApp(RecorderScope(controller: recorder, child: app.createApp()));
}
```

Adapt the import and root widget creation in this recording-only entrypoint.
You can also pass your root widget directly instead of a factory. No data profiles or
per-button/per-field hooks are required. Names for non-keyed input fields are
allocated automatically, such as `{{input_0001}}`.

### Why the generator needs an app startup path

Selectors describe **what to do after the app starts**, not how to initialize it.
For a conventional app the generator now reads the package name from pubspec,
checks `lib/main.dart` for a callable top-level `main()`, and emits:

```dart
await Future<void>.sync(app.main);
await $.pumpAndSettle();
```

This supports synchronous and asynchronous `main()` functions and needs no `app`
block in each YAML. It does not try to reconstruct a Dart import from the live
widget tree or guess arbitrary dependency injection/authentication setup.

If normal `main()` is unsuitable for tests, configure a no-argument Widget factory
once in the app's pubspec:

```yaml
recorder_config:
  app_import: package:your_app/test_app.dart
  app_builder: createTestApp
```

The import must belong to the selected app package. Missing functions, required
parameters and syntax errors fail generation explicitly. A custom factory must
return a Widget; supply other setup in your test wrapper/provider as needed.
The recording entrypoint must not end with `_test.dart`.

YAML schemas 1 and 2 remain readable with their original compatibility behavior;
re-recording writes schema 3 without `app`/`session_id`. If an old recorder configuration deliberately
selected a custom factory, move that selection into pubspec before re-recording.
Do not assume arbitrary app-specific initialization can be inferred automatically.

## Limits and troubleshooting

| Symptom | Action |
| --- | --- |
| Extension missing/unavailable | Build/copy/validate extension assets; run the debug recording entrypoint; enable the real DevTools extension |
| Protocol mismatch | Restart the recording app and reload rebuilt DevTools assets; runtime protocol is 5, new YAML schema is 3 |
| No destination | Refresh authorized projects using a Flutter/IDE DTD session; never use an unrestricted daemon |
| YAML NOT UP TO DATE | Keep the draft open; resolve permissions/concurrent edits and Retry YAML save |
| App restarted or browser closed | Last persisted YAML survives. Re-record the same name if the source remains unfinished; do not treat an interrupted flow as complete |
| Generator rejects active recording | Stop in DevTools and verify the source is saved as stopped |
| Unknown/ambiguous target | Add a stable key/ancestor, re-record, or explicitly exclude an unnecessary action; never use `.first`/coordinates as a silent fix |
| Scroll/long press/custom/native action | Flutter scrollables and identifiable long-press targets are observed; unsupported custom/native gestures remain review-required. Add unique stable keys and check the recorded target |
| Missing input getter/value | Implement the abstract contract in the preserved input file; the YAML intentionally contains no values |
| Existing generated file not recognized | Use a new journey name or reconcile the file manually; handwritten output is not overwritten |
| Duplicate test execution | Keep only actual tests named `*_test.dart`; do not import discoverable tests from another discoverable entrypoint |

Ordinary pointer taps are candidates, not callback-success proof. Accessibility
events are requests before dispatch. Field notifications can include selection,
composition, or programmatic changes; the recorder does not read/retain raw text
to distinguish them. It records reference-only field activity.

### Scrolling, links, and asynchronous UI

The recorder observes drag, wheel, pan/zoom, accessibility scrolling, and standard
Flutter scroll-position changes, including when an ancestor consumes scroll
notifications. Scroll replay identifies a visible destination and uses bounded,
continuous Patrol scrolling to reach it; it does not reproduce an exact pixel
offset. A target key on the `ListView`, `GridView`, or other `ScrollView` and a
unique key on intended list items improve identity. `max_scrolls` defaults to 60
and accepts 1-200. `wait_timeout_ms` defaults to 15000 and accepts 100-120000;
these settings bound readiness and target waits. The recorder does not intercept
arbitrary `Future`s or infer business-state completion.

Inline links can be generated as text-range taps when their text is unique inside
a keyed paragraph. If the same link text occurs more than once, distinguish it
with a unique keyed paragraph, or use a keyed `TextButton`/`WidgetSpan` target.
Custom-painted controls, opaque platform views, pinch/slider-specific gestures,
and arbitrary custom widgets are not universally inferred. Keys improve identity
but cannot make an unsupported gesture observable, and the recorder never edits
application source to add keys.

Generated actions use bounded visibility/enabled waits rather than globally
settling the app after every action. This supports a looping animation while
waiting for a delayed control. Final user assertions should add their own bounded
waits for the expected outcome; a replay completing is not itself a business
assertion.

No full editor, arbitrary native recording, subflow/control-flow language, direct
Run button, visual regression, AI/cloud analysis, or custom E2E engine is included.

## Complex example coverage

The account overview links to a [UI laboratory](example/lib/showcase.dart):

| Screen | Scenarios | Verified boundary |
| --- | --- | --- |
| Animation lab | Slide/scale, animated size/color, cross-fade, bounded loading, expansion | Finite animations record/replay; not a claim about indefinite animations |
| Repeated controls | Two Continue buttons and identical icon types in keyed cards | Unique ancestor scoping; no positional selector fallback |
| Forms and overlays | Validation, text entry, dropdown, modal sheet, information dialog | Input references and overlay-specific screenshot names |
| Account settings | Switch/checkbox tiles, confirmation dialog, snackbar, long list | Stable-target scrolling and supported tap actions |

See [example instructions](example/README.md) for a reproducible walkthrough and
the [recorded complex journey](example/patrol_recorder/complex_ui.yml). This expands
test coverage; it is not proof that every Flutter/custom/native widget is supported.

The [async flow](example/patrol_recorder/async_flow.yml) demonstrates an inline
Terms link, a looping animation, delayed local readiness, a lazy paginated picker,
scrolling to Option 24, a long press, an explicitly named `async_loaded` screenshot,
and outcome assertions. Its delayed work is implemented with local `Future.delayed`
fixtures; it makes no network calls and does not demonstrate interception of
arbitrary application futures.

## Maintain the recorder package

From this repository root:

```sh
dart format lib test
flutter analyze lib test
flutter test
cd tool/patrol_recorder_generator
flutter pub get
dart format lib bin test
flutter analyze
flutter test
cd ../devtools_extension
flutter pub get
dart format lib test tool
flutter analyze
flutter test
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
cd ../../example
flutter pub get
flutter analyze
flutter test
```

Also verify a real named recording -> YAML -> CLI generation -> implemented inputs
-> Patrol run. Unit tests/builds alone do not establish that entire workflow.
The [generator package guide](tool/patrol_recorder_generator/README.md) documents
the CLI, and the [implementation plan](docs/PHASE_1_PLAN.md) records staged evidence.

## Publication status

Publication remains disabled (`publish_to: none`). No package/release was published.
The provisional names, support metadata/issue tracker, platform matrix, archive
inspection, and pub.dev readiness still require work. Original code is
BSD-3-Clause; dependency/licensing considerations are documented in the plan.
