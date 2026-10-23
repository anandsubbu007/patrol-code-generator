// User-owned. Connect fixtures or secret providers here. Regeneration preserves this file.
import 'dart:convert';

import '../../../../m2_fixture_adapter.dart';
import 'empty_inputs.g.dart';

/// User-owned input implementation; regeneration preserves this file.
///
/// Recorded values are not saved. Connect required inputs before replay.
/// Keep real credentials out of source code, YAML, and generated files.
class LocalJourneyInputs extends JourneyInputs with DemoFixtureAdapter {
  const LocalJourneyInputs(this.profile);
  final String profile;
  @override
  double get inputCredit => switch (profile) {
    "demo" => 24.5,
    "empty" => 0.0,
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  String get inputEmail => switch (profile) {
    "demo" => "ada@example.invalid",
    "empty" => "empty@example.invalid",
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  bool get inputEnabled => switch (profile) {
    "demo" => true,
    "empty" => false,
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  Object get inputOptions => switch (profile) {
    "demo" => jsonDecode("{\"source\":\"local_fixture\"}") as Object,
    "empty" => jsonDecode("{\"source\":\"local_fixture\"}") as Object,
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  int get inputQuantity => switch (profile) {
    "demo" => 2,
    "empty" => 0,
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
}

/// Loads test fixtures or private-provider data before replay.
///
/// Add asynchronous provider initialization here when needed.
Future<JourneyInputs> loadInputs() async {
  const profile = String.fromEnvironment(
    'RECORDER_PROFILE',
    defaultValue: "empty",
  );
  if (!const <String>{"demo", "empty"}.contains(profile)) {
    throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    );
  }
  return const LocalJourneyInputs(profile);
}
