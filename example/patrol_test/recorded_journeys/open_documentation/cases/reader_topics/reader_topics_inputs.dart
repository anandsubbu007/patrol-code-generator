// User-owned. Connect fixtures or secret providers here. Regeneration preserves this file.
import 'dart:convert';

import 'reader_topics_inputs.g.dart';

/// User-owned input implementation; regeneration preserves this file.
///
/// Recorded values are not saved. Connect required inputs before replay.
/// Keep real credentials out of source code, YAML, and generated files.
class LocalJourneyInputs extends JourneyInputs {
  const LocalJourneyInputs(this.profile);
  final String profile;
  @override
  int get inputArticleLimit => switch (profile) {
    "demo" => 2,
    "reader" => 3,
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  String get inputAudience => switch (profile) {
    "demo" => "demo",
    "reader" => "reader",
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  bool get inputIncludeFixtures => switch (profile) {
    "demo" => true,
    "reader" => false,
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  Object get inputMetadata => switch (profile) {
    "demo" => jsonDecode("{\"edition\":\"M2 fixture guide\"}") as Object,
    "reader" => jsonDecode("{\"edition\":\"Reader guide\"}") as Object,
    _ => throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    ),
  };
  @override
  double get inputTextScale => switch (profile) {
    "demo" => 1.0,
    "reader" => 1.1,
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
    defaultValue: "reader",
  );
  if (!const <String>{"demo", "reader"}.contains(profile)) {
    throw StateError(
      'Unknown RECORDER_PROFILE; inspect the user-owned inputs file.',
    );
  }
  return const LocalJourneyInputs(profile);
}
