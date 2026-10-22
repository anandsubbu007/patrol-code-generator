# Patrol Recorder: research and implementation history

This document preserves the original research, design decisions, and detailed
implementation evidence. It is not the current task list. See the
[roadmap](ROADMAP.md) for current status, milestones, and open todos, and the
[integrated proof report](INTEGRATED_PROOF_RESULTS.md) for the initial real-host proof.

**Record date:** 22 October 2026. **Publication status:** unpublished.

This is an archival record of research, design, and successive implementation
snapshots, not the current todo list. Later sections supersede earlier proposals
where they describe implemented behavior. See the [roadmap](ROADMAP.md) for
current status and open work, and the [integrated proof report](INTEGRATED_PROOF_RESULTS.md)
for the initial real-host verification.

## 1. Recommendation and scope

Build a small, opt-in **in-app Flutter recorder**, a **Flutter web DevTools extension**, and a **deterministic Patrol Dart generator**. Use the existing Dart Tooling Daemon (DTD) for permitted workspace export. Add a narrowly scoped, optional host-side screenshot adapter only for device captures that Flutter cannot provide.

The product records and edits interactions and captures screenshots. **Patrol remains the execution foundation.** Exported tests must run without the recorder or extension installed.

The repository was an empty directory at initial inspection. The first research
delivery added only this plan; its experiments ran in an isolated session directory.
The subsequently approved M1 implementation now provides the package, extension,
example, and tests. Section 2 preserves the initial research evidence; the separate
[integrated proof report](INTEGRATED_PROOF_RESULTS.md) documents the original implementation.

### In scope

- Start, Pause, Resume, and Stop/Save in a DevTools extension.
- Live interaction timeline with capture provenance and confidence.
- Supported Flutter taps, long presses, text entry, scrolling, and navigation observations.
- Inspectable selector candidates, automatic selection, and manual overrides.
- Multiple dynamic inputs, named variables, explicit custom values, and secret references.
- Dart preview beside the timeline, regenerated after valid edits.
- Flutter-content screenshots and clearly separate full-device screenshots where supported.
- User-configured output destinations through supported export mechanisms.
- Dart files, PNGs, and optional sanitized, machine-generated session metadata.
- Edit, delete, reorder, and manually re-record steps.
- A sample application, automated tests, documentation, and pub.dev packaging readiness.

### Explicit non-goals

No Git branch/tag/commit or release management; release-to-release comparison; screenshot diffing, pixel comparison, or visual regression; behavioral comparison or change insights; AI analysis; cloud services; Maestro integration; or custom E2E execution engine.

No promise of zero-instrumentation recording, automatic assertion inference, arbitrary native UI recording, or arbitrary local filesystem access.

## 2. Initial research evidence (before M1 implementation)

### Environment and tested dependency combination

| Component | Version used |
| --- | --- |
| Flutter / Dart | 3.47.7 stable / 3.13.5 |
| Bundled DevTools | 2.60.0 |
| Host | macOS 27.0.1, arm64 |
| `devtools_extensions` / `devtools_app_shared` | 0.5.1 / 0.5.1 |
| `devtools_shared` / `dtd` | 13.1.0 / 4.0.0 |
| `vm_service` / `web` | 15.4.0 / 1.1.1 |
| `patrol` / `patrol_finders` | 4.10.0 / 3.6.0 |

These versions resolved together without dependency overrides. The DevTools dependency range selects `devtools_shared` 13.x, not the newer incompatible 14.x. Published minimums are not the same as tested support.

### Experiment results

| Experiment | Result and boundary of the claim |
| --- | --- |
| Observe one Flutter interaction | **Passed.** `WidgetTester.tap` drove a real Flutter button through the gesture system. A global pointer route saw down/up; an explicitly instrumented button callback recorded one confirmed tap and the counter changed once. This was injected test input, not a manual tap on a device. |
| VM Service communication | **Passed.** The running Flutter test isolate registered `ext.phase1_probe.snapshot`, posted `phase1_probe.step`, and a real WebSocket VM Service client received the extension event and queried the snapshot by isolate ID. |
| Generate valid Patrol Dart | **Passed.** The observed key produced a complete `patrolTest` file. `flutter analyze` reported no issues against Patrol 4.10.0. The same generated action executed successfully in a `patrolWidgetTest`. Native `patrol test` execution was **not** performed. |
| Flutter-content capture | **Passed.** A painted `RenderRepaintBoundary` produced an 800 x 600 RGBA PNG, 7,596 bytes. It was decoded/viewed and its file signature checked. It contains Flutter test-font rendering, not a device screen or system UI. |
| DTD export | **Passed.** A restricted, locally started DTD accepted Dart and PNG writes inside a configured workspace root, created a missing screenshot subdirectory, and returned identical Dart text on readback. PNG bytes were independently checked with host file access, not DTD binary readback. M1 subsequently found that the current DTD host ignores read encoding; see the results report. |
| Export permission negatives | **Passed.** DTD rejected writes before workspace roots were configured and rejected a path outside the allowed root with `kPermissionDenied`; the forbidden file was not created. Only the experiment's own daemon owner configured its roots. A production extension must not obtain the trusted-client secret or configure roots. |
| Observation negatives | **Passed.** Tapping a disabled button produced pointer events but no confirmed action. A test IME edit changed a text controller without producing pointer events. Pointer observation is therefore not a complete interaction recorder. |
| DevTools API compatibility | **Passed, compilation only.** A Flutter web probe using `DevToolsExtension`, `serviceManager.callServiceExtensionOnMainIsolate`, and `dtdManager.connection.value.writeFileAsString` built successfully. The build emitted a shared icon-font warning; asset/UI validation remains necessary. This was not installed and exercised inside real DevTools. |
| Browser filesystem constraint | **Passed.** In a secure localhost iframe configured with the current DevTools sandbox flags, `showSaveFilePicker` returned `SecurityError` after user activation expired. API existence does not grant silent file access. |
| Browser download fallback | **Not verified.** A Blob download was requested from that iframe, but the VS Code integrated-browser harness exposed no download artifact before timeout. Do not label browser export complete based on the click alone. |
| Full-device capture | **Not exercised.** No Android device/emulator or booted iOS simulator was available. `adb` and `simctl` exist, and `simctl io` documents screenshot-to-PNG/stdout support. Device capture is an explicit later gate. |

**Research-stage conclusion:** The primitive chain **observed interaction -> VM
event -> valid Patrol Dart -> saved Dart and Flutter screenshot** was proved in a
Flutter test harness. Actual DevTools embedding and a running-app recording were
then integrated and verified in M1, including official Patrol web execution.
Mobile/device-level execution remains unverified.

### Reproducibility and local evidence

The isolated harness is retained locally at:

```text
/Users/anandsubbu/.copilot/session-state/6c6347a5-aa4b-4fb7-a042-761a670c995a/files/phase1_probe/
  lib/probe_app.dart
  lib/extension_probe.dart
  lib/code_examples.dart
  test/observe_test.dart
  test/generated_replay_test.dart
  bin/export_probe.dart
  pubspec.yaml
  pubspec.lock
  output/observation.json
  output/export_result.json
  output/one_tap_test.dart
  output/one_tap.png
  exported/one_tap_test.dart
  exported/screenshots/one_tap.png
```

This is local experimental evidence, not a portable example application or a shipped SDK. The harness's private daemon and temporary HTTP server were stopped.

Core reproduction commands, from that directory:

```sh
flutter pub get
flutter test --enable-vmservice --no-dds test/observe_test.dart --reporter expanded
flutter test test/generated_replay_test.dart --reporter expanded
dart format lib test bin output
dart run bin/export_probe.dart
flutter analyze
flutter build web --target lib/extension_probe.dart --no-web-resources-cdn
```

The VM Service test registers its service handler in a real asynchronous zone, not the widget test's fake-clock zone, and uses a test-local HTTP override for its loopback WebSocket. Neither accommodation belongs in production recorder code.

Evidence SHA-256:

```text
Formatted one_tap_test.dart:
7141c10196a8eaa42caa7c914d79c461fa32482e84a1a265583d4744ea15d336

one_tap.png:
9d82f2a8c7c11ca95dfd6d744525622c0d9cba4b985a47702a71271a684ea7b4
```

## 3. Public packages and APIs evaluated

Versions and publication dates below were read from pub.dev's package API on the research date. Licences were checked in published licence pages or resolved package files. These are engineering suitability assessments, not legal certification.

