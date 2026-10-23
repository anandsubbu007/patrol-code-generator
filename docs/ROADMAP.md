# Patrol Recorder Roadmap

This is the active planning document: current delivery status, milestones, and
open todos. Detailed research and implementation evidence is in the
[implementation history](IMPLEMENTATION_HISTORY.md); the initial real-host proof
is documented in the [integrated proof report](INTEGRATED_PROOF_RESULTS.md).

## Current status

The repository now contains an integrated Flutter recorder, a real DevTools
extension, a YAML recording source, a development-only Patrol generator, stable
Flutter-content screenshots, automatic bounded observation, and a working example.
The implementation and verification details are recorded in the linked documents.
Recorder 0.0.2 is published; recorder 0.0.3 is being prepared with the M2 changes.
Broader editor and execution workflows are not complete and require approval
before work begins.

## Completed milestones

- [x] **Initial integrated technical proof:** real DevTools connection, permission-
      bound DTD export, generated Patrol tests, screenshot capture, and real Patrol
      web execution. See the [proof report](INTEGRATED_PROOF_RESULTS.md).
- [x] **Automatic-observation follow-up:** bounded tap/text/scroll/long-press
      observation, selector resolution, protocol/schema evolution, and validation.
      See [implementation results](IMPLEMENTATION_HISTORY.md#automatic-implementation-results)
      and [protocol-5 follow-up](IMPLEMENTATION_HISTORY.md#protocol-5-interaction-and-async-follow-up).
- [x] **YAML and stable-capture follow-ups:** autosaved YAML sources, a separate
      generator, user-owned input providers and test wrappers, and stable screenshot
      paths. See [YAML workflow](IMPLEMENTATION_HISTORY.md#yaml-source-and-generation-workflow)
      and [stable captures](IMPLEMENTATION_HISTORY.md#stable-captures-and-complex-ui).

## Planned milestones

These are proposed scopes, not authorization to implement. Confirm the milestone
scope before starting implementation.

### M2 — YAML flow expressiveness, cases, and data

- [x] Design and implement explicit `expect` steps in the YAML schema and
      generated Patrol Dart. Define supported expectation forms, validation,
      bounded waiting, and behavior for incomplete or unsupported expectations.
- [x] Add a DevTools one-shot widget picker: consume the selection tap, inspect
      the resolved selector, configure an expectation, and persist only on confirmation.
- [x] Prefill exact-text expectations from a single public selected text leaf;
      retain editable text/count drafts without reading private or editable values.
- [x] Define what an `asset` step represents, how assets are referenced and
      stored, and how the generator validates and handles them. Keep paths bounded
      to the configured journey/project roots; do not allow arbitrary file access.
- [x] Support manually authored `expect` and `asset` steps in YAML and ensure
      parsing, validation, preview/generation, and error messages handle them
      consistently.
- [x] Add schema and generator tests for valid, invalid, missing, and unsupported
      expectation/asset inputs.
- [x] Expand the journey model for stable IDs, multiple cases, groups, typed
      input data, reusable profiles/setup, and selector inspection/overrides.

Delivered as schema 5 with legacy schema 1-4 readers. Fixture assets are bounded
UTF-8 text/JSON under `<recordings_directory>/assets/`, embedded during generation,
and applied through an explicit user-owned adapter. Multi-case outputs preserve
user-owned providers/wrappers. CLI `--preview`, `--case`, and `--inspect-selectors`
share the generation validation path. See the
[authored journey guide](../tool/patrol_recorder_generator/README.md#authored-journeys).
Advanced cases/fixtures remain YAML-authored, not a new DevTools case editor.

### M3 — Timeline and editing controls

- [ ] Complete the live timeline and reliable Start/Pause/Resume/Stop/Discard
      lifecycle.
- [ ] Add safe step editing, deletion, reordering, grouping, and manual
      re-recording.

### M4 — Saved journeys and workflows

- [ ] Add saved-journey browsing/reopening and selected file/case/suite commands.
- [ ] Improve overwrite handling, screenshot providers, and supported export
      portability.
- [ ] Keep direct process invocation and runner-result ingestion proof-gated;
      do not assume browser capabilities that are not verified.

### M5 — Example and package readiness

- [ ] Complete representative examples and tests for every advertised interaction.
- [ ] Verify the supported platform/version matrix and package contents.
- [ ] Complete documentation, licensing/provenance review, archive inspection,
      and a pub.dev dry run. Publishing requires separate explicit approval.

## Open decisions and constraints

- Schemas 4 and 5 define `expect` as bounded `exists`, `absent`, `visible`, exact `text`,
  or `count` checks. The DevTools picker authors these steps without activating
  the selected control. See the [expectation guide](../README.md#add-an-expectation).
- Schema 5 defines assets as test fixtures, not screenshots, uploads, arbitrary
  file reads, or executable scripts. Default fixture adapters fail until connected.
  Referenced setup executes after app bootstrap; pre-bootstrap injection stays in
  the preserved user-owned wrapper. Timed-out adapter futures cannot be canceled
  automatically, so adapters own cleanup.
- Patrol remains the execution foundation. Generated actions must use stable,
  validated targets; unresolved or ambiguous actions must not become
  success-shaped test code.
- App-entered values and secrets must not be recorded in YAML. Explicitly authored
  non-secret typed fixture values are allowed in schema 5. Secret references are
  not a secrets vault; compile-time injected values may be present in test
  artifacts.
- Mobile execution, full-device screenshots, browser download persistence,
  remote/other-IDE DTD hosts, and general native interactions remain unverified.
- Recorder 0.0.2 is published; 0.0.3 and companion tooling uploads still require
  explicit owner approval. Do not add a Run button, arbitrary process
  launching, or a custom execution engine as an implicit part of this roadmap.
