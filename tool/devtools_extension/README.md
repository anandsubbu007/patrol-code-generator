# DevTools extension source

This unpublished Flutter web app uses public `devtools_extensions` and DTD APIs.
The root package ships its compiled assets under `extension/devtools/build`.
YAML schema/configuration is shared with the development-only
[generator library](../patrol_recorder_generator/lib/generator.dart), not
duplicated in the UI. The runtime recorder has no generator dependencies.
The extension source app depends on the generator to build its compiled assets;
users of the recorder receive those assets without this source dependency.

```sh
flutter pub get
flutter analyze
flutter test
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
```

The custom Flutter bootstrap loads packaged CanvasKit assets locally. No simulated
DevTools environment is required by the actual proof.

`tool/generate_example.dart` is a create-only fixture generator for the two sample
targets, not a test execution engine. It refuses to overwrite existing generated
files. Do not run it over manually edited examples.

The panel polls the snapshot RPC once a second and serializes autosaves. Record
requires a name/authorized app root and writes an initial `.yml` immediately.
Snapshots, screenshot captures, stop, and review changes update that same file.
Text readback is verified. PNG writes/existence are acknowledged; binary readback
is unavailable on this DTD host.

Re-recording the same name replaces only validated recorder-owned YAML for that
app. Foreign files and concurrent changes are refused. Interrupted sessions stay
marked recording; the CLI will not generate from unfinished sources. Failures
retain the draft and expose Retry YAML save.

The automatic recorder uses protocol version 5 and writes schema-3 YAML. Schemas
1 and 2 remain readable by the generator. Rebuild/reload both the extension
and recording app after upgrading from the explicit-hook prototype. The generator
supports key-first scoped selectors, labels/text, and allowlisted public widget
types, requires review/exclusion of unresolved actions, and emits singleton assertions.
Inline hyperlink text-range taps, long presses, and target-based scrolling use
public Flutter APIs. Scroll-position listeners complement bubbling notifications,
so a consuming ancestor does not prevent standard pointer scrolling from being
observed. Generated Patrol scrolling seeks an identified target with bounded
continuous movement; it does not reproduce exact offsets. Coordinates and index
fallbacks are not supported. Select the app explicitly when DTD lists multiple
projects. Recording-only app setup belongs in the example's
`patrol_test/recorder_main.dart`, not application `lib/`.

Capture suggests a stable name from active page semantics, route, or widget type.
The naming dialog supports explicit state names and prevents duplicate names in
one journey. PNGs use `<screenshots_directory>/<journey>/<name>.png`; small
adjacent ownership markers allow safe generated-image replacement. Runtime
session tokens are transient only; schema-3 YAML exports neither session IDs nor
an app bootstrap block. The CLI infers normal main or uses a pubspec override.

The UI does not generate Dart or collect data values. It displays the saved YAML
path and copies a `dart run patrol_recorder_generator:generate` command. Defaults
are optional `pubspec.yaml > recorder_config`, including YAML/screenshot directories.
The CLI derives the abstract input contract from `{{name}}` references and preserves
the user's implementation. No custom E2E execution engine is included.

The generator also accepts `wait_timeout_ms` (100-120000; default 15000) and
`max_scrolls` (1-200; default 60) in `recorder_config`. These bound readiness and
target scrolling, not arbitrary application futures. The example's local delayed
operations are fixtures only; they do not contact a network. Custom painting,
opaque platform views, pinch/slider-specific gestures, and arbitrary custom
widgets are not universally observable. Keys improve identity but cannot make an
unsupported gesture observable, and the recorder never edits application source.

`RecorderBackend` separates the DevTools web-only host from the panel, allowing
widget tests of the real Record dialog, immediate file creation, autosave, same-name
replacement, configured screenshot location, and failure/retry behavior.
