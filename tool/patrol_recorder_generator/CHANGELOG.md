## Unreleased

- Replay scrolls with `_recorderScrollTo`: reveal built targets with
  `ensureVisible`, otherwise drag in steps of 30% of the viewport toward the
  recorded direction, wait for paged content at the extent, then sweep back.
  Scroll steps without `scroll_view` auto-detect the current-route Scrollable on
  the recorded axis.

## 0.0.6

- Support Dart >=3.8.0 <4.0.0 and Flutter >=3.32.0 through recorder 0.0.6.
- Allow dart_style ^3.1.2 and analyzer >=8.0.0 <15.0.0 rather than requiring
  the latest Dart 3.13-only tooling; retain compatible patch upgrades.
- Keep generated enabled-state checks compatible with Flutter 3.32 semantics,
  with execution coverage for enabled, disabled, and unspecified states.
- Update installation and compatibility guidance for the coordinated release.

## 0.0.5

- Add coordinated tag/branch release automation and hosted publication checks.
- Keep generated-code execution tests runnable from release staging with an
  explicit checkout example-project path.

## 0.0.4

- Prepare the generator for the coordinated 0.0.4 release and document the
  hosted validation sequence.

## 0.0.1

* Separate development-only YAML-to-Patrol generation from the lightweight
  recorder runtime, including formatter, analyzer, YAML, and CLI dependencies.
* Read journey schemas 1, 2, and 3, validate stopped recordings, and generate
  bounded replay actions with typed input contracts.
* Preserve user-owned providers and test wrappers during regeneration.
* Validate selectors, bootstrap, screenshot paths, and safe local writes;
  invalid inputs fail explicitly with a nonzero CLI exit status.
