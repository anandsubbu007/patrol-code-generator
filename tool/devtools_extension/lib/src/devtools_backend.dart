import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:dtd/dtd.dart';
import 'package:patrol_recorder/model.dart';

import 'backend.dart';
import 'exporter.dart';

class DevToolsRecorderBackend implements RecorderBackend {
  @override
  WorkspaceFiles get files {
    final connection = dtdManager.connection.value;
    if (connection == null) {
      throw StateError(
        'Workspace export needs the DevTools DTD connection. Start the app with --print-dtd or use an IDE-managed DevTools session.',
      );
    }
    return DtdWorkspaceFiles(connection);
  }

  @override
  Future<List<Uri>> projects() async {
    final connection = dtdManager.connection.value;
    if (connection == null) {
      throw StateError(
        'No authorized workspace connection. Start the app with --print-dtd or use an IDE-managed DevTools session.',
      );
    }
    final roots = await connection.getProjectRoots();
    if (roots.uris == null) {
      throw StateError('DTD returned no project listing.');
    }
    return roots.uris!
        .map(
          (uri) =>
              uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/'),
        )
        .toList();
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
