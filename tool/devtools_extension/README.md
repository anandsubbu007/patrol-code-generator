# DevTools extension source

This unpublished Flutter web app uses public `devtools_extensions` and DTD APIs.
The root package ships its compiled assets under `extension/devtools/build`.
The generator uses `dart_style` to produce formatted, syntactically validated Dart;
its analyzer dependency is confined to this tooling app, not the recorder runtime.

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

M1 polls the snapshot RPC once a second. Streaming recovery, full lifecycle
controls, selector editing, journey browsing and reopening are later milestones.
File export is create-only DTD with text readback and PNG write/existence
acknowledgment (binary readback is unavailable on this host), not arbitrary browser
filesystem access. See the [root README](../../README.md).

The automatic recorder uses protocol version 2. Rebuild/reload both the extension
and recording app after upgrading from the explicit-hook prototype. The generator
supports key-first scoped selectors, labels/text, and allowlisted public widget
types, rejects unresolved targets, and emits singleton assertions before actions.
Coordinates and index fallbacks are not supported. Select the app explicitly when
DTD lists multiple projects. Recording-only app setup belongs in the example's
`patrol_test/recorder_main.dart`, not application `lib/`.
