// User-owned. Add setup/assertions here. Regeneration preserves this file.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'async_flow_inputs.dart';
import 'async_flow_steps.g.dart';

void main() {
  patrolTest(recordedJourneyName, ($) async {
    final inputs = await loadInputs().timeout(
      const Duration(milliseconds: 15000),
      onTimeout: () => throw StateError(
        'Input provider timed out. Check the fixture provider or increase recorder_config.wait_timeout_ms.',
      ),
    );
    await runRecordedJourney($, inputs);
    await $('Selection confirmed: Option 24')
        .waitUntilVisible(timeout: const Duration(seconds: 15));
    expect(find.text('Selection confirmed: Option 24'), findsOneWidget);
    await $('Long press received')
        .waitUntilVisible(timeout: const Duration(seconds: 15));
    expect(find.text('Long press received'), findsOneWidget);
    await $(find.byKey(const ValueKey<String>('loop_animation')))
        .waitUntilVisible(timeout: const Duration(seconds: 15));
    expect(
      $.tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey<String>('loop_animation')),
          )
          .value,
      isFalse,
    );
  }, tags: [recordedJourneyTag]);
}
