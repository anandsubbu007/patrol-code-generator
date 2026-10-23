# Record a Flutter journey and replay it with Patrol

This runnable example uses fictional data and local fixtures only. The recorder
stores stable selectors and input references, never values typed into fields.

## Start recording

Keep recording setup in a test-only entrypoint, separate from application code:

```dart
import 'package:flutter/material.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';

final recorder = RecorderController();

void main() {
  runApp(RecorderScope(controller: recorder, child: createApp()));
}
```

The maintained entrypoint is [patrol_test/recorder_main.dart](patrol_test/recorder_main.dart).
After setting up the repository, run from the example directory:

```sh
flutter pub get
flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd
```

Open DevTools, enable **patrol_recorder**, and start a new named recording.
Interact with the app, then choose **Add expectation**, tap a public text widget,
and select **Exact text**. Its suggested comparison text is editable and is saved
only when confirmed. Stop recording before generating Dart.

## Try the maintained M2 example

After **Open demo account**, choose **Fixture and expectation lab**. The
[schema-5 journey](patrol_recorder/m2_fixtures.yml) contains two cases with real
JSON/text fixture assets, typed profiles, reusable setup/groups, selector
overrides, and explicit text/count expectations. Its
[user-owned adapter](patrol_test/m2_fixture_adapter.dart) applies fixtures to
the actual local app store; no backend is contacted.

```sh
dart run patrol_recorder_generator:generate --journey m2_fixtures --preview
dart run patrol_recorder_generator:generate --journey m2_fixtures --inspect-selectors
dart run patrol_recorder_generator:generate --journey m2_fixtures
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/populated/populated_test.dart --device chrome --web-headless
patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/empty/empty_test.dart --device chrome --web-headless
```

Both checked-in providers are implemented and both cases passed Patrol web
replay. Let each case use its default profile. Regeneration preserves the
user-owned providers and test wrappers; generated `.g.dart` files are replaceable.
Do not re-record over this maintained, manually authored journey.

Assets must stay under the configured recordings root's `assets/` directory.
They are test fixtures, not uploads or arbitrary runtime file reads. Never put
secrets in YAML, fixtures, screenshots, or generated providers.

See the [full example guide](README.md) for setup, recording, all example flows,
and limitations. The normal app entrypoint deliberately contains no recorder
setup. Web replay is verified; native/mobile end-to-end execution is not.