| Package/API | Current evidence | Decision |
| --- | --- | --- |
| Flutter DevTools extensions | `devtools_extensions` 0.5.1, published 2026-05-04; BSD-3-Clause; Dart >=3.6, Flutter >=3.27.1. Public globals initialize under `DevToolsExtension`. [S1, S2] | Use. Ship compiled Flutter web assets and extension configuration with the runtime package; keep UI source/dependencies separate. |
| `devtools_app_shared` | 0.5.1 resolved with the extension package; BSD-3-Clause. Provides service management, DTD integration, and UI utilities. | Use only public exports. Do not import DevTools application internals. Account for the analytics-related transitive dependency during compliance review. |
| Dart `developer` / `vm_service` | `registerExtension`, `postEvent`; `vm_service` 15.4.0 published 2026-10-15, BSD-3-Clause, Dart ^3.5. Extensions are per isolate. [S3] | App uses `dart:developer`; extension uses its existing managed VM connection. Do not add a second debugger connection in the product. |
| DTD | 4.0.0 resolved; BSD-3-Clause. Public `writeFileAsString`, `readFileAsString`, workspace-root discovery; restricted to the daemon host's allowed workspace roots. [S4] | Primary workspace export. Text and byte-preserving Latin-1 PNG export experimentally verified. |
| Patrol | 4.10.0, published 2026-09-15; Apache-2.0; Dart >=3.8, Flutter >=3.32. [S5] | Generated tests depend on this, not the app recorder runtime. Use public `patrolTest` and `PatrolIntegrationTester` APIs. |
| Patrol finders | 3.6.0, published 2026-07-09; Apache-2.0. Accepts `Key`, `Symbol`, text, type, icon, and an ordinary Flutter `Finder`. [S6] | Use normal Patrol syntax. Semantics selectors work by wrapping Flutter finders; do not invent a Patrol semantics shorthand. |
| Patrol CLI | 4.8.0, published 2026-09-15; Apache-2.0. Official compatibility table supports the 4.10.0/4.8.0 pair. [S7] | Developer-run execution only. No recorder-specific test runner. |
| Flutter semantics | `SemanticsProperties.identifier`, `find.bySemanticsIdentifier`, `find.bySemanticsLabel`; identifier is not the accessibility label. [S8] | Prefer explicit stable identifiers when unique. Ensure semantics are active for semantics-based test finders. |
| Flutter observation | `PointerRouter.addGlobalRoute`, public hit testing, `TextEditingController`, `ScrollNotification`, `NavigatorObserver`. [S9] | Automatic app-level observers are the intended default; custom adapters are optional. No global public hook reports all recognized widget callbacks. |
| Maestro architecture (reference only) | Flutter support uses the system accessibility/semantics hierarchy, not Flutter keys. Studio documents inspecting an element and adding a command; this does not establish passive capture of every interaction performed outside Studio. Android hierarchy code exposes IDs, labels, bounds, and state. [S21-S23] | Adopt hierarchy-backed target discovery and contextual selectors as design ideas only. No Maestro dependency, integration, copied implementation, or replacement for Patrol. |
| Flutter screenshots | `RenderRepaintBoundary.toImage` after paint, followed by PNG encoding. [S10] | Use directly; no extra screenshot dependency needed for the baseline. |
| `gesture_recorder` | 0.3.2, published 2025-11-27; Apache-2.0. Public repository last source activity observed in November 2025. Records pointer packets, provides a DevTools UI and IDE export; no Patrol generation. [S11] | Prior art, not a dependency. Inspected source replaces `PlatformDispatcher.onPointerDataPacket` and contains a replay loop. Avoid callback replacement and its custom replay mechanism. Its inspected IDE helper also swallows export failures; do not copy that behavior. |
| `automated_integration_test` | 1.0.4, published 2025-03-27; claims automatic integration-test generation; MIT text retains `Copyright (c) 2024 [Your Name]`. Advertised repository could not be retrieved. [S12] | Reject as a dependency: provenance/maintenance uncertainty, contradictory zero-config/wrapping instructions, and no demonstrated Patrol/DevTools solution. Documentation claims were not treated as experimental proof. |
| `flutter_flight_recorder` | 0.0.7, published 2026-09-01; MIT; Flutter >=3.13, no non-SDK runtime dependencies. Explicit action recording and navigation observer; broader incident/logging scope. [S13] | Useful privacy/bounded-buffer prior art, not a dependency. It is not a Patrol interaction-to-code generator. |
| `screenshot` | 3.0.0, published 2024-05-14; MIT; Flutter >=3.22. Wraps `RenderRepaintBoundary`; does not grant device-wide capture. [S14] | Do not add for functionality already provided by Flutter. Age alone does not prove abandonment, but maintenance evidence is weaker than the SDK. |
| `file_selector` | 1.1.0, published 2025-11-21; BSD-3-Clause; Dart ^3.9, Flutter >=3.35. Web does not support its save-location or directory-picker APIs. [S15] | Not a solution for choosing arbitrary paths from a web extension. Consider only if a future native UI genuinely needs it. |
| `web` / browser File System Access | `web` 1.1.1, BSD-3-Clause; browser APIs require capabilities, permissions, and user activation. [S16] | For Blob/download fallback and optional feature-detected pickers, not unrestricted filesystem access. |
| `archive` | 4.5.2, published 2026-10-13; MIT; Dart >=3.0. [S17] | Candidate for a single ZIP download. Add only when implementing that fallback and validate its web build and dependency inventory. Not needed in the runtime. |

### Compatibility and enterprise policy

- Initial supported/tested development baseline: Flutter 3.47.7, Dart 3.13.5, DevTools 2.60.0, Patrol 4.10.0, CLI 4.8.0. Investigate a Flutter 3.32 lower bound separately; do not advertise it merely because Patrol permits it.
- Start with debug-mode Android/iOS recording. Desktop and web observation are candidates that need their own end-to-end validation, particularly web/DWDS and multi-view behavior. Profile/release recording is not supported initially.
- Prefer a BSD-3-Clause licence for original package code, subject to owner approval. Retain required upstream notices, including Apache notices where applicable. Do not copy existing recorder implementations.
- Inventory direct/transitive dependencies and compiled extension assets, their licences, provenance, known advisories, and maintenance ownership. A permissive licence is necessary but not sufficient for enterprise approval.
- Build the extension with local web resources; do not require a CDN or third-party runtime service. Inspect packaged assets and network traffic before approval.
- The package must not initiate telemetry or upload app data. The host DevTools/SDK has its own settings; do not claim control over host-wide telemetry. Audit reachable analytics dependencies and ensure recorder data never enters them.
- Use loopback-only existing tooling connections, preserve VM authentication, and never expose VM/DTD URIs, authentication tokens, input values, or screenshots in diagnostics.

## 4. Proposed architecture

```text
Developer's debug Flutter app
  RecorderScope + one-time debug initialization
  |-- passive pointer / accessibility / scroll observations
  |-- bounded element + semantics target discovery
  |-- automatic focused standard-text-field observation
  |-- optional navigation observer / custom-control adapters
  |-- source-side redaction + bounded session buffer
  `-- RepaintBoundary Flutter-content capture
           |
     dart:developer service extensions + Extension events
           |
DevTools Flutter web extension
  |-- managed VM connection and isolate lifecycle
  |-- session controller / capability handshake
  |-- timeline + step/selector/input editor
  |-- deterministic Dart generator + side-by-side preview
  `-- explicit export coordinator
           |
           +-- managed DTD -> permitted workspace files
           +-- browser download/ZIP -> browser-selected destination
           `-- optional DTD screenshot provider
                   -> allowlisted adb/simctl capture on developer host

Developer runs exported files using Patrol CLI.
There is no execution/replay engine in the recorder.
```

### Package boundaries

1. **Published runtime package:** Flutter-only recording adapters, protocol/model definitions, debug-only initialization, and the prebuilt extension assets. No `flutter_test`, Patrol, UI framework dependency, or `vm_service` client in application runtime code.
2. **Unpublished extension app:** UI, managed DevTools services, generator, input editor, and export logic. Its development dependencies do not become dependencies of the developer's app.
3. **Optional host screenshot executable:** Only if full-device capture is enabled. A Dart executable can register a narrowly defined capture service with the existing DTD; it does not run tests or accept arbitrary shell commands. Validate this integration before including it in the published package.

Prefer these boundaries over a large multi-package framework. Extract a separate public model package only if a real dependency constraint requires it.

### App integration

- Require explicit debug opt-in, for example through a development-only entrypoint and a recorder scope wrapping the app.
- Do not require `recordTap` or `recordText` calls in normal application callbacks.
  Those M1 APIs were removed in the automatic implementation. Unsupported custom
  controls require stable accessible structure or remain explicitly unresolved.
- Place the capture boundary around the Flutter root, including the `MaterialApp` navigator/overlay subtree, not merely one route's body.
- Install/remove pointer routes and listeners without replacing framework dispatcher callbacks, winning gestures, or changing application callbacks.
- Discover standard text fields automatically; preserve application callbacks and
  controller ownership. Navigation metadata may optionally use observers for the
  relevant navigators; missing route metadata must not require per-button hooks.
- Compile-time disabled paths must install no observers, register no recorder RPCs, allocate no session buffers, and read no input in profile/release builds.
- Existing app initialization still belongs to the app. Generated tests use an explicitly configured, typed bootstrap recipe, not a guessed `main()` signature.

### Automatic-first integration decision (22 October follow-up)

The user rejected application-wide action hooks as too invasive. The required UX
is one debug-only recorder setup, existing keys/semantics where available, and
optional sensitive/ignore annotations. Ordinary buttons and standard text fields
must not require modified `onPressed` or `onChanged` callbacks. This changes the
default architecture, not the historical scope/results of M1. The later
implementation request also moved all example setup/data into `patrol_test/` and
removed coordinate/index fallbacks. Results below supersede the research-only
status in this section.

#### What Maestro establishes, and what it does not

- Its Flutter guide explicitly describes an external accessibility/semantics
  approach. Ordinary Flutter keys are not exposed to that OS hierarchy. Widgets
  with accessible text can be targeted without adding IDs everywhere; stable
  semantics identifiers improve reliability. [S21]
- The inspected Android implementation reads `AccessibilityNodeInfo` attributes
  including resource ID, content description, text, bounds, enabled/clickable,
  focus, and password state. This is target discovery, not a Flutter callback
  event bus. Its window-root lookup uses reflection with a public fallback; do
  not port this into our public-API-only Flutter design. [S23]
- Current Studio documentation describes right-clicking an inspected element and
  adding a command. The public Studio repository exposes a README/issues rather
  than the desktop implementation. We therefore cannot claim source-verified
  passive recording of arbitrary direct-device interactions, or infer that
  Maestro has a universal Flutter action listener. [S22]
- Borrow the design principle: **interaction context + hierarchy + selector
  resolution -> editable test step**. Do not borrow its runner, native driver,
  cloud services, or platform permissions. Generated output remains Patrol Dart.

#### Flutter-native observation design

```text
User interacts normally with the running app
   |
App-level observers (not action calls in application callbacks)
   |-- pointer route -> down-time hit target -> gesture classification
   |-- semantics action listener -> accessibility action request
   |-- focus manager -> mounted EditableText -> controller notifications
   `-- scroll notifications / optional navigator observers
   |
Target resolver: element ancestors + semantics + scoped match validation
   |
Source-side privacy -> reference-only input bindings -> bounded steps
   |
Existing VM Service -> DevTools timeline -> existing Patrol generator/export
```

1. **Pointer path:** use `PointerRouter.addGlobalRoute` and
   `hitTestInView`. Discover the relevant element/ancestors and available
   semantics when the pointer goes down, before a subsequent action can replace
   the route. A debug-only `RenderObject.debugCreator` bridge is available for
   framework-created render objects; missing mappings remain unresolved.
   Filter cancelled sequences, movement, disabled standard controls, and
   unsupported/multi-pointer interactions. Do not install a competing root
   `GestureDetector` or replace dispatcher callbacks.
2. **Accessibility path:** use the public
   `SemanticsBinding.addSemanticsActionListener`. It receives platform semantics
   requests before dispatch, not ordinary pointer taps and not callback-completion
   notifications. Preserve that provenance, deduplicate where a host emits
   overlapping observations, and never buffer text-bearing action arguments.
   Enable semantics with a scoped handle and dispose it appropriately. [S24]
