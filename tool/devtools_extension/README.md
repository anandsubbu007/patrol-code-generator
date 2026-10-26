# DevTools extension

This Flutter web app displays live Patrol Dart statements from the debug
recorder. Record needs no journey name, intermediate file, or generation command.
The package ships compiled assets under `extension/devtools/build`.

```sh
flutter pub get
flutter analyze
flutter test
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
```

The panel polls the recorder snapshot once a second. Copy is blocked for
unresolved actions until corrected or explicitly excluded; incomplete recordings
require review. Disconnection retains the last preview but captures no further
actions. Clipboard contents contain input references, not recorded values.

DTD workspace access is required to read the app's optional
`recorder_config.addkey` boolean. Start the recording app with `--print-dtd` or
use IDE-managed DevTools. Exactly one authorized Flutter app depending on the
recorder must be identifiable. Errors are shown rather than guessing a project.
Key suggestions describe the action owner and tree path, but never edit source.
Add approved keys yourself, rebuild, and re-record.

Expectation picking distinguishes text and component targets. Visible screen
captures are masked in the runtime and previewed in memory, not saved to disk.
Source builds require Dart >=3.9 / Flutter >=3.35; consumers use compiled assets.
Protocol version 8 requires rebuilding the extension and recording app together.
