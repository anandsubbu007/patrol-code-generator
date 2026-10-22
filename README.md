# Patrol Recorder

An **unpublished automatic-recording prototype**: one test-only Flutter entrypoint
-> a real DevTools extension -> editable Patrol Dart/data files and screenshots.
No recording calls are needed in button or text-field callbacks.

Tested toolchain: Flutter 3.47.7 / Dart 3.13.5, DevTools 2.60.0, Patrol 4.10.0,
Patrol CLI 4.8.0, Node 22.23.4. Start with the [runnable example](example/README.md).

## What this milestone provides

- Debug-only passive tap candidates, accessibility tap requests, and focused
  standard-text-field activity. No callback replacement or gesture interception.
- Key-first automatic selectors with uniquely identified ancestor scopes.
  Ambiguity blocks export; no coordinate or positional-index fallback.
- A minimal extension with Start, Stop, observed steps, generated Dart/data preview,
  profile selection, Flutter-content screenshot preview, safe DTD export, and
  Copy Run Command.
- Separate human-editable Dart profile files and external secret references.
- Independently discoverable generated test files; no duplicate suite entry point.
- A sample login form and account navigation with two generated example targets.

Pause/resume, full editing, groups/case management, saved-session reopening,
native-device screenshots, direct Run, and runner-result ingestion
are **not implemented**. See the [implementation plan](docs/PHASE_1_PLAN.md)
for the approval-gated remaining milestones.

## Build and use

```sh
flutter pub get
cd tool/devtools_extension
flutter pub get
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
cd ../../example
flutter pub get
flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd
```

