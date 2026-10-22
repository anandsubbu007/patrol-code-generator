import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';

Future<void> exercise(
  WidgetTester tester,
  Future<void> Function(RecorderController controller) action,
) async {
  final recorder = RecorderController();
  try {
    await tester.pumpWidget(
      RecorderScope(controller: recorder, child: createApp()),
    );
    recorder.start();
    await tester.pump();
    await tap(tester, 'login');
    await action(recorder);
  } finally {
    if (recorder.state == RecordingState.recording) recorder.stop();
    await tester.pumpWidget(const SizedBox());
    recorder.dispose();
  }
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<String> captureName(
  WidgetTester tester,
  RecorderController recorder,
) async {
  final pending = tester.runAsync(recorder.capture);
  await tester.pump();
  return (await pending)!.suggestedName;
}

void main() {
  testWidgets(
    'finite animations and repeated controls remain automatically recordable',
    (tester) async {
      await exercise(tester, (recorder) async {
        await tap(tester, 'open_animations');
        expect(await captureName(tester, recorder), 'animation_lab');
        await tap(tester, 'animate_card');
        await tap(tester, 'expand_card');
        expect(find.textContaining('Expanded summary'), findsOneWidget);
        await tap(tester, 'simulate_loading');
        expect(find.text('Loaded'), findsOneWidget);
        await tap(tester, 'animation_lab_back');
        await tap(tester, 'open_repeated');
        final business = find.byKey(const ValueKey('business_card'));
        await tester.tap(
          find.descendant(of: business, matching: find.text('Continue')),
        );
        await tester.pumpAndSettle();
        expect(find.text('business selected'), findsOneWidget);
        final target = recorder.steps.last.target;
        expect(target.key ?? target.scope?.value, 'business_card');
        await tester.tap(
          find.descendant(of: business, matching: find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        expect(find.text('business count: 1'), findsOneWidget);
        expect(await captureName(tester, recorder), 'repeated_controls');
        expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        expect(
          recorder.steps.every((s) => s.action == RecordedAction.tap),
          isTrue,
        );
      });
    },
  );

  testWidgets(
    'forms, dropdowns, bottom sheets and dialogs have stable capture identities',
    (tester) async {
      await exercise(tester, (recorder) async {
        await tap(tester, 'open_forms');
        await tap(tester, 'preview_profile');
        expect(find.text('Enter a display name'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('display_name')),
          'Fictional Person',
        );
        await tester.pumpAndSettle();
        await tap(tester, 'profile_role');
        await tester.tap(find.text('Editor').last);
        await tester.pumpAndSettle();
        await tap(tester, 'preview_profile');
        expect(find.text('Role: Editor'), findsOneWidget);
        expect(await captureName(tester, recorder), 'profile_preview_sheet');
        await tap(tester, 'close_preview');
        await tap(tester, 'open_info_dialog');
        expect(await captureName(tester, recorder), 'information_dialog');
        await tap(tester, 'dismiss_info');
        expect(await captureName(tester, recorder), 'forms_lab');
        expect(
          recorder.steps.where((s) => s.action == RecordedAction.enterText),
          isNotEmpty,
        );
        expect(
          recorder.steps
              .where((s) => s.action == RecordedAction.enterText)
              .map((s) => s.input),
          contains('display_name'),
        );
        expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        expect(
          jsonEncode(recorder.snapshot()),
          isNot(contains('Fictional Person')),
        );
      });
    },
  );

  testWidgets(
    'settings toggles, dialogs and target-based scrolling remain recordable',
    (tester) async {
      await exercise(tester, (recorder) async {
        await tap(tester, 'settings');
        await tap(tester, 'notifications');
        await tap(tester, 'newsletter');
        await tap(tester, 'reset_preferences');
        expect(await captureName(tester, recorder), 'reset_preferences_dialog');
        await tap(tester, 'confirm_reset');
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('notifications')),
              )
              .value,
          isTrue,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('newsletter')),
              )
              .value,
          isFalse,
        );
        expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(
          recorder.steps.any(
            (s) => s.action == RecordedAction.scrollUntilVisible,
          ),
          isTrue,
        );
        expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        expect(jsonEncode(recorder.snapshot()), isNot(contains('"position"')));
      });
    },
  );
}
