# Milestone 1: integrated technical proof

**Completed:** 22 October 2026. **Approval boundary:** stop here; M2 is not authorized.

**Historical report:** the later requested automatic-observation implementation
removed the explicit hooks described here and moved example recording setup and
profiles to `patrol_test/`. See the [current results](PHASE_1_PLAN.md#automatic-implementation-results).
The original M1 outputs remain as historical fixtures.

This is a working, unpublished proof of concept, not the complete recorder.
The [plan](PHASE_1_PLAN.md) retains the remaining approval-gated milestones.

## Result

The actual chain was exercised:

```text
running Flutter web app
  -> explicit callback hooks
  -> VM Service / DWDS
  -> real Flutter DevTools extension
  -> Patrol Dart + separate editable profile data
  -> authorized DTD export + Flutter-content PNG
  -> official Patrol CLI web execution
```

No simulated DevTools host, custom E2E runner, unrestricted daemon, browser
filesystem bypass, or custom execution server was used. Browser automation drove
the real app and DevTools for verification; it is not a shipped execution engine.

## Environment

| Component | Verified version / target |
| --- | --- |
| Host | macOS 27.0.1, arm64 |
| Flutter / Dart | 3.47.7 stable / 3.13.5 |
| DevTools | 2.60.0, bundled with Flutter |
| Recording browser | Microsoft Edge 155.0.4283.62 through Flutter's Chrome target |
| DevTools extension / shared app libraries | 0.5.1 / 0.5.1 |
| DTD | 4.0.0 client, Flutter-managed host |
| Patrol / finders / CLI | 4.10.0 / 3.6.0 / 4.8.0 |
| Node | 22.23.4 for successful official Patrol runs |
| Official Playwright / Chromium | 1.56.0 / 141.0.7390.37, build 1194 |

These are tested versions, not a claim of support for every version admitted by
dependency constraints. No Android device or booted iOS simulator was available.

## What was implemented

- [Runtime/model](../lib/): opt-in debug-only recorder scope, explicit tap and
  input-reference callbacks, bounded recording buffer, service-extension protocol,
  sensitive-region capture exclusion, and bounded Flutter-content PNG capture.
- [Extension](../tool/devtools_extension/): actual DevTools connection, Start/Stop,
  observed actions, generated Dart/data preview, profile selection, capture,
  authorized workspace export, configuration loading, and Copy Run Command.
  M1 polls snapshots; the full event/lifecycle editor is deferred.
- [Generator](../tool/patrol_recorder_generator/lib/generator.dart) (subsequently extracted): stable case tags,
  semantics identifiers before string keys, normal Patrol APIs, separate editable
  data, named profiles, external secret references, and source formatting.
- [Exporter](../tool/devtools_extension/lib/src/exporter.dart): permission-bound DTD,
  safe relative paths, create-only preflight/recheck, preserved existing config,
  text readback, and explicitly limited PNG verification.
- [Example](../example/): login/form inputs, optional demonstration secret field,
  two public profiles, account navigation, and independent generated targets.
- Unit/widget tests, setup/privacy/schema documentation, BSD-3-Clause licence,
  and a locally built/validated extension bundle.

The root package has only Flutter as a runtime dependency. DevTools, formatting,
YAML, and protocol-client dependencies remain in the unpublished tooling app.

## Real-host acceptance evidence

| Gate | Observed result |
| --- | --- |
| Extension discovery | Enabled `patrol_recorder` in real DevTools and saw `Connected - ready`. The final rebuilt bundle was also reloaded successfully. |
| Real interaction | Started in the extension, edited Email and Note in the running app, and clicked **Open demo account**. The app navigated; the extension showed exactly three actions: two `enterText` references and one `tap`. |
| Observation boundary | Input values were not accepted by recorder hooks. Navigation was caused by the recorded tap, not represented as a separately observed navigation event. |
| Valid generated source | Generated source uses `$.enterText` with logging disabled and `$(find.bySemanticsIdentifier("demo.login")).tap()`, with an explicitly managed semantics handle. Analysis and actual Patrol execution passed. |
| Editable data | Source imports a sibling data file. `demo` and `secondary` profiles are public fictional defaults, not captured form contents. Data-unit tests verify independent edits and required-value errors. |
| Screenshot | Captured after stopping on the non-sensitive account page. Exported PNG is 2392 x 1669 RGBA, 37,568 bytes; signature, chunk CRCs, decompression, and metadata dimensions passed independent host checks. |
| DTD permissions | The Flutter-managed DTD supplied the example project as an authorized root. No trusted-client secret or root-setting RPC was used by the extension. |
| Complete persistence | Saved test, data, PNG, and `recording.json`; UI reported four saved files. Existing project configuration was preserved. |
| Overwrite refusal | Saving the same journey again displayed an explicit refusal naming the existing test. No overwrite option or automatic deletion was introduced. |
| Command copy | Read the actual browser clipboard and verified the target, unique tag, profile define, and supported Chrome/headless flags. |
| Runner | The exact UI-exported test passed through official `patrol test`. A three-target suite passed; a suite-wide case tag then selected exactly one test with `secondary`. |

### Persistent output

The real UI export is retained in
[browser_verified](../example/patrol_test/recorded_journeys/browser_verified/):

```text
browser_verified_test.dart
browser_verified_data.dart
recording.json
screenshots/session_1792644650631000_step_0003_flutter.png
```

The [test](../example/patrol_test/recorded_journeys/browser_verified/browser_verified_test.dart),
[data](../example/patrol_test/recorded_journeys/browser_verified/browser_verified_data.dart),
[metadata](../example/patrol_test/recorded_journeys/browser_verified/recording.json),
and [PNG](../example/patrol_test/recorded_journeys/browser_verified/screenshots/session_1792644650631000_step_0003_flutter.png)
are real saved outputs, not placeholders.

PNG SHA-256:

```text
b1e5298e36d5208af86493787bd35dead4a33f612f2ea08f22b0a0a1a3711df9
```

This checksum identifies the saved artifact; it is not visual comparison or
regression functionality. The PNG contains only Flutter-rendered app content,
not browser chrome, OS UI, notifications, or a system keyboard.

The `login` and `accounts` targets are generated demonstration fixtures. The
third target above is the actual browser-recorded export. Each bootstraps the
app independently; there is no discoverable suite file importing them.

## Verification commands and results

From the repository root:

```sh
dart format lib test
flutter analyze lib test
flutter test
```

**Passed:** formatting unchanged; clean analysis; **5 tests**.

From `tool/devtools_extension`:

```sh
dart format lib test tool
flutter analyze
flutter test
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
```

**Passed:** clean analysis; **6 tests**; production web build and official extension
validation. The build tool emits Flutter's deprecated `--pwa-strategy` warning;
this did not fail the build.

From `example`:

```sh
dart format lib test patrol_test/recorded_journeys
flutter analyze
flutter test
flutter test test/data_test.dart --dart-define=RECORDER_PROFILE=secondary
```

**Passed:** formatting unchanged; clean analysis; **5 tests**, then **3 data tests**
again with the secondary profile. That is **16 distinct unit/widget tests** across
the three packages, plus the explicit profile rerun.

With Node 22 directly on PATH, these official runner commands passed from `example`.
The globally activated CLI's executable directory was not on this host's PATH,
so validation used `dart pub global run patrol_cli:main`:

```sh
# Exact UI-exported test, stable case tag, public demo profile: 1 passed.
dart pub global run patrol_cli:main test \
  --target patrol_test/recorded_journeys/browser_verified/browser_verified_test.dart \
  --tags recorder_browser_verified_sign_in --dart-define RECORDER_PROFILE=demo \
  --device chrome --web-headless --web-timeout 30000 --web-global-timeout 180000

# All independently discovered targets: 3 passed, no duplicates.
dart pub global run patrol_cli:main test \
  --device chrome --web-headless --dart-define RECORDER_PROFILE=demo \
  --web-timeout 30000 --web-global-timeout 180000

# Filter the whole suite by one case tag: exactly 1 passed with secondary data.
dart pub global run patrol_cli:main test \
  --tags recorder_login_sign_in --dart-define RECORDER_PROFILE=secondary \
  --device chrome --web-headless --web-timeout 30000 --web-global-timeout 180000
```

The complete suite reported:

```text
accounts / Open account settings [demo]                         passed
browser_verified / Sign in with demonstration profile [demo]   passed
login / Sign in with demonstration profile [demo]              passed
Total: 3; Successful: 3; Failed: 0; Skipped: 0
```

Patrol's result reports are terminal/local runner output, not ingested by the
extension. Generated action completion is not an inferred business assertion.
The example widget test separately verifies navigation and absence of secret text.

## Failures found and resolved

### DTD binary readback

The first real UI export wrote a genuine PNG, then failed during readback with
`Failed to decode data using encoding 'utf-8'`. The public client accepts an
encoding argument, but this host's implementation calls `readAsString()` without
applying it. The earlier research harness verified PNG bytes with host `File`
access, so it had not established DTD binary readback.

The corrected exporter:

1. Lists the parent directory for existence checks, including binary files.
2. Uses the supported Latin-1 write transport to preserve encoded file bytes.
3. Reads text back as UTF-8 and checks exact equality.
4. Checks PNG write acknowledgment and file existence.
5. Clearly states in the UI that PNG binary readback is unavailable.

The successfully saved PNG was independently validated on the host. That check
does not become an unproven binary-readback claim in the shipped extension.
The exact owned files from the failed partial export were removed after the
successful replacement export; no user-authored file was overwritten.

DTD still has no exclusive-create/multi-file transaction. A concurrent writer
can race a check, and errors can leave partial files. Use a fresh, non-symlinked
output directory and do not edit the destination concurrently. Host/race hardening
and richer partial-export recovery remain later gates.

### Official browser installation

The official Playwright installer downloaded Chromium but stalled during
extraction under Node 26.12.0. Retrying the same official installer with Node
22.23.4 completed successfully. No dependency implementation or browser markers
were patched. Invoking Patrol inside `npx --call` then failed because npm options
propagated to Patrol's nested `npx`; putting Node 22 directly on PATH resolved it.

The selected CLI always runs its browser installation command, including when
an alternative browser channel is selected. Browser flags are not a demonstrated
offline-installation bypass. Network access for dependency installation remains
an environment prerequisite, not a recorder cloud service.

### Browser automation boundary

Flutter's accessibility activation required an explicit dispatched activation
event in the verification browser. A duplicate-export error was visible in a
browser screenshot even when a text-locator wait timed out. The actual refusal
was visually verified rather than treating the locator timeout as product success.

## Privacy, limitations, and publication gates

- No real credentials were used. Secret steps generate named references only.
  `--dart-define-from-file` is compile-time injection, not a vault; values can be
  present in built test binaries. Live input values are not transported.
- `safeProfiles` is app-authored public data. The app author must not put sensitive
  values there or display them outside a `RecorderSensitive` region.
- Capture is blocked while an explicitly sensitive subtree is mounted. Arbitrary
  sensitive pixels elsewhere cannot be detected automatically.
- M1 supports explicit taps and string input references only. No generalized long
  press, scrolling, navigation observation, automatic selector discovery, or native
  interaction capture is claimed.
- Full Pause/Resume/Discard, editing/reordering, groups/multiple cases per journey,
  typed data sets, saved-test browsing/reopening, and selector overrides await M2-M4.
- Mobile execution, full-device screenshots, remote/other IDE DTD hosts, and browser
  download persistence remain unverified.
- No Run button, arbitrary process launching, custom E2E engine, or result feed.
  Patrol starts a separate test app; recording connection survival is not assumed.
- `publish_to: none` remains set. Package naming, approved repository/support
  metadata, a real issue tracker instead of the explicit `example.invalid`
  placeholder, complete documentation, broader tests/platform matrix, archive
  inspection, and pub.dev dry run remain M5 gates. Nothing was published.

**Next approval requested:** M2's multi-journey model, groups/cases, typed data
validation, and selector inspection. No M2 implementation has been started.
