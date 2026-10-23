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
  const GenerationSummary(
    this.root,
    this.journeys,
    this.result, {
    this.selectors = const [],
  });
  final Uri root;
  final List<GeneratedJourney> journeys;
  final ExportResult result;
  final List<Map<String, Object?>> selectors;
}

class LocalRecordings {
  LocalRecordings._(
    this.root,
    this.workspace,
    this.pubspec,
    this.defaults,
    this.directory,
  );

  final Uri root;
  final LocalWorkspaceFiles workspace;
  final String pubspec;
  final ExportConfig defaults;
  final String directory;

  static Future<LocalRecordings> open(
    Directory project, {
    String? recordingsDirectory,
  }) async {
    final root = Directory(await project.resolveSymbolicLinks()).uri;
    final workspace = LocalWorkspaceFiles(root);
    final source = await workspace.read(root.resolve('pubspec.yaml'));
    if (source == null) {
      throw StateError('No pubspec.yaml in the selected app project.');
    }
    final defaults = ExportConfig.fromPubspec(source);
    final directory = validateRelativePath(
      recordingsDirectory ?? defaults.recordingsDirectory,
    );
    await workspace.exists(root.resolve('$directory/.path_check'));
    return LocalRecordings._(root, workspace, source, defaults, directory);
  }

  Future<List<Uri>> journeys() async {
    final folder = Directory.fromUri(root.resolve('$directory/'));
    if (!await folder.exists()) return [];
    final paths = <Uri>[];
    await for (final entity in folder.list(followLinks: false)) {
      if ((entity is File || entity is Link) && entity.path.endsWith('.yml')) {
        paths.add(entity.uri);
      }
    }
    return paths..sort((a, b) => a.toString().compareTo(b.toString()));
  }

