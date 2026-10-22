## 0.0.1

* Automatic debug observation replaces per-button/per-field recording hooks.
* Key-first scoped selectors, explicit ambiguity, singleton assertions, and no
  coordinate or index fallback; protocol version 2.
* Standard focused fields use reference-only activity and automatic obscured-field
  privacy. Added optional subtree exclusion.
* Moved example recording setup and profiles to `patrol_test/`; application `lib/`
  no longer imports recording/test requirements.
* Unpublished Milestone 1: explicit debug recording hooks, DevTools proof,
  separate Patrol/data generation, restricted export, and runnable web example.
