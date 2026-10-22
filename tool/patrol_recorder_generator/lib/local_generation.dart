import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:patrol_recorder/model.dart';
import 'package:yaml/yaml.dart';

import 'file_export.dart';
import 'generator.dart';
import 'journey.dart';

/// Local CLI writes use sibling temporary files and reject symlinked destinations.
class LocalWorkspaceFiles implements WorkspaceFiles {
  LocalWorkspaceFiles(this.root);
  final Uri root;
  int _nextTemp = 0;

  Future<File> _file(Uri uri) async {
    if (root.scheme != 'file' ||
        !root.path.endsWith('/') ||
        uri.scheme != 'file' ||
        !uri.path.startsWith(root.path)) {
      throw const FormatException('File is outside the app project.');
    }
    final relative = uri.path.substring(root.path.length);
    validateRelativePath(relative);
    var cursor = root;
    for (final part in relative.split('/')) {
      cursor = cursor.resolve(part);
      final type = await FileSystemEntity.type(
        cursor.toFilePath(),
        followLinks: false,
      );
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'Symlinked generator paths are not supported.',
          cursor.toFilePath(),
        );
      }
      cursor = Uri.directory(cursor.toFilePath());
    }
    return File.fromUri(uri);
  }

  @override
  Future<bool> exists(Uri uri) async => (await _file(uri)).exists();

  @override
  Future<String?> read(Uri uri) async {
    final file = await _file(uri);
    if (!await file.exists()) return null;
    if (await file.length() > 2 * 1024 * 1024) {
      throw FileSystemException(
        'Generator text file exceeds 2 MiB.',
        file.path,
      );
    }
    return file.readAsString();
  }

  @override
  Future<void> write(Uri uri, Uint8List bytes) async {
    final file = await _file(uri);
    await file.parent.create(recursive: true);
    await _file(uri);
    final temp = File('${file.path}.patrol_tmp_${pid}_${_nextTemp++}');
    await temp.create(exclusive: true);
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await _file(uri);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}

class GenerationSummary {
  const GenerationSummary(this.root, this.journeys, this.result);
  final Uri root;
  final List<GeneratedJourney> journeys;
  final ExportResult result;
}

Future<RecorderAppConfig> resolveAppBootstrap(
  WorkspaceFiles workspace,
  Uri root,
  String pubspec,
  ExportConfig config, {
  RecorderAppConfig? legacy,
}) async {
  final document = loadYaml(pubspec);
  if (document is! YamlMap || document['name'] is! String) {
    throw const FormatException(
      'The app pubspec must declare its package name.',
    );
  }
  final package = document['name'] as String;
  final app = RecorderAppConfig(
    appImport:
        config.appImport ?? legacy?.appImport ?? 'package:$package/main.dart',
    appBuilder:
        config.appBuilder ??
        (config.appImport == null ? legacy?.appBuilder : null) ??
        'main',
  );
  final import = Uri.parse(app.appImport!);
  if (import.pathSegments.first != package) {
    throw StateError(
      'The configured app import must belong to package $package.',
    );
  }
  final path = 'lib/${import.pathSegments.skip(1).join('/')}';
  final source = await workspace.read(root.resolve(path));
  if (source == null) {
    throw StateError(
      'Cannot find $path. The default is lib/main.dart -> main(). '
      'For custom test initialization, set recorder_config.app_import and app_builder once in pubspec.yaml.',
    );
  }
  final parsed = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  if (parsed.errors.isNotEmpty) {
    throw FormatException('Fix Dart syntax errors in $path before generation.');
  }
  final candidates = parsed.unit.declarations
      .whereType<FunctionDeclaration>()
      .where((function) => function.name.lexeme == app.appBuilder)
      .toList();
  if (candidates.length != 1) {
    throw StateError(
      'No unambiguous top-level ${app.appBuilder}() in $path. '
      'Configure a local no-argument entrypoint or widget builder explicitly.',
    );
  }
  final parameters = candidates.single.functionExpression.parameters;
  if (parameters == null ||
      parameters.parameters.any(
        (p) => p.isRequiredNamed || p.isRequiredPositional,
      )) {
    throw StateError(
      '${app.appBuilder} in $path requires arguments. Configure a no-argument test adapter.',
    );
  }
  return app;
}

