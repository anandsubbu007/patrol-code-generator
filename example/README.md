# Patrol Recorder example

This local-only Flutter app demonstrates login, repeated controls, asynchronous
content, scrolling, and fixture widgets.

## Record live Patrol statements

```sh
flutter pub get
flutter run --print-dtd --target patrol_test/recorder_main.dart
```

Open Flutter DevTools → **Patrol Recorder**, start recording, and interact with
the app. Review the live Dart statements and use **Copy** to paste them into a
Patrol test that you maintain.

Text input arguments are identifiers: define them in your test from fictional
fixtures or explicit test parameters. Do not expect captured values or generated
test scaffolding. Add the app setup, expectations, cleanup, and native Patrol
configuration your test requires.

The example's `recorder_config.addkey: true` enables stable-key suggestions only.
Manually place a suggested `ValueKey` on the widget owning the action, rebuild,
and record again. For example, key the `InkWell` handling a tap rather than its
nested `Text`. Resolve ambiguous targets or exclude those steps before copying.

## Run without recording

```sh
flutter run --target lib/main.dart
```

## Validate

```sh
flutter analyze
flutter test
```

The app tests and `patrol_test/demo_profiles.dart` are manually maintained.
`patrol_test/recorder_main.dart` is a debug app entrypoint, not a replay test.
Keep actual Patrol tests separate and run them using your configured Patrol CLI.
Do not commit Patrol CLI's generated `test_bundle.dart`.
