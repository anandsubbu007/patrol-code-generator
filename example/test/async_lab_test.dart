import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_example/app.dart';

void main() {
  testWidgets(
    'links, Future-disabled buttons and lazy dropdown scrolling work while animation loops',
    (tester) async {
      final recorder = RecorderController();
      try {
        await tester.pumpWidget(
          RecorderScope(controller: recorder, child: createApp()),
        );
        recorder.start();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('login')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open_async')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.tapOnText(
          find.textRange.ofSubstring(
            'Terms',
            descendentOf: find.byKey(const ValueKey('legal_paragraph')),
          ),
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('after_api')))
              .onPressed,
          isNull,
        );
        await tester.pump(const Duration(milliseconds: 650));
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('after_api')))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const ValueKey('after_api')));
        await tester.pump();
        expect(find.text('Future-dependent action completed'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('open_lazy_picker')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        var attempts = 0;
        final target = find.byKey(const ValueKey('option_24'));
        while (target.hitTestable().evaluate().isEmpty && attempts++ < 15) {
          await tester.drag(
            find.byKey(const ValueKey('async_options')),
            const Offset(0, -230),
          );
          await tester.pump(const Duration(milliseconds: 600));
        }
        expect(target.hitTestable(), findsOneWidget);
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const ValueKey('confirm_option')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Selection confirmed: Option 24'), findsOneWidget);
        recorder.stop();
        expect(
          recorder.steps.any(
            (s) => s.action == RecordedAction.tapText && s.text == 'Terms',
          ),
          isTrue,
        );
        final scroll = recorder.steps
            .where((s) => s.action == RecordedAction.scrollUntilVisible)
            .last;
        expect(scroll.target.key, 'option_24');
        expect(scroll.scrollView!.key, 'async_options');
        expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        expect(jsonEncode(recorder.snapshot()), isNot(contains('"position"')));
      } finally {
        if (recorder.state == RecordingState.recording) recorder.stop();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        recorder.dispose();
      }
    },
  );
}
