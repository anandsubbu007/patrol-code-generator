import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';

/// Debug-only entrypoint for recording through DevTools, not test replay.
///
/// Run from the example app: `flutter run --target patrol_test/recorder_main.dart`.
/// Copy live Dart statements from the Patrol Recorder DevTools panel into a
/// manually maintained Patrol test and supply its input variables.
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