3. **Text path:** listen to `FocusManager` changes, inspect the focused node's
   context/ancestors for a mounted standard `EditableText`, and attach to its
   public controller. This can discover controllers created internally by
   `TextField`; app-owned controller or callback changes are unnecessary.
   Handle an already focused field when recording starts and reconcile controller
   replacement/disposal without whole-tree polling. [S25]
4. **Input references:** prefer a safe stable field identifier for a binding;
   otherwise allocate an editable reference such as `input_0001`. Bind profiles
   and values in DevTools/data files, not per-field recorder calls in app code.
   Treat `obscureText` as sensitive automatically and honor explicit annotations.
   Neither controller values nor semantics text-input arguments should enter
   buffers, events, diagnostics, or metadata by default.
5. **Honest confidence:** a short pointer sequence is a recorded gesture
   candidate, not proof that a particular callback or business operation
   succeeded. Likewise controller changes can be programmatic, selection-only,
   or composing changes. Coalesce and classify; unresolved provenance is visibly
   review-required, not silently promoted to confirmed user input. Separating
   selection-only changes while retaining no sensitive text is an explicit
   implementation/privacy gate. The implemented mode deliberately records
   focused-controller activity (including selection/programmatic notifications)
   without reading text, rather than pretending it can distinguish those sources.
6. **Target policy:** prefer a unique stable identifier/key, then a scoped
   identifier/key, then scoped labels/text or a supported public type. An
   ordinary key is available to our in-app runtime even though Maestro cannot
   access it externally. No mandatory key on every widget.

For duplicate "Continue" labels, resolve a stable ancestor such as a keyed
shipping form and generate a normal scoped Flutter finder wrapped by Patrol:

```dart
final target = find.descendant(
  of: find.byKey(const ValueKey<String>('shipping_form')),
  matching: find.text('Continue'),
);
expect(target, findsOneWidget);
await $(target).tap();
```

If no stable scope resolves the duplicate, require user correction or an
explicitly approved fragile fallback. Never automatically choose `.first`.
Semantics nodes and Flutter finder matches are not one-to-one: merged semantics,
offstage routes, and ancestor widgets require generator-compatible validation.
Do not persist a transient semantics node ID or element identity as a selector.

#### Verified API experiments, not a completed automatic recorder

[automatic_observation_feasibility_test.dart](../test/automatic_observation_feasibility_test.dart)
contains four executable experiments on the tested Flutter SDK:

| Experiment | Result |
| --- | --- |
| Uninstrumented button interaction | A passive pointer listener and hit test found the standard button's key and enabled state. Enabled and disabled buttons both produced pointer down/up; only the enabled button activated. Cancellation produced a cancel event without activation. |
| Uninstrumented text field | Focus discovery found an internally created controller without `onChanged`, an app-supplied controller, or a field key. `obscureText` was available. Test IME input, selection changes, and programmatic writes all notified: notifications alone do not prove typing. Listener cleanup after unmount passed. |
| Accessibility action | The public semantics listener received a synthetic platform tap request before the button action; an ordinary pointer tap did not generate that request. The test invokes the existing platform callback, without replacing it. |
| Duplicate labels | Two keyless buttons with the same text matched ambiguously; a stable ancestor key plus descendant text selected and activated exactly the intended button. This validates the finder shape, not an implemented automatic resolver. |

`dart format`, `flutter analyze lib test`, and the four new tests plus five
existing runtime tests passed (**9 tests**). These are Flutter widget-harness
experiments using simulated pointer/IME/platform inputs, not real-host automatic
recording, full IME coverage, performance evidence, or an automatic Patrol replay
proof. At that research stage the M1 runtime still used explicit hooks; the
subsequent automatic implementation replaces them as documented below.

### Protocol and lifecycle

Use a versioned `ext.patrol_recorder.*` namespace. Proposed commands: `capabilities`, `start`, `pause`, `resume`, `stop`, `snapshot`, and `captureFlutter`. Publish sanitized step notifications through `postEvent`.

Each response/event includes protocol version, session ID, app-isolate identity, sequence number, and state/revision where relevant. Commands are acknowledged and idempotent by request ID. Only one recording controller owns a session; other views are read-only.

The capability handshake advertises installed text/router/action adapters, available screenshot kinds, supported selectors, and resource limits. Unsupported features are disabled with an explanation.

Subscribe through `serviceManager`; do not reconnect/dispose the host-managed service. Discover the app isolate rather than choosing the first VM isolate. Reconcile initial snapshot and events by sequence number, detect gaps, and request missing data. Hot restart creates a new session identity; never append unrelated isolate events to an old recording.

Keep screenshots out of per-step events. Capture on explicit request, return bounded/chunked payloads if necessary, and preserve request/step IDs. Timeouts, disconnections, incomplete captures, and buffer exhaustion must be visible, not silently treated as success.

## 5. Interaction-observation feasibility

**A runtime recorder is required for reliable operation.** DevTools can request inspection data and call registered service extensions. It cannot passively reconstruct every gesture, callback, edit, or navigation from the VM Service. Inspector selection modes are not user-action recording and can interfere with app interaction.

| Interaction | Passive observation | Reliable path / required instrumentation | Limitations and generated intent |
| --- | --- | --- | --- |
| Tap | Down/up/cancel, positions, view ID, hit-test candidates | Automatic standard-widget target discovery, without app callback changes | A short pointer sequence is only an inferred tap. Disabled controls, gesture cancellation, overlays, and arena competition can invalidate it. Generate `.tap()` with honest provenance and required ambiguity review. |
| Long press | Duration and movement are observable | Automatic classification requires a supported target and recognizer-behavior proof; not implemented in this slice | Timing alone does not establish which recognizer won; do not infer callback success. Unsupported gestures visibly block runnable export. |
| Text entry | Focus and public controller notifications are available without app callback changes | Automatic focused standard `EditableText` discovery; optional adapter only for unsupported controls | IME composition, paste, autofill, hardware input, selection-only and programmatic changes need provenance handling. Controller changes alone do not prove user intent. Commit/coalesce references, not raw values. Native fields are unsupported. |
| Scroll | Pointer drag/wheel/pan-zoom plus bubbling `ScrollNotification`/metrics | Future adapter: scope notifications to the scrollable; not implemented in this slice | Prefer scrolling to an identified target. No coordinate-based fallback is permitted. Current recognized scroll/drag gestures visibly block export. |
| Navigation | No universal pointer-derived route event | `NavigatorObserver` for each navigator; router-specific integration for declarative/nested routing where needed | Record push/pop/replace/remove as observations associated with the triggering action. Route changes must not generate a second `pushNamed` after a tap. Sanitize route arguments and URLs. External/programmatic changes without a reproducible cause require review. |
| Accessibility activation | Public `SemanticsBinding.addSemanticsActionListener` observes platform requests | App-level listener, not a per-button hook | Requests arrive before dispatch and do not prove success. A pointer-only recorder misses them; the semantics listener does not report ordinary pointer taps. [S24] |
| Custom-painted UI/custom recognizers | Pointer hit context can be observed | Stable accessible target metadata or a future validated adapter | No reliable widget/semantics target can be invented. Keep an unresolved step; do not generate coordinates. |
| Platform views, WebViews, OS dialogs, keyboard keys, other apps | Outside ordinary Flutter widget observation | Not supported by this recorder's initial adapters | Patrol may execute manually authored native actions, but execution capability does not imply recording capability. Show a capture gap; never fabricate native steps. |

### Target discovery constraints

- Gather candidates from the pointer's view-aware hit-test path and relevant element ancestors, plus available semantics and explicit adapter metadata.
- `RenderObject.debugCreator`/debug inspection can assist in debug builds, but not every render object yields a useful widget/key. It is not a release-mode contract.
- Snapshot metadata before navigation/disposal changes the target tree. Use current tree validation only when available; exported metadata cannot certify later runtime uniqueness.
- A root `GestureDetector` must not be used as a universal recorder: it participates in the gesture arena and misses or alters child recognition.
- Avoid periodically scanning the whole widget tree or reading every text value. Bound discovery work, detach disposed controllers, and make text capture consent explicit.
- Uncertain observations remain visibly **inferred** or **unresolved**, not silently promoted to confirmed actions.

## 6. Selector selection and customization

Select deterministically by uniqueness, stability, scope, visibility, and reproducibility, not by AI or an arbitrary confidence percentage.

Default order among valid candidates:

1. Exact serializable `ValueKey<String>` on the target, globally unique or within
   a uniquely keyed/identified ancestor.
2. `Semantics.identifier`, globally unique or within that kind of ancestor.
3. Semantics label, text-field decoration label, or visible plain `Text`, with
   localization/dynamic-value warnings and the same uniqueness rules.
4. An allowlisted public widget type, globally unique or scoped to a stable ancestor.

If none resolves uniquely, block runnable export. Do not generate coordinates,
positional indexes, or `.first`. Private/object/unique keys are not stringified.

Examples of supported output:

| Target | Patrol/Flutter expression |
| --- | --- |
| Semantics identifier | `$(find.bySemanticsIdentifier('checkout.submit'))` |
| String key | `$(const ValueKey<String>('submit'))` or `$(#submit)` for appropriate string keys |
| Semantics label | `$(find.bySemanticsLabel('Continue'))` |
| Visible text | `$('Continue')` |
| Widget type | `$(ElevatedButton)` |
| Scoped text | `$(const Key('checkoutPanel')).$('Continue')` |

Do not serialize `UniqueKey`, object identity, `GlobalKey` identity, private widget types, diagnostic `toString()` output, or typed keys with the wrong value type. For example, a `ValueKey<int>` is not a `Key` constructed from its printed number.

The current timeline shows the selected selector/scope, source, and unresolved
reason. Full candidate inspection and structured selector overrides remain M2.
Revalidate after changes; never silently select `.first` on ambiguity.

Missing or ambiguous selectors block a runnable export unless the developer supplies an explicit override or excludes the step. Permit a separately labelled draft export containing actionable TODOs, not success-shaped test actions.

Pointer positions are transient hit-test inputs only. The model/export contains
no coordinate or index selector. Screenshot dimensions are image metadata, not
tap coordinates.

## 7. Session controls and editing

State machine: **disconnected -> ready -> recording <-> paused -> stopped/draft -> exported**. Errors retain the editable draft.

