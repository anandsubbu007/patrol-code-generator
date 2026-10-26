# Patrol Recorder

Record a Flutter journey into **YAML**, generate ordinary **Patrol Dart tests**,
and supply dynamic values through your own **Dart input implementation**.

```text
DevTools Record -> patrol_recorder/<journey>.yml
                         |
              dart run patrol_recorder_generator:generate
                         |
              Patrol steps + abstract inputs
                         |
              your input implementation -> Patrol CLI
```

No recording calls are needed in application button/text-field callbacks.
Recording setup stays in a test-only entrypoint, not application `lib/`.
This is an **experimental project**, not a universal or production-certified
recorder. The recorder is published on pub.dev; this checkout targets recorder
and generator 0.0.6. Check both package pages before installing. The tested local environment was Flutter
3.47.7 / Dart 3.13.5, DevTools 2.60.0, Patrol 4.10.0, Patrol CLI 4.8.0, Node
22.23.4, and Flutter web.

## At a glance

- Observe supported Flutter controls without adding recording callbacks.
- Save editable-test source as named YAML journeys; text values become typed
  input references, never recorded credentials.
- Generate ordinary Patrol code with the development-only
  `patrol_recorder_generator` companion.
- Keep your input providers, setup, and outcome assertions when regenerating.
- Capture visible Flutter screens with masking for marked private regions.
- Pick a widget in DevTools and save bounded expectations with editable text suggestions.
- Author schema-5 cases, typed fixture profiles, setup/groups, assets, and selector overrides.

This is a Flutter package, not a plain-Dart package or native plugin. Its runtime
uses Flutter widgets, rendering, and `dart:ui` APIs, so it cannot run in a
standalone Dart VM without Flutter. Package metadata does not declare a
platform allowlist: the complete recording/replay workflow has only been
verified on Flutter Web in Chrome-compatible browsers, and Android, iOS, Linux,
macOS, and Windows end-to-end behavior remains unverified. This avoids implying
that the package is Web-only while also avoiding an unverified all-platform
claim. Native dialogs and arbitrary custom gestures are not supported. Do not
infer end-to-end verification from Flutter or Patrol's platform coverage.
Recording requires debug mode; keep the generator and Patrol as dev dependencies.
The recorder can also be dev-only when imported only by a recording entrypoint
outside application `lib/`.
Patrol Recorder is an independent project, not an official Patrol product.

## Screenshots and demo

These are real captures of the local example using fictional data, not mockups.

![Connected Patrol Recorder DevTools panel](doc/images/recorder.png)

| Start a journey                              | Reach an outcome                                 |
| -------------------------------------------- | ------------------------------------------------ |
| ![Demonstration login](doc/images/login.png) | ![Demo account overview](doc/images/account.png) |

![Repeated controls requiring scoped selectors](doc/images/repeated-controls.png)

![M2 fixture and expectation lab with fictional data](doc/images/fixture-lab.png)