  /// Plans only named files, never whole directories or authored fixture assets.
  Future<Map<Uri, List<int>>> resetPlan({
    required bool screenshots,
    required bool generatedCode,
  }) async {
    final paths = await journeys();
    final candidates = paths.toSet();
    for (final uri in paths) {
      if (!screenshots && !generatedCode) continue;
      final yaml = await workspace.read(uri);
      if (yaml == null) {
        throw StateError('Recording changed while planning reset: $uri');
      }
      final recording = RecordedJourney.fromYaml(yaml);
      if (uri.pathSegments.last != '${recording.id}.yml') {
        throw StateError('Journey filename must match ${recording.id}.yml.');
      }
      if (screenshots) {
        candidates.addAll(
          recording.screenshots.map((image) => root.resolve(image.path)),
        );
      }
      if (generatedCode) {
        for (final item in recording.effectiveCases) {
          final config = ExportConfig(
            outputDirectory: recording.cases.isEmpty
                ? defaults.outputDirectory
                : '${defaults.outputDirectory}/${recording.id}/cases',
            journeyId: recording.cases.isEmpty ? recording.id : item.id,
          );
          candidates.addAll(
            [
              config.stepsPath,
              config.contractPath,
              config.inputsPath,
              config.testPath,
            ].map(root.resolve),
          );
        }
      }
    }
    final plan = <Uri, List<int>>{};
    for (final uri in candidates) {
      if (await workspace.exists(uri)) {
        final file = await workspace._file(uri);
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw FileSystemException('Reset expects a regular file.', file.path);
        }
        plan[uri] = await file.readAsBytes();
      }
    }
    return plan;
  }

  Future<void> deletePlanned(Map<Uri, List<int>> plan) async {
    // Check every file before deleting any; confirmation may have taken time.
    for (final entry in plan.entries) {
      final file = await workspace._file(entry.key);
      final current = await file.readAsBytes();
      if (current.length != entry.value.length ||
          !Iterable<int>.generate(current.length)
              .every((index) => current[index] == entry.value[index])) {
        throw StateError('Reset cancelled: ${file.path} changed.');
      }
    }
    var deleted = 0;
    for (final uri in plan.keys) {
      try {
        await (await workspace._file(uri)).delete();
        deleted++;
      } on FileSystemException catch (error) {
        throw FileSystemException(
          'Reset stopped after $deleted files: ${error.message}',
          error.path,
        );
      }
    }
  }
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
  String? selectedCase,
  bool preview = false,
}) async {
  if (selectedCase != null) {
    if (journey == null) {
      throw const FormatException('--case requires --journey.');
    }
    requireIdentifier(selectedCase, 'Case ID');
  }
  final catalog = await LocalRecordings.open(
    project,
    recordingsDirectory: recordingsDirectory,
  );
  final root = catalog.root;
  final workspace = catalog.workspace;
  final source = catalog.pubspec;
  final defaults = catalog.defaults;
  final recordings = catalog.directory;
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
    paths.addAll(await catalog.journeys());
  }
  if (paths.isEmpty) throw StateError('No .yml journeys found in $recordings.');
  final originals = <Uri, String>{};
  final outputs = <GeneratedJourney>[];
  final validationErrors = <String>[];
  final selectors = <Map<String, Object?>>[];
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
      final missingScreenshots = <String>[];
      for (final image in recording.screenshots) {
        if (!await workspace.exists(root.resolve(image.path))) {
          missingScreenshots.add(image.path);
        }
      }
      if (missingScreenshots.isNotEmpty) {
        throw StateError(
          'Missing recorded screenshots:\n'
          '${missingScreenshots.map((path) => '  - $path').join('\n')}\n'
          'Screenshot paths in YAML are relative to the app project: ${root.toFilePath()}\n'
          'Restore these files or re-record "${recording.id}" in DevTools. '
          'Changing screenshots_directory does not update existing recordings.',
        );
      }
      final resolved = await recording.resolveAssets(
        workspace,
        root,
        recordings,
      );
      originals.addAll(resolved.sources);
      originals[uri] = yaml;
      outputs.addAll(
        recording.generateCases(
          defaults,
          app: app,
          assetValues: resolved.values,
          selectedCase: selectedCase,
        ),
      );
      selectors.addAll(
        recording
            .inspectSelectors(selectedCase: selectedCase)
            .map((selector) => {'journey_id': recording.id, ...selector}),
      );
    } on FormatException catch (error) {
      validationErrors.add('${uri.pathSegments.last}: ${error.message}');
    } on StateError catch (error) {
      validationErrors.add('${uri.pathSegments.last}: ${error.message}');
    } on FileSystemException catch (error) {
      validationErrors.add(
        '${uri.pathSegments.last}: ${error.message} (${error.path ?? 'filesystem'})',
      );
    }
  }
  if (validationErrors.isNotEmpty) {
    throw StateError(
      '${journey == null ? 'Batch validation checks every .yml journey in $recordings/ (${paths.length} selected).' : 'Validation checks only the selected journey "$journey".'}\n'
      '${validationErrors.join('\n\n')}\n\n'
      'No output files were written. Fix the invalid recordings and retry.'
      '${journey == null ? '\nWithout --journey, an invalid recording blocks the entire batch.' : ''}'
      '${journey == null && outputs.isNotEmpty ? '\nValid journeys: ${outputs.map((output) => output.config.journeyId).join(', ')}.\nTo generate only one of these, add --journey ${outputs.first.config.journeyId} to your original command.' : ''}',
    );
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
  if (files.keys.any((path) => originals.containsKey(root.resolve(path)))) {
    throw StateError(
      'Generated outputs collide with journey or asset sources. Choose a different output directory.',
    );
  }
  if (preview) {
    return GenerationSummary(
      root,
      outputs,
      const ExportResult([], []),
      selectors: selectors,
    );
  }
  for (final entry in originals.entries) {
    if (await workspace.read(entry.key) != entry.value) {
      throw StateError(
        'A recording or asset changed during generation. Stop recording and retry.',
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
  return GenerationSummary(root, outputs, result, selectors: selectors);
}
