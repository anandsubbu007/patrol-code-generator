import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';

/// Debug-only entrypoint for recording through DevTools, not test replay.
///
/// Run from the example app: `flutter run --target patrol_test/recorder_main.dart`.
/// After stopping and saving YAML, generate tests from the same app directory:
/// `dart run patrol_recorder_generator:generate`.
/// Complete generated input TODOs, then run tests through `patrol test --target`.
/// Patrol CLI owns test_bundle.dart; do not edit or commit that generated file.
void main() {
  if (!kDebugMode) {
    throw StateError(
      'The recording entrypoint is debug-only. Use lib/main.dart.',
    );
  }
  final recorder = RecorderController();
  runApp(RecorderScope(controller: recorder, child: createApp()));
}