- **Start:** capability check, new session, cleared runtime buffer only after acknowledgment.
- **Pause:** stop admitting new runtime observations; do not merely hide events in the UI.
- **Resume:** resume the same session with a visible boundary. Do not retroactively capture activity performed while paused.
- **Stop:** finish pending input/scroll coalescing, acknowledge the last sequence number, then retrieve any remaining events.
- **Save:** export the stopped, validated draft. An unsuccessful or cancelled export remains unsaved.
- Edit action parameters, selector choices, input bindings, screenshot attachments, and optional explicit assertions.
- Delete/reorder steps using stable IDs. Revalidate variable dependencies, navigation context, and screenshot associations.
- **Re-record:** user selects a step/range and manually returns the app to the necessary state; a new captured segment replaces it only on confirmation. No automatic rewind, replay, or state reset engine.
- Auto-generated Dart preview sits beside the timeline and changes after every valid model edit. Keep invalid edits visible with diagnostics; do not show stale code as current.
- Exported Dart is developer-owned and freely editable. Do not parse arbitrary edited Dart back into the recorder or overwrite an existing edited file silently.

Suggested session data: schema version, SDK/tool compatibility metadata, capture mode, monotonic ordering, step IDs, action type, source (`instrumented`, `inferred`, `manual`), sanitized target candidates, selected selector, input references, screenshot references, and draft revision. Do not store debugger credentials, arbitrary widget dumps, or unredacted route arguments.

## 8. Dynamic inputs and secrets

Represent each text action as an input binding, not just one global replacement string:

- `literal`: an explicitly approved non-sensitive custom value.
- `variable`: a named value reused by any number of steps.
- `external`: a named execution-time/build-time configuration input.
- `secretRef`: only a name/reference and required flag, never the recorded credential.

Support multiple independently configured fields and repeated bindings. Validate variable names, duplicates, reserved Dart words, missing references, types, and declaration ordering. Generate named local variables in deterministic order.

### Privacy rules

- Default text capture to redacted/reference-only unless the developer registers a field as safe. Treat `obscureText` and explicitly marked fields as sensitive regardless of UI settings.
- Redact **inside the app before buffering, posting VM events, previewing, logging, or serializing**. Changing a step to "secret" after sending the value is too late.
- Secret references retain no value, length, hash, or reversible encoding. Capture the fact of an edit and its target/binding only.
- Mask selectors/labels/route data that might contain secrets; never use a password's text as a selector.
- Preview, metadata, diagnostic messages, and export manifests contain references only. Diagnostics must not echo offending values.
- No plaintext secret entry field in the extension. Supply test credentials out of band, preferably short-lived test-only values.
- `String.fromEnvironment` with Patrol's `--dart-define-from-file` avoids literal credentials in generated source, but **embeds values in the built test application**. It is not a secure vault. Keep the private input file outside distributable project output and protect build artifacts. Runtime delivery requires an app-specific secure test fixture.
- Use `$.enterText(..., enablePatrolLog: false)` for external/sensitive inputs. Patrol's lower-level text method can log its `value` by default; disabling recorder logs alone is insufficient. Application/OS logs still need separate control.
- Disable automatic screenshots around sensitive input. Manual captures require a clear privacy warning. Full-device screenshots may expose notifications or another app; redacted metadata does not make those images safe.

The generator must correctly escape quotes, backslashes, dollar interpolation, control characters, and multiline/unicode values. Do not treat user-entered selectors or input names as executable Dart source.

## 9. Screenshot capture

Every image carries `captureKind`, provider, step ID, request/completion timestamps, dimensions, scale, and relevant view/device identity. Distinguish a recording artifact from a screenshot requested by a subsequently executed test.

| Capture kind | Supported mechanism | Exclusions / gate |
| --- | --- | --- |
| **Flutter content** | App-side `RenderRepaintBoundary.toImage` after the intended frame paints; PNG bytes returned to the extension | Only that subtree. No system bars, keyboard, OS dialogs, other apps, or guaranteed platform-view/texture contents. Root overlays must actually be inside the boundary. |
| **Android full device** | Optional host provider invokes installed `adb -s <serial> exec-out screencap -p` using fixed argument lists | Authorized device required. Protected/secure surfaces may be blank or unavailable; no bypass. Not yet device-tested. |
| **iOS simulator full device** | Optional host provider invokes `xcrun simctl io <udid> screenshot --type=png -` | Booted simulator required. No claim for physical iOS devices. CLI support verified, capture not yet tested. |
| **Physical iOS / desktop whole display** | No built-in baseline provider | Show unsupported. Native consent-based APIs or separately approved host tooling require independent investigation. |
| **Browser/app viewport** | Flutter content as above; any future browser capture must be explicitly labelled viewport/content | Not a full-device screenshot and not the extension's own browser page presented as the app. |

### Why not simply call Patrol for recording-time screenshots?

Patrol 4.10.0 exposes `$.takeNativeScreenshot(tag)`, requiring CLI 4.8.0 for the corresponding feature. It operates in a Patrol test, is Android-only, returns no PNG bytes, and is a no-op elsewhere; its public wrapper does not throw on failure. It is **not** a general DevTools capture/export API. [S18]

Normal developer app recording must not depend on a Patrol test already running. A host capture adapter is separate from test execution and strictly limited to screenshot capture.

The optional adapter advertises its capabilities through DTD, requires explicit device selection, has bounded output/timeouts, and accepts no arbitrary process names, shell fragments, or filesystem paths from the app. Prefer stdout image transport over shared temporary device files. Fail visibly when the device is locked, missing, disconnected, or refuses capture.

Screenshot association is explicit: "after step N" means capture was requested after that action's observation and a frame boundary. It does not prove an asynchronous app operation has completed. Show capture time and allow retake. Do not insert unexplained sleeps or wait forever for an animated app to settle.

## 10. Supported local export

### Primary: DTD workspace export

The extension uses the connection supplied by `DevToolsExtension` and discovers permitted workspace/project roots. The developer selects the correct package in a multi-root workspace and configures **relative** paths, for example:

```text
test directory:        patrol_test/recorded/
screenshot directory:  patrol_test/recorded/screenshots/
metadata directory:    patrol_test/recorded/sessions/
```

Write Dart/JSON with `writeFileAsString`. The current public API also accepted `latin1.decode(pngBytes)` with `encoding: latin1`, producing byte-identical PNGs in the experiment. **Writing a base64 string into a `.png` file is not valid PNG export.** Validate the binary round trip against each supported DTD version; otherwise offer the download route explicitly.

DTD refers to the filesystem **where DTD runs**. In a remote/container workspace that may not be the user's desktop. Show the host/root and final destination before saving. A directory path on a mobile app is not the developer's project directory.

Enforce safe relative paths, no traversal/absolute path injection, valid filenames, and explicit overwrite confirmation. Test workspace boundaries and symlink behavior; the simple outside-root experiment does not certify all filesystem edge cases.

Use unique session filenames by default. Preflight the export, report each file's status, verify reads/byte counts, and write the completion manifest last. DTD does not provide a documented multi-file transaction here: if one write fails, report partial export and allow retry; never claim an atomic save. Do not silently remove existing files.

If DTD is absent, has no authorized root, or denies access, explain the limitation. Do not start an unrestricted daemon or introduce an arbitrary-write HTTP endpoint to work around it.

### Fallback: browser-managed download

- Offer a single ZIP containing Dart, PNGs, and optional metadata, plus individual file download where supported.
- The user controls the physical destination through browser download settings or a permitted picker. The extension configures the suggested filename and paths **inside** the archive, not an arbitrary destination path.
- A File System Access picker is optional enhancement, gated by feature detection, secure context, iframe/host restrictions, permissions, and a direct user gesture.
- Do not rely on `file_selector.getSaveLocation` or `getDirectoryPath` on web.
- Browser fallback is **not yet accepted**: test real standalone DevTools in Chrome/Edge and embedded IDE DevTools separately. The integrated-browser experiment did not prove successful download persistence.
- Cancellation, permission rejection, blocked downloads, missing roots, and write errors remain visibly unsaved. A Blob anchor click is only a download request, not proof that a file was saved.

## 11. Generated Patrol Dart examples

### A. Complete test from the one-tap proof

The following uses the isolated probe application. A real export substitutes the configured sample/application bootstrap import and widget.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase1_probe/probe_app.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('recorded increment', ($) async {
    await $.pumpWidgetAndSettle(const ProbeApp());
    await $(const ValueKey<String>("increment")).tap();
    expect(find.text('Count: 1'), findsOneWidget);
  });
}
```

The assertion was deliberately authored for the counter proof; the recorder must not claim to infer arbitrary application correctness.

### B. Several independent inputs, a reused value, and a custom value

This is a type-checked generation pattern for a sample app providing the listed field keys. A full test calls it after the app's configured bootstrap; it is not claimed to run against the one-button probe.

```dart
Future<void> fillInputs(PatrolIntegrationTester $) async {
  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');
  const otp = String.fromEnvironment('E2E_OTP');
  const note = 'Local test';

  if (email.isEmpty || password.isEmpty || otp.isEmpty) {
    throw StateError('Supply E2E_EMAIL, E2E_PASSWORD, and E2E_OTP');
  }

  await $.enterText(
    find.byKey(const Key('email')), email, enablePatrolLog: false,
  );
  await $.enterText(
    find.byKey(const Key('confirmEmail')), email, enablePatrolLog: false,
  );
  await $.enterText(
    find.byKey(const Key('password')), password, enablePatrolLog: false,
  );
  await $.enterText(
    find.byKey(const Key('otp')), otp, enablePatrolLog: false,
  );
  await $(const Key('note')).enterText(note);
}
```

Use the same Flutter/Patrol imports as example A. A developer runs the saved test using the existing Patrol installation/setup:

```sh
patrol test --target patrol_test/recorded/login_test.dart \
  --dart-define-from-file /private/path/e2e-inputs.json
```

Patrol's default test directory is currently `patrol_test`, not an assumed `integration_test`. Honor an existing `patrol.test_directory` setting or an explicitly selected output directory. The private values file is not generated or exported by the recorder.

### C. Semantics and future target-based long press/scroll

```dart
final semantics = $.tester.ensureSemantics();
try {
  await $.pump();
  await $(find.bySemanticsIdentifier('checkout.submit')).tap();
} finally {
  semantics.dispose();
}

await $(const Key('item')).longPress();
await $(const Key('lastItem')).scrollTo(view: $(const Key('list')));

