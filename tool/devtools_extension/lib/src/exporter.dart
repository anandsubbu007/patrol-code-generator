import 'dart:convert';
import 'dart:typed_data';

import 'package:dtd/dtd.dart';
import 'package:json_rpc_2/json_rpc_2.dart';

import 'generator.dart';

abstract interface class WorkspaceFiles {
  Future<bool> exists(Uri uri);
  Future<String?> read(Uri uri);
  Future<void> write(Uri uri, Uint8List bytes);
}

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

/// Create-only export. A project configuration is preserved, never overwritten.
Future<List<String>> exportNewFiles({
  required WorkspaceFiles workspace,
  required Uri projectRoot,
  required Map<String, Uint8List> files,
}) async {
  if (projectRoot.scheme != 'file' || !projectRoot.path.endsWith('/')) {
    throw const FormatException('Select an authorized project directory URI.');
  }
  final pending = <String, Uri>{};
  for (final name in files.keys) {
    validateRelativePath(name);
    final uri = projectRoot.resolve(name);
    if (await workspace.exists(uri)) {
      if (name == 'recorder_config.yaml') continue;
      throw StateError(
        'Export refused: $name already exists. Choose a new journey ID.',
      );
    }
    pending[name] = uri;
  }
  final written = <String>[];
  for (final entry in pending.entries) {
    // DTD has no exclusive-create transaction: recheck immediately before writing.
    if (await workspace.exists(entry.value)) {
      throw StateError(
        'Export stopped: ${entry.key} appeared during export. ${written.length} files saved.',
      );
    }
    await workspace.write(entry.value, files[entry.key]!);
    written.add(entry.key);
    // Current DTD hosts ignore the read encoding and cannot read arbitrary PNGs.
    final verified = entry.key.endsWith('.png')
        ? await workspace.exists(entry.value)
        : await workspace.read(entry.value) == utf8.decode(files[entry.key]!);
    if (!verified) {
      throw StateError(
        'Export verification failed for ${entry.key}. ${written.length} files saved.',
      );
    }
  }
  return written;
}
