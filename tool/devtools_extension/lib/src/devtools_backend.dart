import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:dtd/dtd.dart';
import 'package:patrol_recorder/model.dart';
import 'package:yaml/yaml.dart';

import 'backend.dart';

class DevToolsRecorderBackend implements RecorderBackend {
  @override
  Future<bool> addKeyEnabled() async {
    final connection = dtdManager.connection.value;
    if (connection == null) {
      throw StateError(
        'Connect an authorized DTD workspace to read recorder_config. Launch with --print-dtd or use IDE-managed DevTools.',
      );
    }
    final roots = await connection.getProjectRoots();
    final uris = roots.uris;
    if (uris == null || uris.isEmpty) {
      throw StateError('No authorized app project roots are available.');
    }
    final candidates = <String>[];
    for (final root in uris.toSet()) {
      final directory = root.path.endsWith('/')
          ? root
          : root.replace(path: '${root.path}/');
      final content = (await connection.readFileAsString(
        directory.resolve('pubspec.yaml'),
      )).content;
      if (content == null) {
        throw StateError('DTD returned no app pubspec content.');
      }
      final document = loadYaml(content);
      if (document is Map &&
          document.containsKey('flutter') &&
          [document['dependencies'], document['dev_dependencies']].any(
            (dependencies) =>
                dependencies is Map &&
                dependencies.containsKey('patrol_recorder'),
          )) {
        candidates.add(content);
      }
    }
    if (candidates.isEmpty) {
      throw StateError(
        'No Flutter app with a patrol_recorder dependency was found in the authorized workspace.',
      );
    }
    if (candidates.length != 1) {
      throw StateError(
        'Cannot identify the recording app pubspec in DTD roots.',
      );
    }
    return parseAddKeyEnabled(candidates.single);
  }

  @override
  Future<Map<String, dynamic>> command(
    String command, {
    Map<String, String> parameters = const {},
  }) async {
    if (serviceManager.service == null) {
      throw StateError('No app VM Service is connected.');
    }
    final response = await serviceManager
        .callServiceExtensionOnMainIsolate(
          recorderServiceMethod,
          args: {...parameters, 'command': command},
        )
        .timeout(const Duration(seconds: 15));
    final json = response.json;
    if (json == null || json['protocolVersion'] != recorderProtocolVersion) {
      throw const FormatException(
        'Recorder protocol mismatch. Rebuild the extension and restart the recording app.',
      );
    }
    return json;
  }
}
