# Patrol Recorder generator

Unpublished development-only companion to the Flutter recorder. It reads
machine-generated YAML journeys and emits ordinary Patrol Dart tests. It does not
record interactions or execute tests, and has no Maestro dependency.

From an app that lists this package as a development dependency:

```sh
dart run patrol_recorder_generator:generate
dart run patrol_recorder_generator:generate --journey login
dart run patrol_recorder_generator:generate --project /path/to/app
dart run patrol_recorder_generator:generate --help
```

Optional app `pubspec.yaml` defaults:

```yaml
recorder_config:
  recordings_directory: patrol_recorder
  screenshots_directory: patrol_recorder/screenshots
  output_directory: patrol_test/recorded_journeys
  wait_timeout_ms: 15000
  max_scrolls: 60
```

`--recordings-directory` overrides YAML discovery for a single invocation.
Only direct `*.yml` children of that directory are source journeys. A file name
must match its journey ID. The CLI validates the complete selected batch before
writing: schema, resolvable app entrypoint, stopped state, input references, supported/scoped
selectors, excluded steps, safe paths, and referenced screenshot existence.

New schema-3 YAML contains no app import/builder or session ID. Schema-1 and
schema-2 YAML remain readable. The default
bootstrap is inferred from the project name and `lib/main.dart -> main()`, which
is invoked through `Future<void>.sync` so async initialization is awaited.
The parser validates that the selected function exists and needs no arguments.
Custom test factories use optional `recorder_config.app_import` and `app_builder`
in pubspec. Schema-1 files retain their legacy bootstrap until re-recorded.

Each input action uses a whole-string reference such as `"{{user_name}}"`.
Arbitrary templates, expressions, JavaScript, raw credentials, and coordinate
selectors are not supported. The recorder, not hand editing, owns the YAML.

For each journey the generator creates:

| Output | Ownership |
| --- | --- |
| `*_steps.g.dart` | Generated actions and current name/tag; regenerated |
| `*_inputs.g.dart` | Generated abstract `JourneyInputs` and validation; regenerated |
| `*_inputs.dart` | One-time implementation scaffold; always preserved |
| `*_test.dart` | One-time Patrol entrypoint; always preserved |

Implement the abstract getters in the input file and return the instance from
`loadInputs()`. Getters intentionally throw until you wire them. Credentials come
from your private provider, not YAML. Pass your instance directly to
`runRecordedJourney($, inputs)` if you prefer your own test entrypoint.

Re-recording a journey replaces its YAML. Running this CLI again replaces only
recognized generated files, never manually maintained implementations/assertions.
New input getters make missing implementation an analyzer error. Source changes
do not delete obsolete PNGs or generated journeys automatically. New screenshots
have stable journey/name paths and are replaced by the recorder only when their
ownership marker matches. This package does not compare screenshots.

Generated actions use bounded target visibility/enabled waits rather than
globally settling after each action. `wait_timeout_ms` defaults to 15000 and
accepts 100-120000; it bounds app startup, input-provider, and target readiness
waits. `max_scrolls` defaults to 60 and accepts 1-200; it bounds continuous,
target-based Patrol scrolling through lazily built content. This reproduces
reaching an identified visible target, not an exact pixel offset.

Inline hyperlink actions use public Flutter text-range targeting. Link text must
be unique in a keyed paragraph; duplicate text needs a separately keyed paragraph
or a keyed `TextButton`/`WidgetSpan`. Arbitrary futures, business-state completion,
custom painting, opaque platform views, pinch/slider-specific gestures, and
unsupported custom widgets are not inferred universally. Add explicit bounded
waits and assertions for final business outcomes in the preserved test wrapper.

Local writes reject symlinked paths and use sibling temporary-file replacement.
Generation is not a multi-file transaction: stop concurrent recording/generation
and editing before regenerating. Errors have nonzero exit status and no
success-shaped output for invalid/in-progress sources.

## Development

```sh
flutter pub get
dart format lib bin test
flutter analyze
flutter test
```

The libraries are pure Dart and run using `dart run`; `flutter pub get/test` is used
in this repository because the shared recorder-model package also has a Flutter
runtime. Formatter/YAML dependencies stay out of the app-side recorder package.
