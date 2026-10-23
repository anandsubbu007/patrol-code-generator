import 'exporter.dart';

abstract interface class RecorderBackend {
  Future<Map<String, dynamic>> command(
    String command, {
    Map<String, String> parameters = const {},
  });
  Future<List<Uri>> projects();
  WorkspaceFiles get files;
}
