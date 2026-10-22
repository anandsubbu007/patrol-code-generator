class JourneyData {
  const JourneyData(this.name, this.values);
  final String name;
  final Map<String, String> values;

  String value(String name) {
    final result = values[name];
    if (result == null || result.isEmpty) {
      throw StateError('Missing non-secret profile field: $name');
    }
    return result;
  }

  String secret(String name) {
    const secrets = <String, String>{};
    final result = secrets[name];
    if (result == null || result.isEmpty) {
      throw StateError(
        'Missing secret reference: $name (use a private dart-define file)',
      );
    }
    return result;
  }
}

// Edit non-secret values here. Never add passwords or tokens.
const profiles = <String, Map<String, String>>{
  "demo": {"email": "demo@example.invalid", "note": "Personal demonstration"},
  "secondary": {
    "email": "second@example.invalid",
    "note": "Secondary demonstration",
  },
};

JourneyData loadProfile() {
  const name = String.fromEnvironment('RECORDER_PROFILE', defaultValue: "demo");
  final values = profiles[name];
  if (values == null) {
    throw StateError(
      'Unknown RECORDER_PROFILE; inspect the journey data file.',
    );
  }
  final result = JourneyData(name, values);
  for (final field in <String>["email", "note"]) {
    result.value(field);
  }
  for (final field in <String>[]) {
    result.secret(field);
  }
  return result;
}
