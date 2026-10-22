import 'dart:convert';
import 'dart:typed_data';

import 'generator.dart';

abstract interface class WorkspaceFiles {
  Future<bool> exists(Uri uri);
  Future<String?> read(Uri uri);
  Future<void> write(Uri uri, Uint8List bytes);
}

class ExportResult {
  const ExportResult(this.written, this.preserved);
  final List<String> written;
  final List<String> preserved;
}

/// User-owned files are never overwritten. Generated files require explicit consent.
Future<ExportResult> exportFiles({
  required WorkspaceFiles workspace,
  required Uri projectRoot,
  required Map<String, Uint8List> files,
  Set<String> userOwnedPaths = const {},
  Map<String, String> generatedMarkers = const {},
  bool updateGenerated = false,
}) async {
  if (projectRoot.scheme != 'file' || !projectRoot.path.endsWith('/')) {
    throw const FormatException('Select an authorized project directory URI.');
  }
  final pending = <String, Uri>{};
  final previous = <String, String>{};
  final preserved = <String>[];
  for (final name in files.keys) {
    validateRelativePath(name);
    final uri = projectRoot.resolve(name);
    if (await workspace.exists(uri)) {
      if (userOwnedPaths.contains(name)) {
        preserved.add(name);
        continue;
      }
      final marker = generatedMarkers[name];
      if (!updateGenerated || marker == null) {
        throw StateError(
          'Export refused: $name exists. Choose a new journey ID or explicitly update generated files.',
        );
      }
      final content = await workspace.read(uri);
      if (content == null || !content.startsWith(marker)) {
        throw StateError(
          'Refusing to replace $name: it is not a recognized generated file.',
        );
      }
      previous[name] = content;
    }
    pending[name] = uri;
  }
  final written = <String>[];
  for (final entry in pending.entries) {
    // DTD has no exclusive-create transaction: recheck immediately before writing.
    if (previous.containsKey(entry.key)
        ? await workspace.read(entry.value) != previous[entry.key]
        : await workspace.exists(entry.value)) {
      throw StateError(
        'Export stopped: ${entry.key} appeared during export. ${written.length} files saved.',
      );
    }
    try {
      await workspace.write(entry.value, files[entry.key]!);
    } on Exception catch (error) {
      throw StateError(
        'Export failed at ${entry.key}; ${written.length} files already saved. $error',
      );
    }
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
  return ExportResult(written, preserved);
}