See the [demo walkthrough](doc/DEMO.md) for media, capture instructions, and the
record -> YAML -> generate -> replay script. Screenshots are optional; a video
is not a pub.dev publication requirement.
The refreshed [10-second example video](https://github.com/anandsubbu007/patrol-code-generator/blob/main/doc/media/example-walkthrough.webm)
shows login and the fixture lab in the real app. It is an app walkthrough, not
a video of DevTools, generation, or Patrol execution.

## Runnable M2 example

The [fixture lab](example/lib/fixture_lab.dart) is available after **Open demo
account** under **Fixture and expectation lab**. Load/clear a fictional customer
manually, or replay the maintained [schema-5 journey](example/patrol_recorder/m2_fixtures.yml).
Its `populated` and `empty` cases apply real JSON/text fixtures through a
[user-owned adapter](example/patrol_test/m2_fixture_adapter.dart), then verify
exact text, credit, enabled state, and repeated-item counts.

After repository setup, run from `example/`:

```sh
dart run patrol_recorder_generator:generate --journey m2_fixtures --preview
dart run patrol_recorder_generator:generate --journey m2_fixtures --inspect-selectors
dart run patrol_recorder_generator:generate --journey m2_fixtures
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/populated/populated_test.dart --device chrome --web-headless
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/empty/empty_test.dart --device chrome --web-headless
```

Both checked-in case providers are implemented and both Patrol web replays passed.
The cases use their own default profile; do not force `RECORDER_PROFILE=demo`
onto the `empty` case. Regeneration preserves the maintained providers/wrappers.
See the [M2 walkthrough](example/README.md#m2-fixtures-and-expectations) for file
locations, safe asset paths, types, setup/groups, overrides, and expectation picking.
Advanced fixtures/cases are authored in stopped YAML; they are not auto-recorded
from private input values or created by a DevTools case editor.

## Install from pub.dev

For the 0.0.6 release, publish the recorder first and the generator second.
After both package pages list 0.0.6 or a later compatible version, add
them with a range that accepts patch releases without allowing 0.1.0:

```sh
flutter pub add --dev 'patrol_recorder:>=0.0.6 <0.1.0' 'patrol_recorder_generator:>=0.0.6 <0.1.0' 'patrol:4.10.0'
dart pub global activate patrol_cli 4.8.0
```

If application widgets import recorder APIs (for example `RecorderSensitive`),
put **only the recorder** in regular dependencies instead:

```yaml
dependencies:
  flutter:
    sdk: flutter
  patrol_recorder: '>=0.0.6 <0.1.0'
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol_recorder_generator: '>=0.0.6 <0.1.0'
  patrol: 4.10.0
```

The ranges deliberately start at 0.0.6, so they do not silently install
older releases that require Dart 3.13.
Run `flutter pub get` after adding them and confirm the resolved versions.

The recorder has only the Flutter SDK as a direct runtime dependency. The
generator owns `analyzer`, `dart_style`, `yaml`, and `args`. These are regular
dependencies of the tooling package so its CLI works for consumers, but the
tooling package itself is an app **dev dependency**. Moving code out of `lib/`
alone would not provide this separation.

Recorder, generator, and example require **Dart >=3.8.0 <4.0.0 and
Flutter >=3.32.0**, including Flutter/Dart releases using Dart 3.11.
The generator allows `dart_style ^3.1.2` and `analyzer >=8.0.0 <15.0.0`;
Pub selects versions compatible with your SDK instead of requiring the newest
analyzer/formatter. Do not copy this repository's lockfiles or local overrides
into another app. After upgrading, run `flutter pub upgrade patrol_recorder
patrol_recorder_generator` to refresh an existing app's resolution.

Building the DevTools extension **from source** requires Dart >=3.9.0 <4.0.0
and Flutter >=3.35.0 for its dropdown APIs. Consumers receive the compiled
extension and do not need that source-build toolchain. Full recording/replay
evidence remains the Flutter 3.47.7 / Dart 3.13.5 Web run, not proof of every
DevTools host or platform on older SDKs.
Package analysis/tests cover Flutter 3.32.0 / Dart 3.8.0, Flutter 3.41.0 /
Dart 3.11.0, and Flutter 3.47.7 / Dart 3.13.5. Generated replay code uses
semantics APIs shared by these SDKs. Regenerate owned steps after upgrading;
your input providers and wrappers remain untouched.

Node.js is used by Patrol's web test tooling, not
declared by this package. Node 22.23.4 completed the recorded clean web setup.
An earlier clean Playwright browser installation stalled under Node 26.12.0;
the current audit host replayed with its existing local browser dependencies,
which does not prove a clean Node 26 setup. Use Node 22.23.4 for reproducible
first-time validation. Once both packages are published, users receive the
compiled DevTools extension with the recorder; no repository clone or extension
build is needed.

1. Add a [recording-only entrypoint](#use-in-your-own-app) wrapping your root
   widget with `RecorderScope`.
2. Run `flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd`.
3. Open the printed DevTools URL, enable **patrol_recorder**, record a named
   journey, stop it, and review its actions.
4. Run `dart run patrol_recorder_generator:generate --journey login` in the app.
5. Implement the generated input getters, add business assertions, and run the
   test with Patrol CLI, not `flutter test`.

The [example](example/README.md) includes a runnable app, recording entrypoint,
saved YAML, generated steps, and fictional input implementations.

## Guide

1. [Setup and record](#setup-and-record)
2. [Generate Patrol code](#generate-patrol-code)
3. [Implement dynamic inputs](#implement-dynamic-inputs)
4. [Run the tests](#run-the-tests)
5. [Re-record and maintain journeys](#re-record-and-maintain-journeys)
6. [Configuration and screenshots](#configuration-and-screenshots)
7. [Use in your own app](#use-in-your-own-app)
8. [Limits and troubleshooting](#limits-and-troubleshooting)
9. [License and support](#license-and-support)
10. [Publishing checklist](doc/PUBLISHING.md)

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

### 1. Repository development: install and build

Use a Flutter-supported Chrome-compatible browser and Node 22.23.4 on PATH for
the documented first-time Patrol web setup. Check `flutter doctor`,
`flutter devices`, and `node --version`.

From this repository root:

```sh
flutter pub get
dart pub global activate patrol_cli 4.8.0
cd tool/patrol_recorder_generator
flutter pub get
cd ../..
cd tool/devtools_extension
flutter pub get
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
cd ../../example
flutter pub get
```

These commands finish in the example app. The extension uses packaged local
CanvasKit assets, not a renderer CDN. The example declares both local packages
as dev dependencies. A local override resolves the generator's hosted recorder
dependency to the same checkout. The published runtime recorder does not depend
on the generator or formatter/analyzer/YAML packages.

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

### Add an expectation

During recording, click **Add expectation**, then tap a widget in the running
Flutter app. The selection tap does not activate the control or record a tap.
Review its stable selector, choose an expectation and timeout, then click
**Save expectation**. Cancel adds nothing. Selection expires after two minutes;
private/ignored regions and unresolved targets cannot be confirmed. Rebuild the
DevTools extension and restart the app when updating to protocol 7.
**Exact text** is prefilled when the selected target contains exactly one public
text leaf. The suggestion remains editable; switching expectation kinds preserves
your text and count independently. Editable values and private content are never
used as suggestions. **Match count** starts at one for the uniquely selected target.

Schemas 4 and 5 accept manually authored assertions (edit only after stopping):

```yaml
- id: account_ready
  action: expect
  source: authored
  include: true
  target:
    key: account_title
  expectation:
    kind: text
    value: Account overview
    timeout_ms: 10000
```

Supported kinds: `exists` (exactly one match), `absent` (zero matches), `visible`
(one hit-testable match), `text` (one target containing exactly one matching
Text/RichText, including the target itself), and `count` (a nonnegative integer).
Only `text` and `count` take `value`. Text is an exact, nonempty string of at most
1000 characters, supplied explicitly, never read from editable fields. Do not put
secrets in expected text. Timeout defaults to 10000 ms and must be 100-120000 ms.
Generated checks poll without settling until satisfied or timed out; `absent`
means absent at a check, not continuously absent over the whole timeout.
Missing, unsupported, or misplaced expectations fail validation rather than
being skipped. Count assertions may deliberately match multiple widgets.

Schema 5 also supports fixture `asset` steps, multiple cases, reusable groups/setup,
typed input profiles, and selector overrides. See the
[authored journey guide](tool/patrol_recorder_generator/README.md#authored-journeys).
The picker authors expectations only; edit advanced journeys after stopping.

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
The recorder does not capture typed field values. Schema 5 permits manually
authored, non-secret fixture values with explicit types. Password/secret literals,
arbitrary expressions, and coordinate selectors are not supported.
`secret: true` classifies a reference; it is not a value.
New recordings use schema 5; the generator continues to read schemas 1-4.

Targets prefer keys, then semantics identifiers/labels, field labels/text, then
supported public widget types. A tap on text or an icon is attributed to the
enclosing interactive widget (`onTap`/`onPressed`/`onLongPress`), and that
widget's key is used. Keys on wrappers are used too, for example
`AppButton(key: ...)` building `Padding(InkWell(...))`, when the wrapper
contains no other interactive widget and its center lands on the tapped
control. Keys of nested controls (such as a trailing `IconButton` in a
`ListTile`) are never used for the outer action. Text is used only when no key
identifies the action. Repeated targets can use a unique ancestor
`within` scope. Ambiguous actions retain a review reason rather than selecting
`.first` or an index. The generated test asserts a single match before acting.

## Generate Patrol code

From the app directory:

```sh
# Choose a journey or another action interactively in a terminal.
dart run patrol_recorder_generator:generate

# Generate all *.yml journeys without the menu.
dart run patrol_recorder_generator:generate --all

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
Without `--journey`, a terminal menu offers single/batch generation, preview,
selector inspection, reset, re-recording guidance, and cancellation. Validation
failures return to the menu so you can choose another journey. Empty or missing
recordings folders show guidance instead of failing immediately.

Reset lets you choose YAML only, YAML plus referenced screenshots, or both plus
generated journey files **including user-owned inputs and tests**. It lists exact
files and requires typing `DELETE`; fixture assets, unreferenced captures,
unrelated files, and directories are preserved. Malformed YAML supports YAML-only
reset; repair it before resetting associated files. Stop recording before reset,
then record again in DevTools. The generator does not record or execute tests.

`--all` bypasses the menu. Redirected input, `CI=true`, and `--no-interactive` retain
unattended batch behavior; `--interactive` explicitly enables prompts.
Use `--journey` or `--all` with `--inspect-selectors` for JSON without menu text.
Batch generation includes older `.yml` recordings in the configured
directory. Validation errors list invalid journeys and missing screenshot paths,
and no output is written for a failed batch. Restore captures or re-record the
affected journey; screenshot paths are relative to the app project and changing
`screenshots_directory` does not update existing YAML. Errors list valid journey
names when available so you can select one with `--journey <name>` instead.

Default output:

```text
patrol_test/recorded_journeys/login/
  login_test.dart
  login_inputs.dart
  login_inputs.g.dart
  login_steps.g.dart
```

| File              | Ownership                                                              |
| ----------------- | ---------------------------------------------------------------------- |
| `*_inputs.g.dart` | Generated abstract `JourneyInputs` contract and validation             |
| `*_steps.g.dart`  | Generated normal Patrol actions, current test name and case tag        |
| `*_inputs.dart`   | One-time user implementation scaffold; **never overwritten**           |
| `*_test.dart`     | One-time Patrol entrypoint for setup/assertions; **never overwritten** |

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
official Node/Playwright dependencies. Use Node 22 directly on PATH; do not wrap
Patrol in `npx --call`.

Run individual generated tests through Patrol CLI with `--target`, not VS Code's
standard **Run Test / Debug Test** buttons or direct `flutter test`. Patrol CLI
initializes the app service required by `patrolTest`; bypassing it can cause
`LateInitializationError: Field 'patrolAppService' has not been initialized`.
Widget tests in `test/` still use the normal Flutter test runner.

In VS Code, run these commands in the integrated terminal or configure your own
task invoking Patrol CLI with the app directory as its working directory. This
package does not install IDE tasks or replace the standard test runner.

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

The following dependency setup is for after recorder and generator 0.0.6 are
published. Check both package pages first; a hosted recorder alone does not
make the complete workflow installable from pub.dev.

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol_recorder: '>=0.0.6 <0.1.0'
  patrol_recorder_generator: '>=0.0.6 <0.1.0'
  patrol: 4.10.0

patrol:
  test_directory: patrol_test
```

If application `lib/` imports recorder widgets, move `patrol_recorder` to
`dependencies`, keeping the generator under `dev_dependencies`.
For unpublished repository development use the two local paths and recorder
override shown in the example pubspec. Only source contributors need to build
the extension.

Create `patrol_test/recorder_main.dart`:

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

### Public API

Import `package:patrol_recorder/patrol_recorder.dart` only from your debug
recording entrypoint:

| API                                          | Purpose                                                                         |
| -------------------------------------------- | ------------------------------------------------------------------------------- |
| `RecorderController()`                       | Owns a recording's state and automatic observations; default limit is 500 steps |
| `RecorderScope(controller: ..., child: ...)` | Wraps the app root and installs debug observation/capture                       |
| `RecorderSensitive(child: ...)`              | Marks a subtree for screenshot masking; interactions may still be observed      |
| `RecorderIgnore(child: ...)`                 | Excludes subtree interactions and masks its screenshot region                   |
| `controller.state`, `steps`, `error`         | Inspect recording status, read-only actions, and visible failure state          |
| `controller.start()`, `stop()`               | Programmatic lifecycle; normally driven by the DevTools panel                   |
| `controller.dispose()`                       | Releases controller resources when its owner no longer needs it                 |

The separate `package:patrol_recorder_generator/generator.dart` library exposes YAML
journey parsing, generation, and workspace export contracts for tool integrations.
Normal users should invoke `dart run patrol_recorder_generator:generate`; importing the
app-side recorder library does not import the generator or its filesystem CLI.

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

YAML schemas 1-4 remain readable with their original compatibility behavior;
new recordings use schema 5 without `app`/`session_id`. If an old recorder configuration deliberately
selected a custom factory, move that selection into pubspec before re-recording.
Do not assume arbitrary app-specific initialization can be inferred automatically.

## Limits and troubleshooting

| Symptom                                | Action                                                                                                                                                                                |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Extension missing/unavailable          | Build/copy/validate extension assets; run the debug recording entrypoint; enable the real DevTools extension                                                                          |
| Protocol mismatch                      | Restart the recording app and reload rebuilt DevTools assets; runtime protocol is 7, new YAML schema is 5                                                                             |
| No destination                         | Refresh authorized projects using a Flutter/IDE DTD session; never use an unrestricted daemon                                                                                         |
| YAML NOT UP TO DATE                    | Keep the draft open; resolve permissions/concurrent edits and Retry YAML save                                                                                                         |
| App restarted or browser closed        | Last persisted YAML survives. Re-record the same name if the source remains unfinished; do not treat an interrupted flow as complete                                                  |
| Generator rejects active recording     | Stop in DevTools and verify the source is saved as stopped                                                                                                                            |
| Unknown/ambiguous target               | Add a stable key/ancestor, re-record, or explicitly exclude an unnecessary action; never use `.first`/coordinates as a silent fix                                                     |
| Scroll/long press/custom/native action | Flutter scrollables and identifiable long-press targets are observed; unsupported custom/native gestures remain review-required. Add unique stable keys and check the recorded target |
| Missing input getter/value             | Implement the abstract contract in the preserved input file; the YAML intentionally contains no values                                                                                |
| Existing generated file not recognized | Use a new journey name or reconcile the file manually; handwritten output is not overwritten                                                                                          |
| Duplicate test execution               | Keep only actual tests named `*_test.dart`; do not import discoverable tests from another discoverable entrypoint                                                                     |

Ordinary pointer taps are candidates, not callback-success proof. Accessibility
events are requests before dispatch. Field notifications can include selection,
composition, or programmatic changes; the recorder does not read/retain raw text
to distinguish them. It records reference-only field activity.

### Scrolling, links, and asynchronous UI

The recorder observes drag, wheel, pan/zoom, accessibility scrolling, and standard
Flutter scroll-position changes, including when an ancestor consumes scroll
notifications. Scrolling is recorded as an objective, not a pixel offset.
Consecutive scrolls of one view (including searching back and forth) collapse
into one step with the net direction. Scrolling away and back records nothing.
An action inside the scrolled view, such as a tap, becomes the scroll's
destination. Otherwise the furthest visible keyed item or unique text is used.
If the scroll view itself has no unique key, the step omits `scroll_view` and
replay finds the Scrollable from the destination. If neither the view nor any
destination can be identified, the step needs review until you tap the intended
item or add a key.

Replay (`_recorderScrollTo`, a bounded `scrollTo()` used before `tap()`) works
on any screen size. A destination that is already built is revealed with
`ensureVisible`. Otherwise the recorded view (or, without a view key, each
current-route Scrollable on the recorded axis, largest first) is dragged in
steps of 30% of the viewport toward the recorded direction. At the scroll
extent it waits for paged content, then sweeps back the other way. A drag the
view absorbs falls back to a programmatic scroll. A unique key on the
`ListView`, `GridView`, or other `ScrollView` and on intended list items still
improves identity. `max_scrolls` (scrolls per sweep) defaults to 60
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

| Screen             | Scenarios                                                                | Verified boundary                                                        |
| ------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| Animation lab      | Slide/scale, animated size/color, cross-fade, bounded loading, expansion | Finite animations record/replay; not a claim about indefinite animations |
| Repeated controls  | Two Continue buttons and identical icon types in keyed cards             | Unique ancestor scoping; no positional selector fallback                 |
| Forms and overlays | Validation, text entry, dropdown, modal sheet, information dialog        | Input references and overlay-specific screenshot names                   |
| Account settings   | Switch/checkbox tiles, confirmation dialog, snackbar, long list          | Stable-target scrolling and supported tap actions                        |

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
The [generation guide](#generate-patrol-code) documents the companion CLI.
Historical implementation notes remain in the source repository.

## License and support

Original code is licensed under [BSD-3-Clause](LICENSE), including the companion generator.
Redistributions must retain the copyright notice, license conditions, and
disclaimer; the license does not grant endorsement rights. Bundled third-party
extension assets retain their own licenses in
[`extension/devtools/build/assets/NOTICES`](extension/devtools/build/assets/NOTICES).
Patrol and Flutter are separate projects with their own licensing.

Report bugs and feature requests in the
[issue tracker](https://github.com/anandsubbu007/patrol-code-generator/issues).
Include Flutter/Dart, DevTools and Patrol versions, browser, sanitized YAML,
reproduction steps, and the complete error. Remove credentials, screenshots of
private content, and authenticated VM Service/DTD URLs before sharing.
See [CONTRIBUTING.md](CONTRIBUTING.md) for checkout setup, checks, and pull
request guidance.

## Publication status

This checkout prepares recorder and generator **0.0.6** for publication. The
release order is recorder first, then generator; after both uploads, confirm
the hosted package pages and run the clean consumer workflow. The repository
example uses local path dependencies; that validates local development, not
hosted installation.
Version 0.0.3 remains an immutable published release with its original
documentation and six declared Flutter targets. Version 0.0.6 does not declare
a platform allowlist; end-to-end verification remains Web-only. See the
[release checklist](doc/PUBLISHING.md) for the ordered release and validation
steps.
The example and extension source app intentionally remain unpublished.