```

These APIs were type-checked against the resolved dependencies. Scrolling and
long-press generation are still future work; current observation does not emit
these actions. The earlier coordinate-based examples were removed at the user's
request. Generate bounded Patrol waits and configurable settle policy per step.

Navigation observations ordinarily annotate the triggering step. A manually confirmed back action may generate an appropriate Flutter/Patrol action; route names alone are not instructions to call the app's navigator directly.

## 12. Proposed source and exported-output structure

Source structure after approval:

```text
packages/
  patrol_recorder/
    lib/
    bin/                         # optional screenshot-only host provider
    extension/devtools/
      config.yaml
      build/                     # prebuilt extension, included on pub.dev
    example/                     # representative Flutter app
    test/
    pubspec.yaml
    README.md
    LICENSE
    CHANGELOG.md
  patrol_recorder_devtools/       # unpublished Flutter web app
    lib/
    test/
    pubspec.yaml
docs/
  IMPLEMENTATION_HISTORY.md
```

Generated user output:

```text
<selected-package>/
  patrol_test/recorded/
    login_test.dart
    screenshots/
      <session-id>_step-0001_flutter.png
      <session-id>_step-0001_device.png
    sessions/
      <session-id>.json           # optional, sanitized machine metadata
```

Each image filename and metadata entry identifies its capture kind. Metadata is optional and is never required to execute the Dart test. Partial exports do not receive a completed-session manifest. A downloaded ZIP preserves the same relative structure.

### DevTools packaging

Current required configuration fields are `name`, `issueTracker`, `version`, and `materialIconCodePoint`. `requiresConnection` is optional. Prefer `requiresConnection: false` to keep stopped drafts editable while disconnected, with recording controls gated on an active compatible app. [S19]

Use the official commands from the extension app:

```sh
dart run devtools_extensions build_and_copy \
  --source=. --dest=../patrol_recorder/extension/devtools
dart run devtools_extensions validate --package=../patrol_recorder
```

The extension is an iframe and must first be enabled by the developer. Test the published-asset layout in real DevTools; a successful `flutter build web` alone does not prove discovery or host communication.

## 13. Tests, documentation, and pub.dev readiness

### Automated tests

- **Protocol/state:** Start/Pause/Resume/Stop acknowledgments, duplicate requests, event ordering/gaps, bounds, reconnects, isolate replacement, and pending capture/input flushing.
- **Observation:** taps, cancellation, disabled controls, long press versus drag, accessibility activation, overlays, nested scrolling, wheel input, IME composition/paste/autofill, controller disposal, and programmatic edits.
- **Navigation:** Navigator 1 observers, nested navigators, router adapters, unnamed routes, back navigation, and route changes not duplicated as test actions.
- **Selectors:** duplicated identifiers/labels/types, typed keys, localization,
  offstage/hidden targets, changing widget trees, private types, ancestor scoping,
  semantics lifecycle, and absence of coordinate/index fallbacks.
- **Generator:** exact Dart text fixtures and compilation for every supported action/input combination; escaping, imports, missing bindings, secret omission, and deterministic output. No image/pixel comparison tests.
- **UI:** controls and disabled states, keyboard accessibility, timeline selection, edits/deletes/reorder, re-record replacement/cancel, live preview updates, and honest error states.
- **Screenshots:** valid PNG signature/decoding/dimensions, correct capture kind, boundary scope, byte-preserving transfer/export, timeout/failure handling, and missing native surfaces. No screenshot diffing.
- **Export:** configured paths, multiple roots, remote roots, traversal/symlink cases, overwrite refusal, denied roots, partial writes, binary encoding, browser cancellation, blocked download, and absent DTD.
- **Privacy:** seed unique secret sentinels; assert they are absent from captured buffers, VM payloads, previews, logs, Dart/JSON/ZIP outputs, and diagnostics. Test screenshot refusal for sensitive contexts.
- **Non-interference:** instrumentation on/off produces the same widget callback count, navigation effects, scrolling, focus, and input results. Release/profile builds expose no recorder service extensions.
- **Actual Patrol integration:** save generated tests into the sample app and execute them using Patrol CLI on every advertised platform. Do not substitute analyzer success for device execution.

### Sample application and documentation

The sample app should include unique keys and semantics identifiers, intentional duplicate labels, a disabled control, tap/long-press targets, nested scrollables, multiple input fields including a password/OTP, Navigator and nested/router navigation, an overlay, and a clearly marked unsupported/native surface.

Document installation and debug-only opt-in, instrumentation choices, supported/unsupported interactions, selector stability, input privacy, screenshot differences, export permissions/remote-host behavior, application bootstrap configuration, Patrol setup/run commands, troubleshooting, and the capability matrix.

### Packaging checklist

- Valid pubspec, real repository/issue/documentation URLs, chosen available package name, compatible SDK/dependency ranges, and declared supported platforms.
- Original licence plus required third-party notices; documented maintenance/security contact and dependency inventory.
- Public API documentation, README, example, tests, and package changelog.
- Precompiled extension assets/configuration present; extension development source/tools excluded from the runtime dependency graph.
- Exclude credentials, VM/DTD tokens, local sessions, screenshots of real apps, generated experiment output, and unnecessary build artifacts from the publish archive.
- Inspect the package archive and run `dart pub publish --dry-run`, the official extension validator, analysis/tests, and package scoring checks. Current pub guidance recommends under 100 MB compressed and 256 MB uncompressed; aim substantially below those values. [S20]
- Test installation of the packaged artifact in a clean sample project, including offline/local web assets and extension discovery.
- No publishing, repository workflow, or package-wide implementation is authorized by this research task.

## 14. Risks and proof-of-concept milestones

### Critical risks

| Risk | Mitigation / stop condition |
| --- | --- |
| "Automatic recording" overpromises what pointer data means | Separate pointer candidates, accessibility requests, focused-controller activity, and unresolved events. No callback-success or universal-recording claims. |
| Target identity is ambiguous or unstable | Require unique valid candidates or manual correction; never silently pick a random match. |
| Secrets leak before reaching the editor | Source-side redaction, reference-only defaults, suppressed input logs, screenshot restrictions, and sentinel tests are required before real-app trials. |
| Full-device screenshot is confused with Flutter capture | Separate providers, filenames, capability states, and UI labels. Native-device providers must demonstrate actual PNG capture or remain unsupported. |
| Filesystem/export assumptions fail in IDE or remote contexts | DTD capability/root discovery and explicit destinations; browser fallback remains gated until persisted artifacts are verified. |
| Recording changes app behavior | Passive listeners, exact callback chaining, lifecycle cleanup, and on/off non-interference tests. No extra gesture recognizer used as a universal tap detector. |
| Large event/image payloads stall app or DevTools | Bounded buffers, incremental events, on-demand snapshots, chunked images where needed, visible backpressure, and measured limits. |
| Generated tests compile but are flaky or cannot initialize the app | Explicit bootstrap, bounded waits, uniqueness checks, and real Patrol execution; no assertion or state-reset inference. |
| Dependency/host APIs change | Public exports only, tested version matrix, protocol capability negotiation, isolated extension dependencies, and reviewed updates. |

### M0 - Primitive feasibility (completed with stated limits)

Observe one instrumented Flutter tap, deliver its data over VM Service, generate a valid Patrol test, execute its action with Patrol finders, capture Flutter content, and save code/PNG through restricted DTD. Also test negative observation/export cases. Evidence is in section 2.

This is sufficient to justify the next experiment, not to claim that the package exists.

### Revised implementation milestones (supersede the original sequence)

The implementation request adds editable per-journey data, named account profiles,
groups/cases, saved-test browsing, and execution-command generation. Implement one
milestone at a time and stop for approval after each.

**M1 - Technical proof of concept (completed):**

- Root Flutter package with an unpublished extension app under `tool/devtools_extension/`
  and a runnable `example/`; this simpler layout replaces the proposed `packages/` layout.
- Explicit tap and input-reference instrumentation only. No universal gesture interception.
- Load the extension inside real DevTools against the running example, not just the
  simulated extension environment.
- Record a real UI interaction, generate Patrol source plus a separate editable Dart
  data file, capture Flutter content, and export through permission-bound DTD.
- Begin the login/form/navigation example with safe named demonstration profiles.
- Generate a supported run command and execute the generated test wherever supported.
  Current public Patrol documentation supports `patrol test --device chrome
  --web-headless`, so web is the first available target; mobile remains unverified.
- Format/analyze/test all changed packages, record actual results below, then stop.

**M1A - Automatic observation with minimal app changes (implemented bounded slice):**

The user authorized implementation after the architecture experiments. The
following acceptance scope guided the work; actual results and remaining limits
are recorded below rather than implying universal support:

- Remove mandatory action/text recording calls from the example's normal buttons
  and fields; retain one debug wrapper and optional sensitive/ignore annotations.
- Observe ordinary taps and standard text-field activity, including fields without
  explicit controllers or keys. No replacement of callbacks/gesture recognizers.
- Resolve a unique key/semantics identifier, unique text, and repeated text scoped
  to an ancestor. An unresolved duplicate blocks runnable export rather than
  producing `.first` or silently dropping the interaction.
- Test disabled controls, cancel/drag sequences, nested recognizers, overlays,
  navigation disposal, keyboard focus, selection-only changes, IME composition,
  programmatic edits, and listener teardown. Clearly mark unsupported cases.
- Verify automatic obscured-field treatment and explicit ignore/sensitive
  subtrees; sentinel values must not appear in source, transport, metadata, logs,
  or screenshots. Do not read full semantics values indiscriminately.
- Repeat the real DevTools -> source/data -> PNG/export -> official Patrol proof
  without per-action hooks. Recheck singleton finder assertions during replay.
- Measure discovery cost on a large tree; no full-tree scan every frame. If a
  bounded traversal cannot establish uniqueness, mark it unresolved. The
  implementation enforces/tested a 10000-element bound; a device-specific latency
  budget and broad performance matrix remain unverified.

This is a targeted observation/generation integration, not approval for the rest
of M2-M5 or a new execution engine. Report its actual evidence and stop afterward.

**M2 - Multi-journey model, groups, cases, and selector inspection:** stable IDs/readable
names, multiple files and cases, typed data schemas, reusable profiles/setup, input
classification, and structured selector overrides. Amount/date types and full data-set
validation belong here, not in an oversized M1 prototype.

**M3 - Timeline, preview, and recording controls:** full live timeline, robust
Start/Pause/Resume/Stop/Discard state machine, editing/reordering, grouping, and
manual re-record workflows. M1 may include only the controls necessary for its proof.

**M4 - Screenshot/export/discovery/execution workflows:** saved-journey reopening and
browsing, selected file/case/suite commands, safe overwrite handling, screenshot
providers, and supported export portability. Direct process invocation and runner
result ingestion remain optional proof-gated integrations, not browser capabilities.

**M5 - Example completion and package readiness:** representative multiple journeys,
all advertised interaction adapters, platform matrix, tests, docs, licensing review,
archive inspection, and pub.dev dry run. No publication is authorized.

### Revised output and execution decisions

Use `patrol_test/recorded_journeys/<journey-id>/<journey-id>_test.dart` with a sibling
`<journey-id>_data.dart` and `screenshots/`. Each journey is an independently discoverable
Patrol target. Do not create a discoverable `suite_test.dart` that imports those tests:
running the configured test directory is the suite, avoiding duplicate execution.

Use one `recorder_config.yaml` for recorder defaults and human-editable Dart for
test data. Credentials are external references only. Each profile selects data before
execution using `RECORDER_PROFILE`; secret injection uses the supported Patrol
`--dart-define-from-file` mechanism with the build-artifact caveat in section 8.
Do not assume the app process inherits the host shell environment.

Investigate case selection using stable unique Patrol test tags and the public
`--tags` option; verify CLI behavior before advertising it. Keep recording and test
execution separate: a Patrol run can restart the app and invalidate the recording
connection. M1 offers copyable commands, not a Run button or automatic result feed.

### Initial integrated proof

The real-host evidence, commands, saved-output details, failures, and verification
boundaries for the initial integrated proof are recorded in the
[integrated proof report](INTEGRATED_PROOF_RESULTS.md).

### Automatic implementation results

This section records the initial automatic implementation milestone. Its
implementation snapshot and counts are historical; the protocol-5 additions and
current verification are recorded below. All changes remain unpublished.

**Integration layout**

```text
example/
  lib/main.dart                      ordinary app launch; no recorder import
  lib/app.dart                       normal widgets and callbacks; empty fields
  patrol_test/recorder_main.dart      debug recorder setup and app bootstrap
  patrol_test/demo_profiles.dart      fictional public test defaults
  patrol_test/recorded_journeys/       editable tests, data, metadata, screenshots
