// User-owned. Add setup/assertions here. Regeneration preserves this file.
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
  }, tags: [recordedJourneyTag]);
}