Future<GenerationSummary> generateProject(
  Directory project, {
  String? journey,
  String? recordingsDirectory,
}) async {
  final root = Directory(await project.resolveSymbolicLinks()).uri;
  final workspace = LocalWorkspaceFiles(root);
  final source = await workspace.read(root.resolve('pubspec.yaml'));
  if (source == null) {
    throw StateError('No pubspec.yaml in the selected app project.');
  }
  final defaults = ExportConfig.fromPubspec(source);
  final recordings = validateRelativePath(
    recordingsDirectory ?? defaults.recordingsDirectory,
  );
  final directory = Directory.fromUri(root.resolve('$recordings/'));
  // Check the directory itself for symlinks before listing.
  await workspace.exists(root.resolve('$recordings/.path_check'));
  if (!await directory.exists()) {
    throw StateError(
      'No $recordings/ directory. Record a named journey in DevTools first.',
    );
  }
  final paths = <Uri>[];
  if (journey != null) {
    // Same validation as the recorder's journey-name field.
    ExportConfig(journeyId: journey);
    paths.add(directory.uri.resolve('$journey.yml'));
  } else {
    await for (final entity in directory.list(followLinks: false)) {
      if ((entity is File || entity is Link) && entity.path.endsWith('.yml')) {
        paths.add(entity.uri);
      }
    }
    paths.sort((a, b) => a.toString().compareTo(b.toString()));
  }
  if (paths.isEmpty) throw StateError('No .yml journeys found in $recordings.');
  final originals = <Uri, String>{};
  final outputs = <GeneratedJourney>[];
  for (final uri in paths) {
    try {
      final yaml = await workspace.read(uri);
      if (yaml == null) {
        throw StateError('Journey file not found: ${uri.toFilePath()}');
      }
      final recording = RecordedJourney.fromYaml(yaml);
      if (uri.pathSegments.last != '${recording.id}.yml') {
        throw StateError(
          'Journey filename must match its recorded ID: ${recording.id}.yml.',
        );
      }
      final app = await resolveAppBootstrap(
        workspace,
        root,
        source,
        defaults,
        legacy: recording.legacyApp,
      );
      for (final image in recording.screenshots) {
        if (!await workspace.exists(root.resolve(image.path))) {
          throw StateError(
            'Missing recorded screenshot: ${image.path}. Restore it or re-record the journey.',
          );
        }
      }
      originals[uri] = yaml;
      outputs.add(recording.generate(defaults, app: app));
    } on FormatException catch (error) {
      throw FormatException(
        '${uri.pathSegments.last}: ${error.message}\n'
        'Re-record this journey or fix its identified widget keys. Dynamic values belong in the Dart input provider, not YAML.',
      );
    } on StateError catch (error) {
      throw StateError('${uri.pathSegments.last}: ${error.message}');
    }
  }
  final files = <String, Uint8List>{};
  for (final output in outputs) {
    for (final entry in output.files().entries) {
      if (files.containsKey(entry.key)) {
        throw StateError('Duplicate generated output: ${entry.key}');
      }
      files[entry.key] = entry.value;
    }
  }
  for (final entry in originals.entries) {
    if (await workspace.read(entry.key) != entry.value) {
      throw StateError(
        'A recording changed during generation. Stop recording and retry.',
      );
    }
  }
  final result = await exportFiles(
    workspace: workspace,
    projectRoot: root,
    files: files,
    userOwnedPaths: {for (final output in outputs) ...output.userOwnedPaths},
    generatedMarkers: {
      for (final output in outputs)
        for (final path in output.generatedPaths) path: output.config.marker,
    },
    updateGenerated: true,
  );
  return GenerationSummary(root, outputs, result);
}
