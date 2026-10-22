## 0.0.1

* Stable page-semantic/route/widget screenshot names with editable state names,
  collision validation, and owned-image replacement without session folders.
* YAML schema 2 omits session IDs and app bootstrap metadata; legacy schema 1
  remains readable. Runtime-only restart detection remains internal (protocol 4).
* Generator infers and awaits `lib/main.dart`'s no-argument main; optional custom
  bootstrap settings move to pubspec. RecorderController needs no config by default.
* Expanded example with finite animations, repeated controls, forms, dropdowns,
  dialogs, bottom sheets, settings, and explicit unsupported-scroll coverage.
* Named recordings now persist as machine-owned YAML under `patrol_recorder/`
  immediately on Record, autosave while active, and finalize on Stop.
* Dynamic input references use `{{name}}`; recorded values/defaults are never
  included. A separate local CLI generates Patrol code and abstract Dart inputs.
* Re-record the same journey name to replace its YAML; regenerate only owned
  `.g.dart` files while preserving user input providers and test wrappers.
* Screenshot and YAML directories are configurable in pubspec/DevTools.
* Maestro-style declarative flow architecture is reference only; no Maestro
  integration, JavaScript evaluation, or alternate test runner.
* Guided Generate code -> validate inputs -> save files workflow with exact saved
  paths and next-step instructions; optional defaults in pubspec.yaml.
* Separate generated abstract input/step files from never-overwritten user input
  implementations and test wrappers. Consent-based regeneration of recognized
  generated files only; no generated JSON input/config file.
* Visible-viewport capture before/during/after recording with private-region
  masking and multiple captures; screenshot is no longer required to generate code.
* Ignore background taps, recognize common toggles/list/menu controls, resolve
  nested taps, and allow explicit review/exclusion of genuinely unsupported steps.
* Protocol version 3.
* Automatic debug observation replaces per-button/per-field recording hooks.
* Key-first scoped selectors, explicit ambiguity, singleton assertions, and no
  coordinate or index fallback; protocol version 2.
* Standard focused fields use reference-only activity and automatic obscured-field
  privacy. Added optional subtree exclusion.
* Moved example recording setup and profiles to `patrol_test/`; application `lib/`
  no longer imports recording/test requirements.
* Unpublished Milestone 1: explicit debug recording hooks, DevTools proof,
  separate Patrol/data generation, restricted export, and runnable web example.
