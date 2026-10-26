# Live Patrol recording demo

The example contains a login/account flow, repeated controls, scrolling,
asynchronous loading, and fixture widgets. The fixture widgets are ordinary demo
UI; test data setup remains the responsibility of your manually maintained tests.

## Run

From `example/`:

```sh
flutter pub get
flutter run --print-dtd --target patrol_test/recorder_main.dart
```

Open the connected Flutter DevTools and select **Patrol Recorder**.

1. Start recording.
2. Enter a fictional email and note, then open the demo account.
3. Inspect the live Patrol Dart output. Text-entry arguments should be identifiers
   for test inputs, not the literal values you entered.
4. Try repeated controls and asynchronous/scrolling pages. Review target
   resolution; do not accept a different control just because its text matches.
5. Add component or text expectations deliberately.
6. Resolve or exclude unsupported/ambiguous steps, then use **Copy**.
7. Paste into your own Patrol test body, define its input variables, and add
   startup, assertions, and cleanup appropriate to the test.

The example opts into `recorder_config.addkey: true`. If a stable key is missing,
review the suggestion and add a `ValueKey` to the action owner manually. A tap on
text inside an `InkWell` belongs to the `InkWell`. Rebuild/restart and record again
so copied code targets a key that really exists.

## Validate the app independently

```sh
flutter analyze
flutter test
flutter run --target lib/main.dart
```

The normal entrypoint does not install the recorder. The widget test suite is
maintained directly; copying from DevTools does not overwrite it.
