// User-owned. Connect fixtures or secret providers here. Regeneration preserves this file.
import 'yaml_login_inputs.g.dart';
import '../../demo_profiles.dart';

class LocalJourneyInputs extends JourneyInputs {
  const LocalJourneyInputs(this.profile);
  final String profile;
  @override
  String get inputEmail =>
      demoProfiles[profile]?['email'] ??
      (throw StateError('Missing email in the selected test fixture.'));
  @override
  String get inputNote =>
      demoProfiles[profile]?['note'] ??
      (throw StateError('Missing note in the selected test fixture.'));
}

Future<JourneyInputs> loadInputs() async {
  const profile = String.fromEnvironment(
    'RECORDER_PROFILE',
    defaultValue: "demo",
  );
  if (!demoProfiles.containsKey(profile)) {
    throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    );
  }
  return const LocalJourneyInputs(profile);
}
