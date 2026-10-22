import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';

void main() {
  if (!kDebugMode) {
    throw StateError(
      'The recording entrypoint is debug-only. Use lib/main.dart.',
    );
  }
  final recorder = RecorderController();
  runApp(RecorderScope(controller: recorder, child: createApp()));
}
