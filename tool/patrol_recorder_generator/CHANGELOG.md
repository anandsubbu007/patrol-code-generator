## 0.0.1

* Separate development-only YAML-to-Patrol generation from the lightweight
  recorder runtime, including formatter, analyzer, YAML, and CLI dependencies.
* Read journey schemas 1, 2, and 3, validate stopped recordings, and generate
  bounded replay actions with typed input contracts.
* Preserve user-owned providers and test wrappers during regeneration.
* Validate selectors, bootstrap, screenshot paths, and safe local writes;
  invalid inputs fail explicitly with a nonzero CLI exit status.
