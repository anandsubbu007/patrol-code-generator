## 0.0.5

- Add coordinated version-tag releases, optional release-branch preparation,
  pub.dev OIDC setup guidance, and release-helper regression checks.
- Wait for pub.dev's dependency-resolution index before proceeding to the
  generator after recorder publication.
- Avoid duplicate push CI for release tags and version branches; cancel
  superseded ordinary CI runs.

## 0.0.4

- Correct publication and installation status, clarify hosted workflow blockers,
  avoid implying Web-only compatibility in package metadata while clearly
  documenting the Web-only end-to-end verification, and add contributor setup
  and automated repository checks.

## 0.0.3

- Add a one-shot DevTools widget picker for bounded exists/absent/visible/text/count
  expectations. Exact-text fields suggest selected public text without reading
  editable or private content; text/count drafts remain separate.
- Companion generator schema 5 adds bounded text/JSON fixture assets, typed
  profiles and case data, reusable setup/groups, stable expanded step IDs,
  selector overrides, and read-only preview/inspection. Schemas 1-4 remain readable.
- Add a runnable fixture lab and maintained two-case `m2_fixtures` journey with
  real user-owned asset adapters, generated Patrol outputs, and successful web replays.
- Refresh pub.dev gallery images and the app walkthrough to show the fixture lab;
  document the distinction between recorded app actions and manually authored fixtures.

## 0.0.2

- Declare Android, iOS, Linux, macOS, web, and Windows compatibility. The
  complete recording/replay workflow remains verified on Flutter web only.

## 0.0.1

- Keep the recorder lightweight: generation lives in the separate
  `patrol_recorder_generator` development dependency, with no generator/analyzer
  dependency in the runtime recorder package.
- Publication preparation: installation and release guides, screenshots,
  BSD-3-Clause licensing, package metadata, and bundled DevTools assets.
- Runtime protocol 5 and YAML schema 3 add hyperlink text-range actions,
  long-press recording, target-anchored scrolling, and bounded replay readiness;
  schema 1 and 2 journeys remain readable.
- Public `ScrollPosition` listeners preserve standard scroll observation when
  notifications are consumed, and are detached on stop/disposal or position
  replacement.
- Generated replay uses continuous target-based Patrol scrolling, configurable
  `wait_timeout_ms` and `max_scrolls`, and no per-action global settling.
- The async example now asserts its delayed selection, long-press outcome, and
  animation switch state with bounded waits. Documentation describes supported
  interactions and limits.
- Stable page-semantic/route/widget screenshot names with editable state names,
  collision validation, and owned-image replacement without session folders.
- YAML schema 2 omits session IDs and app bootstrap metadata; legacy schema 1
  remains readable. Runtime-only restart detection remains internal (protocol 4).
- Generator infers and awaits `lib/main.dart`'s no-argument main; optional custom
  bootstrap settings move to pubspec. RecorderController needs no config by default.
- Expanded example with finite animations, repeated controls, forms, dropdowns,
  dialogs, bottom sheets, settings, and explicit unsupported-scroll coverage.
- Named recordings now persist as machine-owned YAML under `patrol_recorder/`
  immediately on Record, autosave while active, and finalize on Stop.
- Dynamic input references use `{{name}}`; recorded values/defaults are never
  included. The companion CLI generates Patrol code and abstract Dart inputs.
- Re-record the same journey name to replace its YAML; regenerate only owned
  `.g.dart` files while preserving user input providers and test wrappers.
- Screenshot and YAML directories are configurable in pubspec/DevTools.
- Maestro-style declarative flow architecture is reference only; no Maestro
  integration, JavaScript evaluation, or alternate test runner.
- Guided Generate code -> validate inputs -> save files workflow with exact saved
  paths and next-step instructions; optional defaults in pubspec.yaml.
- Separate generated abstract input/step files from never-overwritten user input
  implementations and test wrappers. Consent-based regeneration of recognized
  generated files only; no generated JSON input/config file.
- Visible-viewport capture before/during/after recording with private-region
  masking and multiple captures; screenshot is no longer required to generate code.
- Ignore background taps, recognize common toggles/list/menu controls, resolve
  nested taps, and allow explicit review/exclusion of genuinely unsupported steps.
- Protocol version 3.
- Automatic debug observation replaces per-button/per-field recording hooks.
- Key-first scoped selectors, explicit ambiguity, singleton assertions, and no
  coordinate or index fallback; protocol version 2.
- Standard focused fields use reference-only activity and automatic obscured-field
  privacy. Added optional subtree exclusion.
- Moved example recording setup and profiles to `patrol_test/`; application `lib/`
  no longer imports recording/test requirements.
- Unpublished Milestone 1: explicit debug recording hooks, DevTools proof,
  separate Patrol/data generation, restricted export, and runnable web example.
