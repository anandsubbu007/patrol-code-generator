// User-owned. Add setup/assertions here. Regeneration preserves this file.
import 'package:patrol/patrol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'complex_ui_inputs.dart';
import 'complex_ui_steps.g.dart';

void main() {
  patrolTest(recordedJourneyName, ($) async {
    final inputs = await loadInputs();
    await runRecordedJourney($, inputs);
    await $('Account settings')
        .waitUntilVisible(timeout: const Duration(seconds: 15));
    expect(find.text('Account settings'), findsOneWidget);
    expect(
      $.tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('notifications')))
          .value,
      isTrue,
    );
  }, tags: [recordedJourneyTag]);
}