```

The recorder is an example `dev_dependency`. There is no second overlapping
`integration_test` layout. Both non-test entrypoint/profile files lack the
`_test.dart` suffix, so they are not Patrol test targets. Optional ignore/sensitive
annotations remain available, but the example needs no recorder imports at all:
its ordinary `obscureText` password field is detected automatically.

**Implemented behavior**

- [Runtime observer](../lib/src/observation.dart): passive view-aware pointer
  hit tests, pre-dispatch semantics tap requests, focus-based standard editable
  controller discovery, lifecycle cleanup, and automatic obscured-field privacy.
- [Model](../lib/model.dart): protocol 2, typed key/semantics/field-label/text/type
  selectors, one unique ancestor scope, unresolved reasons, and observation
  provenance. Old protocol-1 session reopening is not supported.
- [Generator](../tool/patrol_recorder_generator/lib/src/generator.dart) (development-only companion): no coordinate
  or index representation; every generated action waits for existence and
  asserts `findsOneWidget` before acting. Unresolved steps refuse generation.
- Keyless duplicate buttons can resolve by text or type inside a stable ancestor;
  unresolved duplicates never silently select one match. Exact string keys
  take priority over semantics identifiers, including in the real app proof.
- The old `recordTap`/`recordText` APIs and all example callback calls were removed.
  The app's callbacks still perform only app behavior.
- Typed text, its hash, and its length are not retained by the recorder.
  Controller activity includes selection/composition/programmatic changes and is
  explicitly labelled as such; it is not a definitive user-typing event.
- Discovery happens on relevant interactions/focus changes, not whole-tree polling
  every frame. Frame reconciliation only follows the focused element chain.
  Over-limit discovery stays unresolved. Labels in sensitive/ignored regions
  are excluded; conservative privacy handling may prefer a key/type or reject
  a label where uniqueness cannot safely be established.
- Multiple DTD roots require an explicit project selection; no arbitrary first
  project is preselected. Create-only export and text/PNG verification boundaries
  remain as in M1.

**Verified results**

| Check | Actual result |
| --- | --- |
| Runtime formatting/analysis/tests | Passed; 22 tests including 18 implementation tests and 4 retained API experiments |
| Generator/DTD tests | Passed; 8 tests, including all selector output shapes, ambiguity rejection, no `.first`/coordinates, singleton assertions, and export failures |
| Example tests | Passed; 6 tests, including automatic recording of email/note/login without hooks or raw-value capture |
| Secondary-profile data tests | Passed; 3 tests rerun with `RECORDER_PROFILE=secondary` |
| Production application | `flutter build web --release --target lib/main.dart --no-wasm-dry-run` passed; ordinary application source contains no recorder/profile imports |
| Extension | Production web build and official extension validation passed |
| Real DevTools | Loaded the recorder from a development dependency with the dedicated test entrypoint, started recording, edited two fields, activated login, stopped, captured, and exported |
| Real recorded selectors | Exactly `email`, `note`, `login` keys; two focused-controller sources and one semantics-action source in this browser automation path |
| Patrol replay | Exact automatic export passed with `secondary`; entire discovered suite passed 4/4 with `demo`, without duplicate execution |
| Saved image | 2392 x 1669 RGBA PNG, 37568 bytes; signature, chunk CRCs, decompression, and metadata dimensions independently verified |

At that milestone, the real output was saved under
`example/patrol_test/recorded_journeys/automatic_verified/`. Those generated
files are no longer present in the working tree. The saved test contained three
key selectors and three singleton assertions; its metadata contained no typed
values or pointer coordinates. PNG SHA-256:
`b1e5298e36d5208af86493787bd35dead4a33f612f2ea08f22b0a0a1a3711df9`.

Commands from `example`, with Node 22 on PATH:

```sh
flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd

dart pub global run patrol_cli:main test \
  --target patrol_test/recorded_journeys/automatic_verified/automatic_verified_test.dart \
  --tags recorder_automatic_verified_sign_in \
  --dart-define RECORDER_PROFILE=secondary --device chrome --web-headless \
  --web-timeout 30000 --web-global-timeout 180000

dart pub global run patrol_cli:main test \
  --device chrome --web-headless --dart-define RECORDER_PROFILE=demo \
  --web-timeout 30000 --web-global-timeout 180000
