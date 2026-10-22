import 'dart:io';

import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';

import '../../../example/patrol_test/demo_profiles.dart';

Future<void> main() async {
  final root = Directory('../../example');
  final app = RecorderAppConfig(
    appImport: 'package:patrol_recorder_example/app.dart',
    appBuilder: 'createApp',
    safeProfiles: demoProfiles,
  );
  final login = [
    RecordedStep(
      id: 'step_0001',
      action: RecordedAction.enterText,
      target: RecorderTarget(key: 'email'),
      input: 'email',
    ),
    RecordedStep(
      id: 'step_0002',
      action: RecordedAction.enterText,
      target: RecorderTarget(key: 'note'),
      input: 'note',
    ),
    RecordedStep(
      id: 'step_0003',
      action: RecordedAction.tap,
      target: RecorderTarget(key: 'login', semanticsIdentifier: 'demo.login'),
    ),
  ];
  for (final config in [
    ExportConfig(),
    ExportConfig(
      journeyId: 'accounts',
      caseId: 'open_settings',
      caseName: 'Open account settings',
    ),
  ]) {
    final output = generateJourney(
      steps: [
        ...login,
        if (config.journeyId == 'accounts')
          RecordedStep(
            id: 'step_0004',
            action: RecordedAction.tap,
            target: RecorderTarget(key: 'settings'),
          ),
      ],
      app: app,
      config: config,
    );
    for (final entry in output.files().entries) {
      final file = File.fromUri(root.absolute.uri.resolve(entry.key));
      if (await file.exists()) {
        throw StateError('Refusing to overwrite ${entry.key}.');
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value);
      stdout.writeln('Created ${entry.key}');
    }
  }
}
