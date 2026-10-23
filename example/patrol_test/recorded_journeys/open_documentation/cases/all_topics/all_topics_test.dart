// User-owned. Add setup/assertions here. Regeneration preserves this file.
import 'package:patrol/patrol.dart';

import 'all_topics_inputs.dart';
import 'all_topics_steps.g.dart';

/// User-owned Patrol entrypoint; regeneration preserves setup and assertions.
///
/// Run from the application directory containing its Patrol dependency:
/// `patrol test --target patrol_test/recorded_journeys/open_documentation/cases/all_topics/all_topics_test.dart --dart-define RECORDER_PROFILE=demo`
///
/// Use Patrol CLI, not the IDE's standard Run Test button or direct flutter test.
/// Patrol CLI generates test_bundle.dart and initializes patrolAppService.
/// Do not edit or commit test_bundle.dart.
void main() {
  patrolTest(recordedJourneyName, ($) async {
    final inputs = await loadInputs().timeout(
      const Duration(milliseconds: 15000),
      onTimeout: () => throw StateError(
        'Input provider timed out. Check the fixture provider or increase recorder_config.wait_timeout_ms.',
      ),
    );
    await runRecordedJourney($, inputs);
    // TODO: Add bounded waits and assertions for the expected final outcome.
  }, tags: [recordedJourneyTag]);
}
