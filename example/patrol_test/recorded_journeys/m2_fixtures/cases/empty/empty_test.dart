// User-owned. Add setup/assertions here. Regeneration preserves this file.
import 'package:patrol/patrol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder_example/fixture_lab.dart';

import 'empty_inputs.dart';
import 'empty_steps.g.dart';

/// User-owned Patrol entrypoint; regeneration preserves setup and assertions.
///
/// Run from the application directory containing its Patrol dependency:
/// `patrol test --target patrol_test/recorded_journeys/m2_fixtures/cases/empty/empty_test.dart --dart-define RECORDER_PROFILE=empty`
///
/// Use Patrol CLI, not the IDE's standard Run Test button or direct flutter test.
/// Patrol CLI generates test_bundle.dart and initializes patrolAppService.
/// Do not edit or commit test_bundle.dart.
void main() {
  patrolTest(recordedJourneyName, ($) async {
    addTearDown(demoFixtures.clear);
    final inputs = await loadInputs().timeout(
      const Duration(milliseconds: 15000),
      onTimeout: () => throw StateError(
        'Input provider timed out. Check the fixture provider or increase recorder_config.wait_timeout_ms.',
      ),
    );
    await runRecordedJourney($, inputs);
    expect(demoFixtures.quantity, 0);
    expect(demoFixtures.enabled, false);
    expect(demoFixtures.credit, 0);
  }, tags: [recordedJourneyTag]);
}
