import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

Future<RecorderScreenshot> captureScreen(
  WidgetTester tester,
  RecorderController recorder,
) async {
  final pending = tester.runAsync(recorder.capture);
  await tester.pump();
  return (await pending)!;
}

Future<void> recording(
  WidgetTester tester,
  Widget child,
  Future<void> Function(RecorderController recorder) body, {
  int maxSteps = 500,
}) async {
  final recorder = RecorderController(maxSteps: maxSteps);
  try {
    await tester.pumpWidget(
      RecorderScope(
        controller: recorder,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await body(recorder);
  } finally {
    if (recorder.state == RecordingState.recording) recorder.stop();
    await tester.pumpWidget(const SizedBox());
    recorder.dispose();
  }
}
