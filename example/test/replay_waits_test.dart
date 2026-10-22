import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:patrol_recorder_example/app.dart';

void main() {
  patrolWidgetTest(
    'public Patrol waits scroll through Future-backed pages without settling the app',
    ($) async {
      try {
        await $.tester.pumpWidget(createApp());
        await $(find.byKey(const ValueKey('login')))
            .tap(settlePolicy: SettlePolicy.noSettle);
        await $(find.byKey(const ValueKey('open_async')))
            .tap(settlePolicy: SettlePolicy.noSettle);
        final paragraph = find.byKey(const ValueKey('legal_paragraph'));
        await $(paragraph).waitUntilVisible();
        await $.tester.tapOnText(
          find.textRange.ofSubstring('Terms', descendentOf: paragraph),
        );
        final ready = find.byWidgetPredicate(
          (w) =>
              w is FilledButton &&
              w.key == const ValueKey('after_api') &&
              w.onPressed != null,
        );
        await $(ready).waitUntilVisible();
        await $(ready).tap(settlePolicy: SettlePolicy.noSettle);
        await $(find.byKey(const ValueKey('open_lazy_picker')))
            .tap(settlePolicy: SettlePolicy.noSettle);
        final view = find.byKey(const ValueKey('async_options'));
        await $(view).waitUntilVisible();
        final target = find.byKey(const ValueKey('option_24'));
        try {
          final scrollable = find.descendant(
            of: view,
            matching: find.byType(Scrollable),
          );
          await $.tester.scrollUntilVisible(
            target,
            $.tester.getSize(view).height * 0.6,
            scrollable: scrollable,
            maxScrolls: 60,
            duration: const Duration(milliseconds: 250),
            continuous: true,
          );
          await $(target).waitUntilVisible();
        } catch (error) {
          final states = $.tester
              .stateList<ScrollableState>(
                find.descendant(of: view, matching: find.byType(Scrollable)),
              )
              .toList();
          fail(
            'Scroll failed: ${error.runtimeType}; offsets: ${states.map((s) => '${s.position.pixels}/${s.position.maxScrollExtent}')}',
          );
        }
        await $(target).tap(settlePolicy: SettlePolicy.noSettle);
        await $(find.byKey(const ValueKey('confirm_option')))
            .tap(settlePolicy: SettlePolicy.noSettle);
        await $('Selection confirmed: Option 24').waitUntilVisible();
      } finally {
        await $.tester.pumpWidget(const SizedBox());
        await $.tester.pump(const Duration(seconds: 1));
      }
    },
  );
}