Open the printed **DevTools** URL, enable the `patrol_recorder` extension when
prompted, and follow the [recording walkthrough](example/README.md#record-a-journey).
This uses actual DevTools, not `use_simulated_environment`.

The extension ships local CanvasKit assets using the documented Flutter loader
configuration. It does not require a CDN for its renderer.

## One test-only entrypoint

Keep recording setup and public test defaults outside application `lib/`.
The example uses [patrol_test/recorder_main.dart](example/patrol_test/recorder_main.dart)
and [patrol_test/demo_profiles.dart](example/patrol_test/demo_profiles.dart).
Its normal [main entrypoint](example/lib/main.dart) and [app](example/lib/app.dart)
have no recorder imports, test profiles, or recording callbacks.

In a dedicated debug recording entrypoint:

```dart
final recorder = RecorderController(
  config: RecorderAppConfig(
    appImport: 'package:your_app/app.dart',
    appBuilder: 'createApp',
    safeProfiles: demoProfiles, // Imported from your test directory.
  ),
);
runApp(RecorderScope(controller: recorder, child: createApp()));
```

Add the recorder as a `dev_dependency`. The recording entrypoint filename must not
end with `_test.dart`, so Patrol does not discover it as a test.
Run the ordinary application with `flutter run`; run the dedicated entrypoint to
enable the recorder. The original `recordTap`/`recordText` APIs were removed.

Selectors prefer exact `ValueKey<String>`, semantics identifier, semantics label,
text-field decoration label, visible `Text`, then supported public widget type.
Duplicate labels/types/keys can use a unique keyed/identified ancestor. Generated
tests wait for existence and assert a single match before each action. A target
without a unique selector stays unresolved; add a stable key/parent and re-record.
There is no automatic `.first`, index, or x/y action generation. Pointer positions
are used only transiently to discover the touched widget, never serialized.

Supported automatic controls are standard Material buttons, icon/floating action
buttons, `InkWell`, tap `GestureDetector`, and standard `TextField`/`EditableText`.
Custom subclasses without stable metadata, native UI, scrolling and long presses
are not generalized here. Unsupported gestures produce a visible blocking error;
disabled/ignored controls and cancelled gestures are excluded.

Pointer gestures are inferred, not callback-success evidence. Accessibility events
are requests before dispatch. Focused controller notifications include typing,
selection/composition changes and programmatic writes; the recorder intentionally
does **not read or retain text** to distinguish them. It records a coalesced field
activity reference, not a claim that every notification is a user edit. Review
references and edit the separate data file before running. A valid string key
becomes the input name; other fields receive names such as `input_0001`.
Missing profile values fail explicitly until filled in the data file.

Provide a public, no-argument widget builder and its package import in
`RecorderAppConfig`. Do not pass arbitrary code to the generator. `safeProfiles`
is explicitly authored **public test-default data**, never live captured input or
real account credentials. Use only fictional/approved non-sensitive values.

## Privacy and screenshots

- Profile values are non-secret defaults. Passwords/tokens use named external
  references. Raw typed input is not buffered, logged, or sent over VM Service.
- `RecorderSensitive` blocks capture while its subtree is mounted. Wrap every
  non-obscured sensitive area; the recorder cannot detect secrets drawn elsewhere.
- `obscureText` automatically selects secret references and blocks capture.
  `RecorderIgnore` excludes subtree interactions and blocks screenshots while
  that subtree is present. These annotations are optional; the example's standard
  password field needs neither annotation nor a recorder import.
- The example deliberately hides input values on its account page.
- Capture is explicit, after stopping, and limited to the Flutter subtree:
  **no system keyboard, notifications, OS dialogs, or guaranteed platform views**.
- PNG transfer is capped at 4 MiB and capture at 8 megapixels; failures are explicit.
- No analytics, cloud service, visual comparison, or custom E2E runner is added.
  DevTools/Flutter retain their own host telemetry settings.

## Output and execution

```text
recorder_config.yaml
patrol_test/recorded_journeys/
  login/
    login_test.dart
    login_data.dart
    screenshots/<session-id>_step-0003_flutter.png
    recording.json
  accounts/
    accounts_test.dart
    accounts_data.dart
```

The two sample targets are generated from explicit demonstration steps, not
misrepresented as a saved manual recording. The additional
[browser_verified journey](example/patrol_test/recorded_journeys/browser_verified/)
was actually recorded and exported through real DevTools. All three use the same
generator family and passed through the official Patrol web runner. They preserve
the historical M1 proof. New protocol-v2 automatic output is saved separately in
[automatic_verified](example/patrol_test/recorded_journeys/automatic_verified/).

DTD export is restricted to the selected authorized project on the **DTD host**,
which may be remote. The extension cannot choose arbitrary local paths. Export
refuses existing Dart/data/PNG/metadata files; choose a new journey ID. An existing
project `recorder_config.yaml` is preserved. When multiple authorized projects are
listed, explicitly select the app project before saving. Use **Load recorder_config.yaml** to
apply its defaults.

Files are preflighted and checked again immediately before writing. Text is read
back exactly. PNG writes are acknowledged and their existence checked; the current
DTD host ignores read encoding and cannot read arbitrary PNG bytes. The integration
proof independently checks PNG bytes on the host. This limitation is shown in the
save result, not hidden. DTD has no exclusive-create/multi-file transaction: do not
edit the destination concurrently. Failures are shown and may leave partial output;
inspect the destination before choosing a new journey ID.
No existing files are automatically deleted. Symlink/race-hardening and retry UX
remain M4 gates; use a fresh, non-symlinked project subdirectory for M1.

Patrol launches its own test application. The recording connection is not assumed
to survive. Copy the displayed command and run it in the selected project terminal.
Results remain in that terminal/Patrol output; there is no automatic result feed.

## Validation

```sh
flutter analyze lib test
flutter test
cd tool/devtools_extension
flutter analyze
flutter test
cd ../../example
flutter analyze
flutter test
```

For current automatic-recording evidence and limitations see the
[updated plan](docs/PHASE_1_PLAN.md#automatic-implementation-results).
The [Milestone 1 report](docs/MILESTONE_1_RESULTS.md) is historical.

## Publication status

Publication is deliberately disabled (`publish_to: none`). The provisional package
name and `example.invalid` extension issue-tracker URL must be replaced/approved
before publication. The latter is a visible placeholder, **not** a real support
endpoint. No package has been published.

Original code is BSD-3-Clause; dependency licences and remaining packaging gates are
documented in the [plan](docs/PHASE_1_PLAN.md).
