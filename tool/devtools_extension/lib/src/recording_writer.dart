import 'dart:convert';
import 'dart:typed_data';

import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';

class CapturedScreen {
  const CapturedScreen(this.bytes, this.info, {required this.name});
  final Uint8List bytes;
  final Map<String, dynamic> info;
  final String name;
}

class RecordingWriter {
  RecordingWriter._(this.root, this.config, this.files, this._expected);
  final Uri root;
  final ExportConfig config;
  final WorkspaceFiles files;
  String? _expected;
  String? _attempted;
  String? _sessionId;
  final _savedImages = <String, CapturedScreen>{};
  RecordedJourney? saved;

  Uri get yamlUri => root.resolve(config.yamlPath);
  String get generateCommand =>
      'dart run patrol_recorder_generator:generate --journey ${config.journeyId}'
      ' --recordings-directory ${config.recordingsDirectory}';

  static Future<RecordingWriter> open({
    required Uri root,
    required ExportConfig config,
    required WorkspaceFiles files,
    required RecorderAppConfig app,
  }) async {
    if (root.scheme != 'file' || !root.path.endsWith('/')) {
      throw const FormatException(
        'Select an authorized app project directory.',
      );
    }
    final pubspec = await files.read(root.resolve('pubspec.yaml'));
    if (pubspec == null) {
      throw StateError('No pubspec.yaml in the selected project.');
    }
    ExportConfig.fromPubspec(
      pubspec,
      expectedPackage: app.appImport == null
          ? null
          : Uri.parse(app.appImport!).path.split('/').first,
    );
    final old = await files.read(root.resolve(config.yamlPath));
    RecordedJourney? previous;
    if (old != null) {
      if (!old.startsWith(journeyHeader)) {
        throw StateError(
          'Refusing to replace ${config.yamlPath}: it is not a recorder-owned journey.',
        );
      }
      previous = RecordedJourney.fromYaml(old);
      if (previous.id != config.journeyId) {
        throw StateError(
          'The existing YAML belongs to a different journey or app.',
        );
      }
    }
    return RecordingWriter._(root, config, files, old);
  }

  Future<void> persist(
    Map<String, dynamic> snapshot, {
    required List<CapturedScreen> captures,
    required Set<String> excluded,
    required bool acknowledgedIncomplete,
  }) async {
    final id = snapshot['sessionId'];
    if (id is! String || snapshot['state'] == 'ready') {
      throw StateError(
        'The app restarted or has no active session. The previous YAML is retained; record this journey again.',
      );
    }
    _sessionId ??= id;
    if (_sessionId != id) {
      throw StateError(
        'The app session changed. Start a new named recording; the previous YAML was not replaced.',
      );
    }
    final steps = [
      for (final raw in snapshot['steps'] as List)
        RecordedStep.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    final images = <JourneyCapture>[];
    final pending = <String, CapturedScreen>{};
    for (final capture in captures) {
      if (capture.info['sessionId'] != id) {
        throw StateError('A screenshot belongs to a different session.');
      }
      requireIdentifier(capture.name, 'Screenshot name');
      final path =
          '${config.screenshotsDirectory}/${config.journeyId}/${capture.name}.png';
      images.add(
        JourneyCapture(
          name: capture.name,
          path: path,
          afterStep: capture.info['stepId'] as String?,
          width: capture.info['width'] as int,
          height: capture.info['height'] as int,
          redactedRegions: capture.info['redactedRegions'] as int,
        ),
      );
      if (!identical(_savedImages[path], capture)) pending[path] = capture;
    }
    final document = RecordedJourney(
      id: config.journeyId,
      name: config.caseName,
      caseId: config.caseId,
      profile: config.profile,
      state: snapshot['state'] as String,
      steps: steps,
      excluded: excluded,
      screenshots: images,
      recordingError: snapshot['error'] as String?,
      acknowledgedIncomplete: acknowledgedIncomplete,
    );
    final text = document.toYaml();
    final current = await files.read(yamlUri);
    if (current != _expected && (_attempted == null || current != _attempted)) {
      throw StateError(
        'The YAML changed outside this recorder. It was not overwritten. Re-open the named recording before replacing it.',
      );
    }
    if (current == text && pending.isEmpty) {
      _expected = text;
      saved = document;
      return;
    }
    // Images must exist before the YAML can reference them.
    for (final entry in pending.entries) {
      final capture = entry.value;
      final imageUri = root.resolve(entry.key);
      final ownerUri = imageUri.resolve('.${capture.name}.recorder');
      final owner =
          'Patrol Recorder screenshot\njourney: ${config.journeyId}\nname: ${capture.name}\n';
      final existingOwner = await files.read(ownerUri);
      if (existingOwner != null && existingOwner != owner ||
          await files.exists(imageUri) && existingOwner != owner) {
        throw StateError(
          'Refusing to overwrite ${entry.key}: no matching recorder ownership marker. Choose a different screenshot name.',
        );
      }
      // Reserve this generated path before writing; retries after a failed PNG write remain safe.
      if (existingOwner == null) {
        await files.write(ownerUri, Uint8List.fromList(utf8.encode(owner)));
        if (await files.read(ownerUri) != owner) {
          throw StateError('Screenshot ownership write failed.');
        }
      }
      await files.write(imageUri, capture.bytes);
      if (!await files.exists(imageUri)) {
        throw StateError(
          'Screenshot write was not acknowledged: ${entry.key}.',
        );
      }
      _savedImages[entry.key] = capture;
    }
    if (await files.read(yamlUri) != current) {
      throw StateError(
        'The YAML changed while screenshots were being saved. Retry after resolving concurrent edits.',
      );
    }
    _attempted = text;
    await files.write(yamlUri, Uint8List.fromList(utf8.encode(text)));
    if (await files.read(yamlUri) != text) {
      throw StateError(
        'YAML readback verification failed. Keep DevTools open and retry saving.',
      );
    }
    _expected = text;
    _attempted = null;
    saved = document;
  }
}
