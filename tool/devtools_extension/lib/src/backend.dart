import 'package:yaml/yaml.dart';

bool parseAddKeyEnabled(String pubspec) {
  final document = loadYaml(pubspec);
  if (document is! Map) {
    throw const FormatException('The app pubspec must be a YAML mapping.');
  }
  final config = document['recorder_config'];
  if (config == null) return false;
  if (config is! Map) {
    throw const FormatException('recorder_config must be a mapping.');
  }
  if (!config.containsKey('addkey')) return false;
  final value = config['addkey'];
  if (value is! bool) {
    throw const FormatException(
      'recorder_config.addkey must be true or false.',
    );
  }
  return value;
}

abstract interface class RecorderBackend {
  Future<Map<String, dynamic>> command(
    String command, {
    Map<String, String> parameters = const {},
  });
  Future<bool> addKeyEnabled();
}
