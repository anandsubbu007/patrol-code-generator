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
The project remains unpublished. Broader editor and execution workflows are not
complete and require approval before work begins.

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

- [ ] Design and implement explicit `expect` steps in the YAML schema and
  generated Patrol Dart. Define supported expectation forms, validation,
  bounded waiting, and behavior for incomplete or unsupported expectations.
- [ ] Define what an `asset` step represents, how assets are referenced and
  stored, and how the generator validates and handles them. Keep paths bounded
  to the configured journey/project roots; do not allow arbitrary file access.
- [ ] Support manually authored `expect` and `asset` steps in YAML and ensure
  parsing, validation, preview/generation, and error messages handle them
  consistently.
- [ ] Add schema and generator tests for valid, invalid, missing, and unsupported
  expectation/asset inputs.
- [ ] Expand the journey model for stable IDs, multiple cases, groups, typed
  input data, reusable profiles/setup, and selector inspection/overrides.

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

- Clarify the user-visible contract and syntax for `expect` and `asset` before
  implementing those YAML commands; the items above intentionally do not assume
  an asset type or assertion language.
- Patrol remains the execution foundation. Generated actions must use stable,
  validated targets; unresolved or ambiguous actions must not become
  success-shaped test code.
- Input values and secrets must not be recorded in YAML. Secret references are
  not a secrets vault; compile-time injected values may be present in test
  artifacts.
- Mobile execution, full-device screenshots, browser download persistence,
  remote/other-IDE DTD hosts, and general native interactions remain unverified.
- No package has been published. Do not add a Run button, arbitrary process
  launching, or a custom execution engine as an implicit part of this roadmap.
