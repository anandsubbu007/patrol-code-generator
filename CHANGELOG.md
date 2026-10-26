## 0.0.7 (release candidate)

- Replace the recording-file and companion-generation workflow with live,
  copyable Patrol Dart statements in the DevTools panel.
- Keep test inputs as identifiers supplied by the user's test, not recorded
  input values.
- Prefer stable action-owner keys and expose unresolved targets for review.
- Support `recorder_config.addkey: true` as an opt-in to stable `ValueKey`
  suggestions; application source is never edited automatically.
- Remove the retired companion package, generated example tests, recording
  fixtures, and obsolete workflow documentation.
- Retain the demo app, manually maintained widget tests, and recorder/extension
  build, test, and single-package publication automation.

Earlier implementation notes described a retired workflow and have been removed
from the current documentation. Historical releases remain available in Git.
