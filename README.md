# Patrol Recorder

Record Flutter interactions and copy live, readable Patrol Dart statements from
DevTools into tests you own. There is no intermediate recording file, separate
code-generation command, or generated test framework to maintain.

## Setup

Add the recorder to your app's development dependencies:

```sh
flutter pub add --dev patrol_recorder
```

Create a debug-only recording entrypoint, separate from your production entrypoint:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

import 'app.dart';

void main() {
  if (!kDebugMode) {
    throw StateError('Use the normal app entrypoint outside debug mode.');
  }
  final recorder = RecorderController();
  runApp(RecorderScope(controller: recorder, child: createApp()));
}
```

Use your own app construction function in place of `createApp()`. Start this
entrypoint with `flutter run --print-dtd --target path/to/recorder_main.dart`, open the
connected Flutter DevTools, and select **Patrol Recorder**.
Use IDE-managed DevTools or connect the printed DTD URI so the panel can read
the app's configuration in its authorized workspace.

## Record → review → copy

1. Start recording in the panel and interact with your app.
2. Review the live Dart statements and the resolved action targets.
3. Resolve ambiguous targets or exclude actions you do not want. For an
   expectation, choose whether you mean a component or its displayed text.
4. Copy the statements into a manually maintained `patrolTest` body.
5. Supply the referenced input variables, app setup, assertions, and cleanup.
   Run the test with your project's normal Patrol CLI configuration.

For example, a short login flow can look like:

```dart
await $.enterText(
  find.byKey(const ValueKey('email')),
  email,
  enablePatrolLog: false,
);
await $(const ValueKey('login')).tap();
expect($(const ValueKey('account')).exists, isTrue);
```

These are statements for an existing Patrol test, not a standalone Dart program.
Import Flutter and `flutter_test` as needed and provide your Patrol test's `$`.
An input such as `email` is an identifier you supply from your own test data;
the recorder does not embed the text you typed as a literal. Review identifiers
before copying and bind them to safe fixtures or your test's input parameters.
Text entry disables Patrol value logging so sensitive inputs are not echoed by
the copied action.

## Stable keys

Optionally enable key suggestions in your app's `pubspec.yaml`:

```yaml
recorder_config:
  addkey: true
```

This requests **suggestions**, not automatic source edits. Add the suggested
stable `ValueKey` yourself and restart recording after rebuilding the app.
Place the key on the widget that owns the action: for
`InkWell → Card → Container → Text`, a tap belongs to the `InkWell`, not the
decorative container or label. A text expectation can target the text instead.
Do not assume the nearest leaf, a widget's class name, or a position in a list
uniquely identifies the intended control.

Existing stable keys are preferred. Review text fallbacks and repeated controls;
unresolved targets must be corrected or explicitly excluded before copying
runnable code. Suggested keys are not present in the app until you add them.

## Scope and limitations

- The recording entrypoint is for local debug sessions, not production builds.
- Output is ordinary Patrol code, and remains your responsibility to review and
  maintain. Set up Patrol's native project integration separately.
- Input values are not persisted in the copied statements. Keep secrets out of
  test fixtures and review any explicitly authored assertion text before sharing.
- Native dialogs, platform permissions, application state, and test data may need
  additional manually authored Patrol steps.
- Custom painting, opaque platform views, and arbitrary gesture recognizers are
  not universally observable. The recorder uses the hit-test/element tree and
  standard gesture recognizer boundaries; ambiguous targets require review.
- Scrolling requires an identified viewport and destination. If the viewport
  cannot be identified, add a stable key and re-record rather than choosing the
  first scrollable. Complex expectations may need more than one Dart statement.

## Development

- [Runnable example](example/README.md)
- [Demo walkthrough](doc/DEMO.md)
- [Contributing and validation](CONTRIBUTING.md)
- [Publishing the recorder](doc/PUBLISHING.md)
- [Changelog](CHANGELOG.md)

The repository contains the recorder package, its DevTools extension under
`tool/devtools_extension`, and a local demo app under `example`.
