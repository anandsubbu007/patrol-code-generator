# Patrol Recorder Roadmap

Research and status snapshot: **2026-10-23**. This is the proposed product
roadmap, not authorization to implement runtime features or publish releases.
It supersedes stale milestone/version statements in earlier drafts. Detailed
implementation and test evidence is in the
[implementation history](IMPLEMENTATION_HISTORY.md) and
[integrated proof report](INTEGRATED_PROOF_RESULTS.md).

## 1. Current state

### Verified capabilities

| Capability | Status | Evidence and boundary |
| --- | --- | --- |
| In-app automatic recording | **Implemented and tested** | Debug-only Flutter observation of standard pointer and semantics actions, long-press candidates, focused text activity, and scrolls. The observer has explicit widget/control allowlists; it is not a universal gesture recorder. [Runtime](../lib/src/observation.dart), [scroll observer](../lib/src/scroll_observation.dart), [interaction tests](../test/interaction_test.dart). |
| Widget identification | **Implemented and tested** | Key-first selectors, semantics identifiers, unique public labels/text, and unique key/identifier ancestor scopes. Ambiguous targets become review-required unsupported steps; coordinates/indexes are not fallback selectors. This is fail-closed, not self-healing across app changes. [Selector resolver](../lib/src/observation.dart), [recorder tests](../test/patrol_recorder_test.dart). |
| Dynamic text inputs | **Partially implemented** | Inputs are references, not captured values; obscure/sensitive input references are flagged. However, `TextEditingController` notifications also include selection, composition, and programmatic changes, so notification does not prove that a user entered text. [Input observer](../lib/src/observation.dart), [feasibility test](../test/automatic_observation_feasibility_test.dart). |
| Unsupported actions | **Implemented and tested** | Unsupported gestures produce explicit review-required steps; included unresolved/unsupported actions do not silently become runnable generated actions. Exclusion and acknowledgement are explicit. Real-host breadth remains limited. [Journey validation tests](../tool/patrol_recorder_generator/test/journey_test.dart), [limits](../README.md#limits-and-troubleshooting). |
| DevTools and saved recordings | **Implemented and tested** | The extension connects to the selected app, writes autosaved YAML through authorized DTD workspace access, and reports save failures. It is a DevTools panel, not a complete timeline editor or test runner. [Extension workflow](../tool/devtools_extension/README.md), [workflow tests](../tool/devtools_extension/test/workflow_test.dart). |
| YAML and test generation | **Implemented and tested** | Schemas 1–5, typed input contracts, authored cases/fixtures, selector inspection/overrides, bounded widget expectations, and ordinary Patrol Dart output. Generated wrappers explicitly leave business-outcome assertions to the application owner. [Generator](../tool/patrol_recorder_generator/lib/src/generator.dart), [journey guide](../tool/patrol_recorder_generator/README.md#authored-journeys). |
| Regeneration safety | **Implemented, with a recovery gap** | Generated markers gate updates; user-owned providers and test wrappers are preserved; project paths and symlinks are checked. Local files are replaced one at a time; DTD has no multi-file transaction, so an interrupted batch can leave partial generated output with an explicit error. [Export policy](../tool/patrol_recorder_generator/lib/src/file_export.dart), [local generation](../tool/patrol_recorder_generator/lib/src/local_generation.dart), [generator tests](../tool/patrol_recorder_generator/test/generator_test.dart). |
| Screenshots | **Capture implemented and tested; comparison missing** | Captures are PNGs of the visible Flutter repaint boundary. `RecorderSensitive`, `RecorderIgnore`, and obscured text fields are masked; arbitrary unmarked sensitive content is not automatically classified. There is no screenshot comparator, baseline/history manager, or visual-regression workflow. [Capture implementation](../lib/src/recorder.dart), [mask tests](../test/patrol_recorder_test.dart), [scope and limitations](../README.md#screenshots-and-demo). |
| Reproducible compatibility | **Implemented but insufficiently verified** | CI covers Flutter 3.32.0 / Dart 3.8.0 package tests, Flutter 3.41.0 / Dart 3.11.0, and Flutter 3.47.7 / Dart 3.13.5, with downgraded analyzer/formatter coverage at the minimum. Full recording/replay proof remains the newer Flutter Web run, not a DevTools-host or platform support matrix. [CI](../.github/workflows/ci.yml), [environment limits](../README.md). |

The runtime package depends only on Flutter; generator and DevTools dependencies
are separate tooling dependencies. The checkout declares version 0.0.6, with
recorder/generator constraints of Dart >=3.8.0 <4.0.0 and Flutter >=3.32.0
(including Dart 3.11), and SDK-compatible analyzer/formatter ranges. Extension
source builds require Dart >=3.9.0 / Flutter >=3.35.0; consumers use compiled
assets. Older-SDK package tests do not establish a full DevTools/Patrol support
matrix. The
[implementation history](IMPLEMENTATION_HISTORY.md) and [proof report](INTEGRATED_PROOF_RESULTS.md)
document the tested versions and recorded Web run. Do not infer support for
Android, iOS, desktop, native dialogs, or full-device screenshots from Flutter
or Patrol support alone.

### Competitor maturity and capability matrix

Counts below are public signals observed on or near the research date; downloads,
stars, likes, and issue counts are not reliability proof. Dates refer to
published package metadata or source history; where a project has no independent
release stream, that limitation is stated explicitly.

| Project | Release, maintenance, tests, and adoption evidence | Verified mechanism / capability | Relevance to `patrol_recorder` |
| --- | --- | --- | --- |
| [`automated_integration_test`](https://pub.dev/packages/automated_integration_test) | Versions 1.0.0–1.0.4 were published 2025-03-26 to 2025-03-27 ([release metadata](https://pub.dev/api/packages/automated_integration_test)); latest 1.0.4. The package declares Dart `>=3.0.0 <4.0.0` and Flutter `>=3.0.0`. The declared [GitHub repository](https://github.com/fahadazizz/automated_integration_test) and issue tracker return 404 and pub.dev flags the repository unreachable. No current issue history, CI, or maintenance activity is verifiable. Pub.dev showed 3 likes and 47 downloads. **License: MIT**, but its archived [license text](https://pub.dev/packages/automated_integration_test/license) has an unfilled `[Your Name]` copyright. | The [1.0.4 archive](https://pub.dev/api/archives/automated_integration_test-1.0.4.tar.gz) uses an app-wrapping singleton and widget observers, then generates `find.text`/`find.byType` tests. It serializes raw text-field values, including obscured values, and catches generation/persistence errors into print/empty-result behavior. No screenshot or visual comparison mechanism found. Claimed Web support conflicts with its package dependency analysis. | **Do not adopt.** Its generated text/type selectors and callbacks are less resilient than our unique, key-first targets; plaintext input capture and weak error reporting conflict with recorder privacy/correctness. Source is available only from the pub archive, not a maintained repository. |
| [`user_interaction_recorder`](https://pub.dev/packages/user_interaction_recorder) | Versions 0.3.0–0.3.2 were all published within about 5.5 minutes on 2025-11-13 ([release metadata](https://pub.dev/api/packages/user_interaction_recorder)); latest 0.3.2. No earlier pub.dev version exists under this package name; a README rename note does not establish a prior published release. Its declared [repository](https://github.com/AhmedSlman/Flutter-Event-Recorder) returns 404, so commits/issues/CI cannot be checked. The package declares Dart `^3.0.0` and Flutter `>=3.0.0`, with SharedPreferences, BLoC 8, and Equatable 2 dependencies. Pub.dev showed 2 likes and 10 downloads. Its shipped test imports a library path absent from the archive. **License: MIT.** | The [0.3.2 archive](https://pub.dev/api/archives/user_interaction_recorder-0.3.2.tar.gz) contains a clean-architecture/BLoC model, manually registered widget IDs and recorder wrappers, SharedPreferences persistence, and an event replay use case. It is not passive instrumentation despite broad marketing claims. Its event model stores values without verified sensitive-data redaction. No screenshot comparison found. | **Do not adopt.** Registry IDs and persistence are understandable patterns, but require app instrumentation and do not solve selector resilience or privacy better than current code. Its source and issue history are unavailable and its test/dependency evidence is weak. |
| [Patrol DevTools extension](https://patrol.leancode.co/documentation/other/patrol-devtools-extension) | Bundled with Patrol tooling, not independently published. Its changelog lists versions 0.2.1–0.4.1 and an unreleased section at the 2026-10-22 repository head; dated extension releases are not recorded. The monorepo root is **Apache-2.0**; the extension has no separate license file, so inheritance is inferred. | Inspects Android/iOS native UI trees, shows element properties, refreshes the tree, and copies `NativeSelector` examples. This is selector discovery for authored tests—not interaction recording, test generation, screenshot capture, or visual comparison. | **Reuse the inspection principle, not the implementation.** Our recorder discovers Flutter widgets in the app isolate; the extension explores native hierarchy outside that tree. Patrol native selectors cannot substitute for Flutter `Finder`s. |
| [DeploySentinel/Recorder](https://github.com/DeploySentinel/Recorder) | First version bump 0.1.0 on 2021-11-18; latest functional bump v0.7.1 on 2022-07-26. Archived read-only on 2026-10-14. The repository had 506 stars, 45 forks, and 11 open issues at archival; reported issues include iframe/extension-page gaps and an unresponsive-page bug. Its [README](https://github.com/DeploySentinel/Recorder/blob/main/README.md) describes Jest tests and GitHub Actions, but historical passing CI runs were not verified. This is a Chrome/Firefox browser extension, not a Flutter/Flutter-platform package. **License: Apache-2.0** ([package metadata](https://github.com/DeploySentinel/Recorder/blob/main/package.json), [license](https://github.com/DeploySentinel/Recorder/blob/main/LICENSE)). | Browser extension observes DOM clicks, keyboard input, resize and scroll; selector preference includes `id`/`class`, then accessibility/name/test-id attributes. It emits Cypress/Playwright/Puppeteer code, hover and text assertions, and full-page screenshot **events**. No image comparison algorithm, thresholds, or masking workflow was verified. | **Design reference only.** Its selector preference/fallback and explicit assertion authoring are useful concepts, but DOM selectors/events do not map to Flutter elements, and the archived project is not a maintained dependency. Screenshot events are not visual comparison. |
| [Flutter `integration_test`](https://docs.flutter.dev/cookbook/testing/integration/introduction) | First-party SDK package maintained in the Flutter monorepo; not independently semver-published, so it has no separate first/latest pub release dates. The linked docs were last updated 2026-05-05. It has SDK CI/release coverage, not a separate recorder issue/release history. **License: Flutter BSD-3-Clause** ([package source](https://github.com/flutter/flutter/tree/master/packages/integration_test), [package manifest](https://github.com/flutter/flutter/blob/master/packages/integration_test/pubspec.yaml), license text at the Flutter repository root). | Runs app-level Flutter tests using `flutter_test` APIs, can run on devices or from the host, and offers screenshot callbacks; it cannot operate native platform UI. It does not record interactions or generate tests. | **Execution substrate, not a recorder competitor.** Keep generated tests in ordinary Flutter/Patrol APIs; do not add a competing runner. |
| [Patrol](https://github.com/leancodepl/patrol) | First pub.dev version observed: 0.6.0 on 2022-09-12; latest stable 4.10.0 on 2026-09-15 ([release metadata](https://pub.dev/api/packages/patrol)); 4.11.0-dev.1 prerelease on 2026-09-20. Multiple releases and daily repository activity were visible in October 2026 ([commit history](https://github.com/leancodepl/patrol/commits/master/)). Public signals included about 1,451 stars, 654k pub downloads, 1,159 closed and 163 open issues. Examples of long-lived platform issues include [Android WebView flakiness](https://github.com/leancodepl/patrol/issues/244), [LambdaTest instrumentation](https://github.com/leancodepl/patrol/issues/2493), and [simulator coverage crashes](https://github.com/leancodepl/patrol/issues/2794). Pub.dev package analysis does not list Windows/Linux/WASM support. Commercial LeanCode support/training is also offered. **License: Apache-2.0** ([license](https://github.com/leancodepl/patrol/blob/master/LICENSE)). | Integration-test framework extending Flutter test execution with native Android/iOS automation and native selectors. Its [DevTools extension](https://github.com/leancodepl/patrol/blob/master/packages/patrol_devtools_extension/CHANGELOG.md) inspects native nodes. Patrol has no passive recording/code generation. | **Already our replay foundation.** Preserve Patrol compatibility and ordinary test ownership. Its native test capabilities do not prove this recorder's native observation/capture behavior. |

The two pub.dev recorder packages' repositories being unavailable limits
verification to their published archives and pub.dev metadata. Their issue
histories, CI outcomes, and ongoing support cannot be asserted. No downloads,
stars, or self-reported feature tables are treated as proof of production
reliability.

### Source-backed architecture findings

- **Selectors:** DeploySentinel's DOM-property priority is not portable to
  Flutter's element tree. Patrol's native tree inspector targets platform
  elements, while this recorder resolves Flutter `Element`s, semantics data,
  render hit tests, and exact unique selectors. Our implementation deliberately
  rejects coordinates/indexes and does not fuzzy-repair a changed target.
- **Interaction capture:** Our runtime observes Flutter pointer routing,
  semantics actions, focus/controller changes, and scroll notifications/
  positions. Its allowlisted widget/control analysis avoids replacing global
  callbacks. It differs from wrappers around every widget (the user recorder
  package), browser DOM event listeners, and Patrol's test-time native driver.
  These mechanisms are not drop-in substitutes.
- **Inputs and secrets:** Our YAML records input references and secret flags,
  never raw text values; input values are supplied by user-owned providers. This
  is safer than the two published recorder archives, but event provenance is
  incomplete because controller notifications can be selection/programmatic
  changes. Never infer that a change notification proves a user typed.
- **Test data and assertions:** Generated inputs, profiles, assets, cases, and
  bounded widget expectations are supported. App-specific business outcomes
  remain in user-owned test wrappers. Automatically inferring domain assertions
  from taps or screenshots is unsupported by the inspected references and
  would be misleading.
- **Persistence and regeneration:** User-owned files are preserved; generated
  files are gated by markers and checked before replacement. Neither local batch
  output nor DTD export is a multi-file transaction. The extension explicitly
  reports partial-write errors; do not claim atomicity.
- **Screenshots:** Recorder capture is distinct from comparison. Flutter's
  `matchesGoldenFile` default local comparator does a pixel-for-pixel PNG
  comparison (zero tolerated differences) and reports master/test/diff images.
  It does not provide configurable thresholds or privacy-region masking. Flutter
  documents font and SDK/platform variation as sources of golden failures.
  Therefore a checksum, screenshot event, or capture is not visual regression.
- **Platform coverage:** The recorder's verified end-to-end path is Flutter Web.
  Patrol's native UI support is useful for generated native tests, but it does
  not make our DevTools DTD, Flutter repaint-boundary capture, or observation
  mechanism verified on mobile.

### Implementation gap analysis

| Capability | Classification | Evidence-based gap |
| --- | --- | --- |
| Unique Flutter widget selectors | **Already implemented and tested** | Add drift/rebuild regression cases; keep ambiguity as a hard failure, not an invitation to choose a nearby widget. |
| Controller-change provenance | **Partially implemented** | Values are not recorded, but changes without user-origin proof can still create input-reference steps. |
| Dynamic input providers | **Implemented and tested** | References, typed contracts, secret references and user-owned providers exist; provider completion and real test data remain app-owned. |
| Meaningful business assertions | **Partially implemented** | Bounded widget assertions exist, but final domain outcomes must be authored by developers in preserved test wrappers. |
| Unsupported interaction reporting | **Implemented and tested** | Unit/generator validation is fail-closed; continue validating the real DevTools review/exclusion path and ensure it never hides a step. |
| Safe regeneration | **Implemented, insufficiently failure-tested** | Ownership checks protect authored files; interrupted multi-file writes need a clearer recovery/retry story, not a false atomicity claim. |
| Screenshot capture/masking | **Implemented and tested** | Flutter viewport PNG and marked/obscured masking exist. Unmarked sensitive UI cannot be detected generically. |
| Screenshot comparison | **Missing; not worth adopting yet** | No inspected recorder performs verified visual comparison. Flutter golden comparison is exact-pixel and test-environment sensitive, with no built-in mask/threshold. |
| Reproducible support matrix | **Implemented but insufficiently tested** | CI now checks minimum, Dart 3.11, and pinned release toolchains. Only Web end-to-end is demonstrated; package tests do not establish older DevTools-host or cross-platform workflow compatibility. |
| Native interaction recording/full-device capture | **Technically incompatible with current proof / not worth adopting now** | Patrol's native hierarchy is outside our Flutter widget tree; a separate native host architecture would be required. |

## 2. Reliability foundations

### R1 — Establish text-input event provenance

- **User problem:** Programmatic controller writes, selection updates, or IME
  composition can look like user text entry and produce a misleading replay step.
- **Proposed behavior:** Record an input reference only when a supported public
  signal establishes user-originated editing; otherwise show a review-required
  input-activity event. Continue to discard text values.
- **Reference and evidence:** Flutter's controller API and the repository's
  [feasibility test](../test/automatic_observation_feasibility_test.dart) prove
  that controller notifications include selection and programmatic changes.
  Neither accessible recorder archive handles secrets safely.
- **Current status:** Partially implemented; raw text is not buffered, but
  controller-change provenance is unresolved.
- **Expected impact:** High trust and privacy for generated dynamic-input steps.
- **Effort:** M.
- **Risk / compatibility:** Flutter public input APIs may not distinguish every
  IME, paste, autofill, hardware-keyboard, and programmatic path. Do not rely on
  private framework APIs or capture raw strings.
- **Dependencies:** A focused prototype using supported Flutter APIs; no new
  runtime package dependency.
- **Acceptance criteria:** Real user-originated edits create a reference-only
  step; programmatic/selection-only changes do not become a runnable
  `enterText`; ambiguous provenance is visible and reviewable; no entered value
  appears in snapshots, YAML, logs, or generated code.
- **Automated tests / experiments:** Widget tests for IME entry, selection,
  composing changes, paste/autofill where available, programmatic writes,
  disposal, and listener cleanup; real Web check before claiming support.
- **Priority:** P1.

### R2 — Make generation failure recovery explicit

- **User problem:** A disk/DTD failure during a multi-file update can leave some
  generated outputs refreshed and others stale.
- **Proposed behavior:** Preflight all targets, report exactly which files were
  written/preserved/failed, and make retry deterministic. Never overwrite
  user-owned files or claim the entire batch is atomic.
- **Reference and evidence:** Our [export policy](../tool/patrol_recorder_generator/lib/src/file_export.dart)
  and [DTD documentation](../tool/devtools_extension/README.md) explicitly
  describe the multi-file transaction limitation and partial-write errors.
  Neither the inspected recorder competitor nor DTD offers a verified
  transaction to adopt.
- **Current status:** Ownership/marker guards and per-file local temp replacement
  exist; batch recovery is insufficiently tested.
- **Expected impact:** Lower risk of stale/mixed generated tests and faster
  recovery after interrupted exports.
- **Effort:** M.
- **Risk / compatibility:** DTD cannot guarantee exclusive create or atomic
  multi-file commit. Any recovery must re-check marker ownership and file content
  before touching output.
- **Dependencies:** Keep existing file APIs; no new runtime dependency or
  deletion/rollback of unknown files.
- **Acceptance criteria:** Simulated failure at every write boundary reports
  precise partial state; rerun repairs only recognized generated files; authored
  wrappers, inputs, YAML and unrelated files remain byte-for-byte unchanged.
- **Automated tests / experiments:** Fault-injection tests for local workspace
  and DTD abstraction, concurrent modification, failed readback, and safe retry.
- **Priority:** P1.

## 3. Near-term priorities

### N1 — Verify clean consumer setup and the declared compatibility floor

- **User problem:** A pinned CI pass does not prove the minimum declared Flutter,
  Dart, DevTools, Patrol, and Patrol CLI combination works for a new user.
- **Proposed behavior:** Maintain an explicit tested matrix: minimum supported
  Flutter, current stable Flutter, bundled DevTools, Patrol/CLI versions, and
  verified platforms. Add a clean consumer path and a small headless Web record
  or replay smoke test where CI can reliably support it.
- **Reference and evidence:** Flutter's official
  [`integration_test`](https://docs.flutter.dev/cookbook/testing/integration/introduction)
  follows the SDK release cycle; Patrol's release/CI cadence is active but still
  has platform-specific issues. Our [CI](../.github/workflows/ci.yml) checks
  Flutter 3.32.0 / Dart 3.8.0, Flutter 3.41.0 / Dart 3.11.0, and the pinned
  release toolchain Flutter 3.47.7 / Dart 3.13.5.
- **Current status:** Minimum-floor package/widget and generated-code tests are
  covered, including older analyzer/formatter resolution. Full Web proof still
  uses the release toolchain; older DevTools hosts and broad platform
  compatibility are not verified.
- **Expected impact:** Fewer setup failures and fewer accidental support claims.
- **Effort:** M.
- **Risk / compatibility:** Toolchain matrices increase CI time; only test a
  second version when reproducible and meaningful. Do not declare platform
  compatibility solely from dependency resolution.
- **Dependencies:** Clean hosted-package consumer setup after approved package
  publication; no new runtime dependency.
- **Acceptance criteria:** CI or documented release checks pass on the declared
  minimum and current stable version; extension builds/validates; a clean
  consumer generates and executes the maintained Web example; docs distinguish
  verified from unverified targets.
- **Automated tests / experiments:** Package archive validation, dependency
  resolution without local overrides, extension build/validation, generator
  CLI, and bounded Patrol Web smoke run.
- **Priority:** P1.

### N2 — Preserve review-first unsupported actions and business assertions

- **User problem:** A test that replays taps without checking the intended
  business outcome is not meaningful; an unsupported gesture must not disappear
  or turn into a plausible but incorrect action.
- **Proposed behavior:** Keep unresolved actions visible with reasons, require an
  explicit exclude/acknowledge choice, and strengthen the example/preserved
  wrapper with bounded app-specific outcome assertions. Never infer a business
  assertion from an interaction or screenshot.
- **Reference and evidence:** Flutter describes integration tests as validating
  complete app behavior; Patrol is the execution framework, not an assertion
  inference engine. Our
  [generator test scaffold](../tool/patrol_recorder_generator/lib/src/generator.dart)
  deliberately leaves a TODO for bounded outcome assertions, and
  [journey tests](../tool/patrol_recorder_generator/test/journey_test.dart)
  reject included unsupported steps.
- **Current status:** Fail-closed generation and user-owned wrappers exist;
  end-user review completeness and business assertions need stronger maintained
  examples.
- **Expected impact:** More honest, diagnosable generated tests and less false
  confidence.
- **Effort:** S.
- **Risk / compatibility:** Avoid adding assertion DSLs or generating
  domain-specific assumptions. Preserve manually authored test files on every
  regeneration.
- **Dependencies:** Existing schema and generator only.
- **Acceptance criteria:** Every included step is supported and resolved or
  generation fails with a reason; exclusions are explicit; example replay
  asserts its business outcome; regeneration preserves those assertions.
- **Automated tests / experiments:** Generator tests for included/excluded
  unsupported events, extension workflow tests for review state, and a Patrol
  replay that fails when the expected business outcome is deliberately absent.
- **Priority:** P1.

### N3 — Expand selector regression coverage without fuzzy recovery

- **User problem:** App refactors, repeated labels, and rebuilt lists can change
  which widget a selector resolves to.
- **Proposed behavior:** Keep key-first and unique scoped selectors; re-evaluate
  uniqueness at replay time and fail with actionable diagnostics when a target
  is absent or ambiguous. Do not auto-select by index, coordinate, or fuzzy text.
- **Reference and evidence:** Our [resolver](../lib/src/observation.dart) uses
  unique key/semantics/text candidates and ancestor scope. DeploySentinel's
  archived DOM recorder used a prioritized selector fallback, while Patrol's
  native extension is a separate native-tree inspector; neither proves
  cross-platform selector stability.
- **Current status:** Implemented and tested for current widget-tree cases;
  dynamic rebuild/refactor behavior needs more regression coverage.
- **Expected impact:** Prevents wrong-target actions from silently passing.
- **Effort:** S.
- **Risk / compatibility:** Finder behavior can vary with Flutter/Patrol upgrades.
  Restrict changes to public APIs and preserve explicit failure for unknown
  widget types.
- **Dependencies:** None; reuse current selector model and CLI inspection.
- **Acceptance criteria:** Duplicate labels resolve only with unique scope;
  duplicate keys, target removal, rebuild, and changed labels fail closed; no
  generated coordinate/index fallback appears.
- **Automated tests / experiments:** Widget-tree mutation/rebuild tests,
  generator output assertions for every selector kind, and bounded replay
  tests against Patrol finders.
- **Priority:** P1.

## 4. Mid-term improvements

### M1 — Evaluate screenshot comparison only in a controlled test workflow

- **User problem:** Captured screenshots show a state but do not detect visual
  regressions.
- **Proposed behavior:** If user demand is demonstrated, prototype an opt-in
  test-only comparison using Flutter golden infrastructure in a pinned
  environment; keep capture and comparison as separate features and never
  compare automatically during recording.
- **Reference and evidence:** Flutter
  [`matchesGoldenFile`](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)
  with the default
  [`LocalFileComparator`](https://api.flutter.dev/flutter/flutter_test/LocalFileComparator-class.html)
  performs exact pixel-for-pixel PNG comparison, emits failure diff images, and
  documents font/SDK/platform variation. It has no built-in tolerated-difference
  threshold or privacy-region masking. DeploySentinel's screenshot event is
  capture, not comparison.
- **Current status:** Capture and marked/obscured masking are implemented;
  comparison is missing.
- **Expected impact:** Potentially useful visual regression checks, but only
  after environment and privacy constraints are proven.
- **Effort:** M for a test-only prototype; L for a maintained cross-platform
  workflow.
- **Risk / compatibility:** Exact pixels can create noisy failures across
  browser, fonts, Flutter versions, viewport, and platforms. Existing capture
  masking must be independently validated before any baseline is written.
- **Dependencies:** No runtime package. Use existing Flutter test dependencies
  for a prototype; defer third-party diff engines pending algorithm, license,
  maintenance, threshold, and masking review.
- **Acceptance criteria:** Prototype documents pixel policy, dimensions,
  environment pinning, intentional baseline update, privacy masks, and false
  positives; no automatic baseline rewrite; capture-only users gain no new
  dependency or behavior.
- **Automated tests / experiments:** Stable Web viewport experiment, exact
  comparator smoke test, masked-region leak test, intentionally changed pixel
  test, and repeat runs to measure nondeterministic pixels.
- **Priority:** P2.

### M2 — Validate mobile/native boundaries before expanding platform claims

- **User problem:** A Flutter widget recorder cannot observe native dialogs and
  platform views merely because generated Patrol tests can control some native
  UI.
- **Proposed behavior:** Build a small Android/iOS compatibility experiment for
  the existing Flutter-only observer, DTD connection, masking, and capture.
  Keep native actions explicitly unsupported unless a separately designed,
  supported host bridge can report them accurately.
- **Reference and evidence:** Patrol's native DevTools inspector copies
  platform-specific selectors; Flutter's official `integration_test` cannot
  interact with native UI. Neither inspected project supplies a drop-in bridge
  for this recorder's Flutter `Element` observer.
- **Current status:** End-to-end verification is Web-only.
- **Expected impact:** Accurate platform claims and early discovery of host API
  incompatibilities.
- **Effort:** L.
- **Risk / compatibility:** Native APIs, permissions, semantics and screenshot
  behavior differ by platform; a separate bridge would add maintenance and
  licensing/security review.
- **Dependencies:** Physical/emulated Android and iOS setup; do not add a plugin
  until a concrete use case and supported mechanism are demonstrated.
- **Acceptance criteria:** Publish a per-platform pass/fail matrix for record,
  save, generate, replay, and screenshot; unsupported paths report errors, not
  success-shaped results.
- **Automated tests / experiments:** Platform-specific smoke tests plus manual
  real-device validation for native UI and screenshot boundaries.
- **Priority:** P2.

## 5. Long-term opportunities

### L1 — Native interaction recording or full-device screenshots

- **User problem:** Some journeys cross from Flutter into native UI or require
  system chrome/keyboard capture.
- **Proposed behavior:** Consider a separate, opt-in host integration only if
  early adopters demonstrate demand and a supported API can preserve the
  current review/privacy guarantees.
- **Reference and evidence:** Patrol provides native test execution and a native
  tree inspector, not passive recording. Flutter's screenshot callback support
  is test infrastructure, not arbitrary device-wide capture.
- **Current status:** Missing and outside the verified recorder architecture.
- **Expected impact:** Could cover native flows, but increases platform-specific
  complexity substantially.
- **Effort:** XL.
- **Risk / compatibility:** Native permissions, OS policy, platform views,
  devices and host-side execution multiply failure modes and support burden.
- **Dependencies:** Demonstrated demand, feasibility prototype, explicit consent,
  platform/licensing/security review, and owner approval.
- **Acceptance criteria:** Separate proof for each platform and interaction;
  never imply current Flutter-only capture includes system UI.
- **Automated tests / experiments:** Device matrix, native selector disambiguation,
  privacy/masking checks, and failure-injection tests before any product scope.
- **Priority:** P3.

## 6. Explicit non-goals

- **No replacement for Patrol or Flutter integration testing.** Generated tests
  remain ordinary Patrol/Flutter tests.
- **No automatic business-assertion inference.** Developers know the domain
  outcome; recorded taps and screenshots do not.
- **No fuzzy, coordinate, or index-based selector fallback.** A failed target
  must be visible rather than a guessed action.
- **No screenshot comparison/history product now.** Existing PNG capture is not
  comparison. Flutter's exact comparator is test-environment-sensitive and has
  no built-in privacy masks or threshold; defer until evidence justifies cost.
- **No arbitrary native UI recorder, whole-device capture, video recorder, or
  custom E2E runner** without an approved architecture and platform proof.
- **No dependency adoption or copied code from the inspected competitors.**
  Their repository availability, maintenance, license provenance, privacy and
  compatibility do not justify code/dependency reuse. The root recorder's
  runtime dependency remains Flutter only.
- **No silent error swallowing, success-shaped fallbacks, automatic baseline
  updates, or overwriting developer-owned files.**

## 7. Open research questions

1. Which public Flutter APIs can distinguish user-originated text entry from
   programmatic, selection, composing, autofill, paste, and hardware-keyboard
   changes without reading the text value?
2. What is the minimum Flutter/Dart/DevTools/Patrol combination that can be
   supported and continuously tested? The checked-in CI currently tests one
   pinned toolchain.
3. Can a useful visual-diff workflow preserve private-region masks and remain
   stable across fonts, browser versions, pixel ratios, animations, and viewport
   sizes? No inspected recorder establishes a threshold or false-positive
   strategy.
4. What demand exists for Android/iOS recording beyond Patrol's native test
   controls and selector inspector, and which supported mechanism could bridge
   native events back to a Flutter journey?
5. Which DTD host/API versions are available in supported DevTools releases, and
   can export recovery be improved without implying atomic multi-file writes?
6. What source-history or maintainer evidence will become available if the
   unreachable repositories for `automated_integration_test` and
   `user_interaction_recorder` return? Until then, only their published archives
   and metadata are verifiable.

## Recommended adaptations: top five

1. **Establish a clean, reproducible Web consumer workflow** — **ready to
   implement**. It solves setup/version uncertainty; Flutter/Patrol show the
   value of maintained SDK/CLI contracts, while our CI currently pins one
   Flutter release. Adapt through a hosted-package install, extension validation,
   generator run, and bounded Patrol Web replay. Keep existing dependencies and
   licenses; no third-party recorder code is needed. Benefit is high, effort M.
   Verify minimum/current stable toolchains and package archives in CI.
2. **Prototype text-event provenance** — **needs a small prototype**. It prevents
   programmatic/selection notifications from becoming false inputs. Current
   code correctly omits values but cannot establish user origin; neither
   published recorder archive is a safe model. Adapt only with public Flutter
   APIs and preserve reference-only data. No dependency/license impact; high
   benefit, M effort. Verify by event-source tests and prove that values never
   enter protocol/YAML/logs.
3. **Keep unique selector failure closed and deepen regression tests** — **ready
   to implement**. It prevents wrong-widget replay. Patrol's inspector and
   DeploySentinel's selector priority illustrate explicit identity discovery;
   our key-first scoped resolver already provides the correct Flutter-specific
   pattern. Reuse no external code/dependency; low compatibility risk, S effort.
   Verify duplicate/rebuilt/removed targets fail clearly with no coordinate or
   index fallback.
4. **Improve generated-file recovery without weakening ownership** — **ready to
   implement**. It limits stale partial output after interruptions. Current
   marker checks and user-file preservation are a strong base, but writes are
   not batch-atomic. Do not adopt another recorder's persistence layer; retain
   local/DTD adapters and report partial status. No new dependency or license
   exposure; high benefit, M effort. Verify failures and retries at every file
   boundary while protecting user-owned files.
5. **Make unsupported steps and app outcomes impossible to overlook** — **ready
   to implement**. It prevents plausible but meaningless tests. Flutter/Patrol
   test whole application behavior; no competitor evidence justifies inferred
   business assertions. Keep user-owned wrappers and add maintained example
   assertions plus review-state tests. No new dependency; high impact, S effort.
   Verify included unsupported actions block generation, excluded ones are
   explicit, and a replay fails when its expected business result is absent.

**Screenshot decision:** Keep the current masked Flutter-content capture. Do not
recommend a comparison engine yet: screenshot events and checksums are not
visual comparison, and Flutter's default comparator is exact-pixel with no
built-in mask or tolerance. M1 is a P2 experiment only after demand and stable
test-environment evidence.
