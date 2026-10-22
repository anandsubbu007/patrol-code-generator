import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';

import '../patrol_test/demo_profiles.dart';

void main() {
  testWidgets('one root wrapper automatically records the hook-free login', (
    tester,
  ) async {
    final recorder = RecorderController(
      config: RecorderAppConfig(
        appImport: 'package:patrol_recorder_example/app.dart',
        appBuilder: 'createApp',
        safeProfiles: demoProfiles,
      ),
    );
    try {
      await tester.pumpWidget(
        RecorderScope(controller: recorder, child: createApp()),
      );
      recorder.start();
      await tester.pump();
      for (final field in ['email', 'note']) {
        await tester.tap(find.byKey(ValueKey(field)));
        await tester.pump();
        tester.testTextInput.enterText('PRIVATE_SENTINEL_$field');
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('login')));
      await tester.pumpAndSettle();
      recorder.stop();
      expect(recorder.error, isNull);
      expect(recorder.steps.map((s) => s.action), [
        RecordedAction.enterText,
        RecordedAction.enterText,
        RecordedAction.tap,
      ]);
      expect(recorder.steps.map((s) => s.target.key), [
        'email',
        'note',
        'login',
      ]);
      expect(
        jsonEncode(recorder.snapshot()),
        isNot(contains('PRIVATE_SENTINEL')),
      );
      expect(find.text('Demo account is open'), findsOneWidget);
    } finally {
      if (recorder.state == RecordingState.recording) recorder.stop();
      await tester.pumpWidget(const SizedBox());
      recorder.dispose();
    }
  });

  testWidgets('login form navigates without exposing input values', (
    tester,
  ) async {
    await tester.pumpWidget(createApp());
    await tester.enterText(
      find.byKey(const Key('password')),
      'SUPER_SECRET_SENTINEL',
    );
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle();
    expect(find.text('Demo account is open'), findsOneWidget);
    expect(find.text('SUPER_SECRET_SENTINEL'), findsNothing);
    await tester.tap(find.byKey(const Key('settings')));
    await tester.pumpAndSettle();
    expect(find.text('Account settings'), findsWidgets);
  });

  test('named demonstration profiles contain no credential fields', () {
    expect(demoProfiles.keys, ['demo', 'secondary']);
    for (final profile in demoProfiles.values) {
      expect(profile.keys, isNot(contains('password')));
      expect(profile['email'], endsWith('.invalid'));
    }
  });
}