```

**Failures resolved and boundaries:** the first generated variable names triggered
lint warnings; the generator now emits `target1`, `target2`, etc. Internal Material
button wrappers required resolving to the public control rather than serializing
private types. Actual multi-root export initially selected the recorder package;
the owned wrong-root output was removed, and the UI now requires explicit
selection with multiple roots. Some dynamic Flutter status text was not visible
to accessibility locators; saved-file inspection and browser screenshots verified
the actual export rather than relying on a locator timeout. The production build
emitted a Cupertino font-family warning and the extension build emitted the
existing PWA-strategy deprecation warning; both builds completed successfully.

**Historical snapshot before the protocol-5 follow-up:** this earlier automatic
slice did not implement scrolling or long presses. The current bounded support
and its limits are documented below. Arbitrary native/custom controls, full
selector editing, and M2-M5 remain out of scope. Pointer taps are candidates, not
recognizer/business-success proof. Reference-only field activity intentionally
does not differentiate all IME, selection, autofill, or programmatic causes.
Mobile, multi-view, complete overlay/gesture combinations and device performance
budgets need further validation.

### Guided workflow repair

The user's reported problems were reproduced and fixed in the existing recorder
workflow, without adding a custom runner, coordinate selectors, or a cloud service.

| Reported issue | Implemented behavior |
| --- | --- |
| Capture disabled while recording | Visible Flutter viewport capture works before actions, during recording, and after stopping; captures carry unique IDs and optional step associations |
| Cannot capture login/sensitive pages | The app masks obscured text fields and explicitly sensitive/ignored rectangles before PNG encoding/transport; missing privacy geometry fails explicitly |
| Frequent unsupported actions | Background taps are ignored; common toggles, list tiles, dropdown/menu taps and nested targets are recognized; unrelated private regions no longer invalidate public labels |
| Genuine unsupported actions block everything | They are explicit review-required steps. The user can uncheck unnecessary actions; only included unresolved steps block code generation. Excluded actions are not replayed |
| Separate recorder configuration | Deleted the example config file. Optional defaults now come from `pubspec.yaml > recorder_config`; all settings can be entered in DevTools |
| No clear completion action | Generate code opens the guided form, stops recording if needed, validates required input choices, and Generate and save files performs actual DTD writes |
| Input customization lost during regeneration | Generated `*_inputs.g.dart` declares an abstract contract; user-owned `*_inputs.dart` implements it. It and `*_test.dart` are preserved. Only recognized `.g.dart` files can be replaced, with explicit consent |
| No visible generated files/next step | A result card lists every saved/preserved absolute path, which provider to connect, analyzer instructions and the terminal run command |

Capture is limited to the visible viewport, not stitched whole-page capture or
system UI. A draft retains at most 10 captures/20 MiB; each is limited to 8
megapixels/4 MiB. Screen capture is optional for generating code. Screenshot-only
drafts can save their images without generating an empty success-shaped test.
Screenshots remain in DevTools memory until exported; refresh/restart is not a
saved-session reopen operation.

Required non-secret input fields can be supplied in the dialog or explicitly
deferred to the user-owned Dart provider. Secret values are never requested in
the UI; generated getters initially use named compile-time defines and can be
connected to a private provider in `loadInputs()`. No JSON input file is required
or generated. Optional session JSON is metadata only, with excluded step IDs and
capture associations. Deferred/missing runtime inputs throw clear errors.

The new output layout is:

```text
<journey>_test.dart          user-owned test entrypoint and custom assertions
<journey>_inputs.dart        user-owned implementation/provider
<journey>_inputs.g.dart      generated abstract interface and input validation
<journey>_steps.g.dart       generated normal Patrol actions
screenshots/*.png           optional masked visible-view captures
sessions/<session>.json     optional recording metadata, never input values
```

Existing old-layout tests are not silently migrated. Generate a fresh journey
when adopting the new layout. Updates preserve old user-owned filenames exactly;
new interface getters must be implemented explicitly. Preserved test wrappers
retain their existing names/tags, so the completion screen offers a file-level
command rather than assuming a newly entered tag replaced them.

Verification includes runtime tests of capture before/during/after recording,
PNG pixel masking, callbacks, nested selectors, dropdowns, toggles, privacy and
cleanup; generator tests of abstract contracts, deferred/secret inputs and
preserved files; widget tests of the actual form, validation, screenshots,
explicit exclusions and final file paths. The extension UI is tested against an
injected backend, with web-only DevTools communication isolated in its adapter.

The actual DevTools proof saved a `guided_login` journey at that milestone: four
Dart files and two PNGs captured during recording, including a masked login
screen before the first action. Those generated files are no longer present in
the working tree. The exported test analyzed cleanly and passed official Patrol
web execution with the `secondary` profile. Real DevTools regeneration preserved
the user input file byte-for-byte and displayed saved/preserved paths and run
instructions. Missing-input validation was also visible in the real UI.

Final checks passed: **27 runtime/API tests, 14 generator/UI/export tests, and 6
example tests (47 total)**; clean analysis of all three packages; extension build
and official validation; and **5/5** independently discovered Patrol tests using
the demo profile. The new guided test also passed individually with secondary
data. The saved login PNG is 2392 x 1669, 37502 bytes, with SHA-256
`49e3402a6f3c5982552166b4e30d694c99ff151964ac4c3801651b9be6eee718`.
Its obscured-field rectangle was visually masked; widget tests independently
assert the masked pixel color, and both saved PNGs passed CRC/decompression checks.

A real-host edge case exposed duplicate DTD roots (the same example directory
listed via workspace and project discovery). The generation dialog now deduplicates
roots before selecting a matching app, with regression coverage. Flutter's
accessibility tree can merge result text into a group; visual inspection and
actual file checks were used in addition to locator-based checks.

DTD still lacks atomic exclusive-create/multi-file transactions. Text is read
back exactly; PNG write/existence is acknowledged and the saved image is verified
independently in the proof. Concurrent editing can race export checks; user-owned
files are never replaced, and generated-only replacement checks ownership and
pre-write content. An interrupted export can leave partial output with an error.

Historical boundary before the protocol-5 follow-up: scroll and long-press
recording had not yet been generalized. The current support is bounded to
identifiable Flutter scrollables and long-press targets; unsupported gestures are
surfaced for review, never synthesized as coordinate actions. Input activity
remains reference-only and may include programmatic or selection changes.

### YAML source and generation workflow

The user requested a Maestro-like declarative source layer, not Maestro
integration. Public [Maestro Flow documentation](https://docs.maestro.dev/maestro-flows/readme) confirms the architecture
of ordered YAML commands plus app/flow metadata, external parameters, and
contextual selectors. This package uses those design principles but retains
Patrol execution and the user's `{{input_name}}` syntax. The schemas are not
interchangeable; Maestro uses `${VARIABLE}`. No Maestro source, JavaScript
evaluator, native driver, cloud service, or execution engine was added.

**Implemented ownership and lifecycle**

1. **Record** asks for the app project/name and paths, then writes an initial
   recorder-owned `.yml` immediately with `state: recording`.
2. Runtime snapshots are polled about once per second and serialized to the same
   file; screenshot/stop/review changes flush explicitly. Writes are serialized
   with UI commands, verified by text readback, and failures are visible/retryable.
3. Input steps contain only references, for example `input: "{{user_name}}"`.
   Secret classification and stable/scoped selectors are metadata, not values.
   App-authored safe defaults are deliberately omitted from YAML.
4. **Stop** saves `state: stopped`. Incomplete or unresolved included actions
   prevent generation. Explicit exclusions remain documented in the source.
5. `dart run patrol_recorder_generator:generate [--journey name]` validates all
   selected sources, then generates ordinary Patrol Dart. It does not run tests.
6. The generated abstract `JourneyInputs` contract is separate from the one-time,
   user-owned provider scaffold. Users implement the getters and return/pass an
   instance to `runRecordedJourney($, inputs)`.
7. Re-record the same name to replace its owned YAML. The CLI then updates only
   recognized generated files. Providers and test wrappers/custom assertions
   remain byte-for-byte unchanged. New getters cause explicit analyzer errors
   until implemented.

The source schema is independently versioned as 1; the runtime transport remains
version 3. It uses declarative `target: {key: ...}` / `text` / `semantics_id` /
`semantics_label` / `field_label` / `widget_type` plus optional `within`. No
coordinates/index selector or arbitrary expression can be deserialized.

Optional `pubspec.yaml > recorder_config` adds:

```yaml
recordings_directory: patrol_recorder
screenshots_directory: patrol_recorder/screenshots
output_directory: patrol_test/recorded_journeys
```

The Record dialog can override recording/screenshot paths. The copied generator
command includes the selected YAML directory. Screenshots save immediately to
`<screenshots_directory>/<journey>/<session>/<capture>_flutter.png`, with paths in
the YAML. Re-recording does not delete archived PNGs. The CLI checks referenced
screenshots exist rather than silently ignoring broken artifacts.

**Updated package decision:** the schema/generator and executable live in
`patrol_recorder_generator`, an app development dependency. The lightweight
`patrol_recorder` owns widgets and shared runtime models and depends only on
Flutter. Formatter/analyzer/YAML dependencies belong to the generator manifest,
not the runtime recorder.
The CLI itself uses only Dart APIs; repository resolution/tests use Flutter tooling
because the shared model belongs to the Flutter runtime package. This is a narrow
code-generation companion, not the optional process-execution bridge or a runner.

**Verification evidence**

- Real DevTools created an empty YAML when Record was confirmed, before actions.
- Two text edits and a tap appeared in the live source as references and keyed
  actions, without the fictional sentinel values typed during verification.
- A screenshot saved immediately to a user-selected
  `artifacts/recorder_captures` directory and was associated with the source.
- A second real recording under the same `yaml_login` name replaced the source
  with a new session, not another YAML file.
- The CLI generated four Dart files from the
  [actual saved YAML](../example/patrol_recorder/yaml_login.yml). Generated stubs
  analyzed cleanly but intentionally required input implementation.
- The [user-owned provider](../example/patrol_test/recorded_journeys/yaml_login/yaml_login_inputs.dart)
  was manually connected to public test fixtures, and a navigation assertion was
  added to the [test wrapper](../example/patrol_test/recorded_journeys/yaml_login/yaml_login_test.dart).
  Regeneration preserved both files exactly; the updated test passed official
  Patrol web execution with the secondary profile.
- Automated tests cover YAML roundtrip, invalid literals/versions/selectors,
  unfinished/unresolved sources, output regeneration/preservation, safe paths,
  symlink rejection, immediate Record persistence, same-name replacement,
  configured screenshot output, write failure/retry, and concurrent/foreign-file
  refusal. Existing runtime/example tests remain in place.

Final verification passed: **27 runtime/API tests, 15 generator/schema/CLI tests,
4 recording-UI/persistence tests, and 6 example tests (52 total)**. All package
analysis checks were clean. The rebuilt extension passed official validation;
the complete Patrol web suite passed **6/6**, including the YAML-generated test.
The YAML test also passed separately with secondary data. No package was published.

**Remaining boundaries:** this is not equivalent to Maestro's production maturity
or full command/platform coverage. There are no subflow/conditional/script APIs
or generalized native/scroll/long-press recording. Unsupported actions still need
review. Autosave is polling-based, not a durability guarantee for an event occurring
just before the extension/app closes. Active/interrupted sources are rejected by
the CLI. DTD has no atomic replacement API; local generated files use sibling
temporary-file replacement, but a batch is not a multi-file transaction. Do not
record/generate/edit the same journey concurrently.

### Stable captures and complex UI

The user requested stable screenshot identities for later external use, less
bootstrap boilerplate, and a more representative example. No screenshot comparison,
baseline/history engine, or visual regression functionality was added.

**Screenshot naming and persistence**

- Capture suggests a name from the active page's scoped semantics identifier,
  scoped semantics label, named route, or public page widget type. Names are
  normalized to safe identifiers; missing usable metadata falls back to `screen`.
- A naming dialog previews the image and permits a state-specific override.
  Repeated page captures suggest `_2`, `_3`, etc.; meaningful names such as
  `animation_expanded` are preferable when flow order might change.
- New image paths are stable:
  `artifacts/recorder_captures/yaml_login/login_page.png` and
  `artifacts/recorder_captures/yaml_login/account_overview.png`, for example.
  The YAML supports multiple uniquely named screenshots.
- Re-recording and capturing the same journey/name replaces only a recorder-owned
  PNG. A small hidden `.name.recorder` text marker protects unrelated existing
  images. Markers contain no session identity. Tests verify same-name output is
  identical at the YAML/path level across runtime sessions.
- Source YAML contains no `session_id`; runtime session tokens remain only in
  live transport to detect app restarts. Record begins a fresh flow rather than
  guessing whether an old on-disk capture belongs to a restarted app.
- Legacy schema-1 sources remain readable. New recordings emitted schema 2 at
  this historical milestone; current recordings emit schema 3 and read schemas
  1 and 2. Old session directories and unreferenced images are not automatically
  deleted.

**Bootstrap resolution**

The previous `app.import`/`app.builder` block was a way to start the app during
replay, not an interaction selector. New YAML no longer needs it:

1. Read the selected application's package name from pubspec.
2. Resolve `package:<name>/main.dart`.
3. Use the Dart analyzer parser to verify a top-level `main` exists and can be
   called without arguments. Missing/ambiguous functions, required parameters,
   and syntax errors produce explicit generation errors.
4. Emit `await Future<void>.sync(app.main); await $.pumpAndSettle();`, supporting
   synchronous and asynchronous main initialization.

Custom initialization cannot safely be reconstructed from the live widget tree.
Apps needing a test-specific Widget factory can configure `app_import` and
`app_builder` once under `pubspec.yaml > recorder_config`. Legacy schema-1 app
metadata is honored for compatibility until re-recording. Existing users of a
custom runtime config should move intentional custom bootstrap settings to pubspec.

The test-only example entrypoint now uses `RecorderController()` without duplicate
bootstrap metadata. The app's normal `main()` and root widget remain ordinary
application code. The analyzer was already a formatter dependency; it is now
declared directly in `patrol_recorder_generator` for its development CLI. The
runtime recorder does not depend on analyzer or generator code.

**Expanded example coverage**

| Surface | Added scenarios | Evidence/boundary |
| --- | --- | --- |
| Login/dashboard | Stable page semantics and navigation | Existing keyed login behavior retained; source contains no typed values |
| Animation lab | Slide/scale, animated size/color, cross-fade, bounded loading, expansion tile | Finite animations complete; no claim for endless animation settling |
| Repeated controls | Duplicate Continue labels and identical icon buttons in keyed cards | Ancestor scoping selects the intended card without coordinate/index fallback |
| Forms/overlays | TextFormField validation, dropdown, bottom sheet and information dialog | Automatic input references and active-overlay capture names |
| Settings | Switch/checkbox tiles, confirmation dialog, snackbar and long list | Tap workflows and target-based scrolling are supported |

Widget tests exercise these surfaces with an automatic recorder wrapper and no
action hooks. Real DevTools recorded
[complex_ui.yml](../example/patrol_recorder/complex_ui.yml), containing 16 actions
and four named captures (`animation_expanded`, `repeated_controls`,
`information_dialog`, `settings_reset`). The CLI generated its code and official
Patrol web execution passed, including disambiguation of Continue within
`business_card`. At that milestone, the re-recorded
[yaml_login.yml](../example/patrol_recorder/yaml_login.yml) used schema 2 and
stable login/account images; its test passed using inferred main and the existing
secondary-profile input provider. Current recordings use schema 3.

These results expand the verified matrix rather than establish universal Flutter
or native-platform support. Continuous animations, arbitrary custom gestures,
native views and whole-page capture remain outside the demonstrated slice.

### Protocol-5 interaction and async follow-up

This is the current bounded implementation, superseding earlier milestone
statements that scroll and long-press observation were unsupported.

- Runtime protocol 5 observes inline hyperlink activation through public Flutter
  text-range APIs, long presses, and drag, wheel, pan/zoom, and accessibility
  scrolling. Scroll-position listeners preserve standard pointer-scroll
  observation when an ancestor consumes `ScrollNotification`s; listener cleanup
  covers stop, disposal, and replaced positions. Programmatic `jumpTo` without
  user intent does not create a user-action step.
- Generated scrolling uses unique primary-scrollable selection, axis validation,
  and Patrol's public continuous `scrollUntilVisible` API to reach an identified
  visible item. It is target-based, not exact-offset reproduction. Coordinate and
  index fallbacks remain prohibited.
- Generated actions use bounded visibility/enabled waits and `SettlePolicy.noSettle`
  rather than global settling after each action. `wait_timeout_ms` defaults to
  15000 (range 100-120000); `max_scrolls` defaults to 60 (range 1-200).
- New recordings use schema 3. Schemas 1 and 2 remain readable. Link text must be
  unique in a keyed paragraph; duplicate links need distinct keyed paragraphs or
  a keyed `TextButton`/`WidgetSpan`.
- The async example covers a looping animation, inline Terms link, local delayed
  readiness, lazy paginated options, a long press, stable keys, and the named
  `async_loaded` screenshot. Its delays are local fixtures, not network calls.
  The preserved test wrapper waits for and asserts the selection result, long
  press result, and animation switch state.
- Arbitrary futures/business-state changes are not intercepted. Custom painting,
  opaque platform views, pinch/slider-specific gestures, and unsupported custom
  widgets are not universally inferred. Keys improve identity but cannot make
  unsupported gestures observable; application source is never modified to add
  keys. Final user assertions need their own bounded outcome waits.

The regression coverage includes consumed-notification drag and wheel scrolling,
listener detachment after Stop, position replacement, and programmatic scrolling.
Verification for this follow-up passed: **41 runtime tests, 19 generator tests,
6 DevTools workflow tests, and 8 example tests**; analysis was clean in all four
packages. The bundled extension rebuilt and passed official validation. The
three current Patrol journeys (`async_flow`, `complex_ui`, and `yaml_login`)
passed together in headless Chrome (**3/3**), including the async journey's
bounded final assertions. These are current results, distinct from historical
milestone counts above. Mobile/device validation was not performed.

## 15. Historical approval boundary

At the time of this record, the initial integrated proof and bounded
automatic-observation follow-up were complete, and the broader M2-M5 editor and
execution workflow remained approval-gated. See the [current roadmap](ROADMAP.md)
for the active milestone status and next steps. No package publication is
authorized by this record.

## Sources

Public sources were checked on 22 October 2026. Mutable documentation can advance; the resolved versions and experimental limitations above are the compatibility evidence for this plan.

- **[S1]** [Flutter DevTools extensions](https://docs.flutter.dev/tools/devtools/extensions) and [custom tool authoring](https://docs.flutter.dev/tools/devtools/custom-tool).
- **[S2]** [`devtools_extensions` API/package documentation](https://pub.dev/documentation/devtools_extensions/0.5.1/) and [package metadata](https://pub.dev/api/packages/devtools_extensions).
- **[S3]** [`registerExtension`](https://api.dart.dev/dart-developer/registerExtension.html), [`postEvent`](https://api.dart.dev/dart-developer/postEvent.html), and [`vm_service`](https://pub.dev/packages/vm_service).
- **[S4]** [DTD file-system public API source](https://github.com/dart-lang/sdk/blob/main/pkg/dtd/lib/src/services/file_system_service.dart) and [`dtd` documentation](https://pub.dev/packages/dtd).
- **[S5]** [`patrol` metadata](https://pub.dev/api/packages/patrol) and [`PatrolIntegrationTester`](https://pub.dev/documentation/patrol/4.10.0/patrol/PatrolIntegrationTester-class.html).
- **[S6]** [`patrol_finders`](https://pub.dev/packages/patrol_finders) and [public finder implementation](https://github.com/leancodepl/patrol/blob/master/packages/patrol_finders/lib/src/custom_finders/patrol_finder.dart).
- **[S7]** [Patrol compatibility table](https://patrol.leancode.co/documentation/compatibility-table), [CLI metadata](https://pub.dev/api/packages/patrol_cli), and [test command](https://patrol.leancode.co/cli-commands/test).
- **[S8]** [`SemanticsProperties.identifier`](https://api.flutter.dev/flutter/semantics/SemanticsProperties/identifier.html) and [`find.bySemanticsIdentifier`](https://api.flutter.dev/flutter/flutter_test/CommonFinders/bySemanticsIdentifier.html).
- **[S9]** [`PointerRouter.addGlobalRoute`](https://api.flutter.dev/flutter/gestures/PointerRouter/addGlobalRoute.html), [`NavigatorObserver`](https://api.flutter.dev/flutter/widgets/NavigatorObserver-class.html), [`TextEditingController`](https://api.flutter.dev/flutter/widgets/TextEditingController-class.html), and [`ScrollNotification`](https://api.flutter.dev/flutter/widgets/ScrollNotification-class.html).
- **[S10]** [`RenderRepaintBoundary.toImage`](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html).
- **[S11]** [`gesture_recorder`](https://pub.dev/packages/gesture_recorder), [published licence](https://pub.dev/packages/gesture_recorder/license), [recorder source](https://github.com/chooyan-eng/gesture_recorder/blob/main/packages/gesture_recorder/lib/src/recorder.dart), and [IDE export helper](https://github.com/chooyan-eng/gesture_recorder/blob/main/packages/gesture_recorder_devtools_extension/lib/ide_communicator.dart).
- **[S12]** [`automated_integration_test`](https://pub.dev/packages/automated_integration_test), [metadata](https://pub.dev/api/packages/automated_integration_test), and [published licence](https://pub.dev/packages/automated_integration_test/license).
- **[S13]** [`flutter_flight_recorder`](https://pub.dev/packages/flutter_flight_recorder), [metadata](https://pub.dev/api/packages/flutter_flight_recorder), and [licence](https://pub.dev/packages/flutter_flight_recorder/license).
- **[S14]** [`screenshot`](https://pub.dev/packages/screenshot) and [licence](https://pub.dev/packages/screenshot/license).
- **[S15]** [`file_selector` platform feature matrix](https://pub.dev/packages/file_selector) and [metadata](https://pub.dev/api/packages/file_selector).
- **[S16]** [Browser File System Access requirements](https://developer.chrome.com/docs/capabilities/web-apis/file-system-access), [`web`](https://pub.dev/packages/web), and [DevTools iframe sandbox implementation](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/extensions/embedded/_controller_web.dart).
- **[S17]** [`archive` metadata](https://pub.dev/api/packages/archive) and [licence](https://pub.dev/packages/archive/license).
- **[S18]** [`takeNativeScreenshot` contract](https://pub.dev/documentation/patrol/4.10.0/patrol/PatrolIntegrationTester/takeNativeScreenshot.html), [Patrol screenshot requirements](https://patrol.leancode.co/cli-commands/test#screenshots), and [Android screencap documentation](https://developer.android.com/tools/adb#screencap). Simulator support was additionally checked with the installed `xcrun simctl io help`.
- **[S19]** [DevTools extension configuration specification](https://github.com/flutter/devtools/blob/master/packages/devtools_extensions/extension_config_spec.md).
- **[S20]** [Dart package publishing requirements](https://dart.dev/tools/pub/publishing).
- **[S21]** [Maestro Flutter architecture and limitations](https://docs.maestro.dev/get-started/supported-platform/flutter) and [selector design](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/how-to-use-selectors).
- **[S22]** [Current Maestro Studio interactive test creation](https://docs.maestro.dev/maestro-studio/run-tests-with-maestro-studio) and [public Studio repository](https://github.com/mobile-dev-inc/maestro-studio).
- **[S23]** [Maestro Android accessibility hierarchy implementation](https://github.com/mobile-dev-inc/Maestro/blob/main/maestro-android/src/androidTest/java/dev/mobile/maestro/ViewHierarchy.kt), inspected on 22 October 2026; GitHub file blob SHA `e23311f538c3667d1deccf7c0dc4756d9399fb6d`.
- **[S24]** [`SemanticsBinding.addSemanticsActionListener`](https://api.flutter.dev/flutter/semantics/SemanticsBinding/addSemanticsActionListener.html) and [Flutter semantics binding source](https://github.com/flutter/flutter/blob/main/packages/flutter/lib/src/semantics/binding.dart).
- **[S25]** [`FocusNode.context`](https://api.flutter.dev/flutter/widgets/FocusNode/context.html), [`EditableText.controller`](https://api.flutter.dev/flutter/widgets/EditableText/controller.html), and [`EditableText.obscureText`](https://api.flutter.dev/flutter/widgets/EditableText/obscureText.html). The installed SDK and the linked widget-harness experiments were also checked.
- **[S26]** [Maestro Flows overview](https://docs.maestro.dev/maestro-flows/readme), [parameters/constants](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/parameters-and-constants), and [selectors](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/how-to-use-selectors), reviewed for the YAML architecture follow-up. Reference only, not a dependency or claim of compatibility.
