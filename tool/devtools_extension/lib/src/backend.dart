import 'exporter.dart';

abstract interface class RecorderBackend {
  Future<Map<String, dynamic>> command(String command);
  Future<List<Uri>> projects();
  WorkspaceFiles get files;
}
