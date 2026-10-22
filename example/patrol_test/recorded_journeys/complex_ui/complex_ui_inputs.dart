// User-owned. Connect fixtures or secret providers here. Regeneration preserves this file.
import 'complex_ui_inputs.g.dart';

class LocalJourneyInputs extends JourneyInputs {
  const LocalJourneyInputs(this.profile);
  final String profile;
}

Future<JourneyInputs> loadInputs() async {
  const profile = String.fromEnvironment(
    'RECORDER_PROFILE',
    defaultValue: "demo",
  );
  if (!const <String>{"demo"}.contains(profile)) {
    throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    );
  }
  return const LocalJourneyInputs(profile);
}
