import 'dart:convert';
import 'dart:typed_data';

import 'package:dtd/dtd.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:patrol_recorder_generator/generator.dart';

export 'package:patrol_recorder_generator/generator.dart'
    show WorkspaceFiles, ExportResult, exportFiles;

class DtdWorkspaceFiles implements WorkspaceFiles {
  DtdWorkspaceFiles(this.connection);
  final DartToolingDaemon connection;

  @override
  Future<bool> exists(Uri uri) async {
    try {
      final entries = await connection.listDirectoryContents(uri.resolve('.'));
      final uris = entries.uris;
      if (uris == null) throw StateError('DTD returned no directory listing.');
      return uris.contains(uri);
    } on RpcException catch (error) {
      if (error.code == RpcErrorCodes.kDirectoryDoesNotExist) return false;
      rethrow;
    }
  }

  @override
  Future<String?> read(Uri uri) async {
    try {
      final response = await connection.readFileAsString(uri);
      final content = response.content;
      if (content == null) throw StateError('DTD returned no file content.');
      return content;
    } on RpcException catch (error) {
      if (error.code == RpcErrorCodes.kFileDoesNotExist) return null;
      rethrow;
    }
  }

  @override
  Future<void> write(Uri uri, Uint8List bytes) =>
      connection.writeFileAsString(uri, latin1.decode(bytes), encoding: latin1);
}
