import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';
import 'package:patrol_recorder_example/fixture_lab.dart';

import '../patrol_test/demo_profiles.dart';

void main() {
  testWidgets(
    'fixture lab applies typed local data and supports expected match counts',
    (tester) async {
      demoFixtures.clear();
      addTearDown(demoFixtures.clear);
      await tester.pumpWidget(createApp());
      await tester.tap(find.byKey(const ValueKey('login')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('open_fixtures')));
      await tester.tap(find.byKey(const ValueKey('open_fixtures')));
      await tester.pumpAndSettle();
      expect(find.text('No fixture loaded'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('seed_fixture')));
      await tester.pumpAndSettle();
      expect(find.text('Ada Fixture'), findsOneWidget);
      expect(find.text('Credit: 24.50'), findsOneWidget);
      expect(find.text('Fixture item'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('clear_fixture')));
      await tester.pumpAndSettle();
      expect(find.text('Fixture item'), findsNothing);
      expect(
        () => demoFixtures.seed(
          {'name': 'Invalid', 'email': 'real@example.com'},
          quantity: 1,
          enabled: true,
          credit: 0,
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets('one root wrapper automatically records the hook-free login', (
    tester,
  ) async {
    final recorder = RecorderController();
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
