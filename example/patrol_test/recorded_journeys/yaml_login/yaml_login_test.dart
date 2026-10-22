// User-owned. Add setup/assertions here. Regeneration preserves this file.
import 'package:patrol/patrol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'yaml_login_inputs.dart';
import 'yaml_login_steps.g.dart';

void main() {
  patrolTest(recordedJourneyName, ($) async {
    final inputs = await loadInputs();
    await runRecordedJourney($, inputs);
    await $('Demo account is open')
        .waitUntilVisible(timeout: const Duration(seconds: 15));
    expect(find.text('Demo account is open'), findsOneWidget);
  }, tags: [recordedJourneyTag]);
}
