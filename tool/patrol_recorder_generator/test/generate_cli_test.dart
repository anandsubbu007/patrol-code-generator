import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';

void main() {
  test('the development package exposes the generation CLI', () async {
    final result = await Process.run('dart', [
      'run',
      'patrol_recorder_generator:generate',
      '--help',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      result.stdout,
      contains('dart run patrol_recorder_generator:generate'),
    );
    expect(result.stdout, contains('--journey'));
    expect(result.stdout, contains('--recordings-directory'));
    expect(result.stdout, isNot(contains('dart run patrol_recorder:generate')));
  });

  test(
    'the generator CLI reports invalid arguments with a failing exit',
    () async {
      final result = await Process.run('dart', [
        'run',
        'patrol_recorder_generator:generate',
        '--unknown-option',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Generation failed:'));
      expect(result.stdout, isNot(contains('Generated:')));
    },
  );

  group('journey validation diagnostics', () {
    late Directory project;

    String recording(String id, {bool missingScreenshots = false}) =>
        RecordedJourney(
          id: id,
          name: 'Test journey',
          caseId: 'test_case',
          profile: 'demo',
          state: 'stopped',
          steps: [
            RecordedStep(
              id: 'step_0001',
              action: RecordedAction.tap,
              target: RecorderTarget(key: 'login'),
            ),
          ],
          screenshots: [
            if (missingScreenshots)
              for (final name in ['login_page', 'account_overview'])
                JourneyCapture(
                  name: name,
                  path: 'artifacts/$id/$name.png',
                  width: 100,
                  height: 100,
                  redactedRegions: 0,
                ),
          ],
        ).toYaml();

    Future<ProcessResult> generate([String? journey]) => Process.run('dart', [
      'run',
      'patrol_recorder_generator:generate',
      '--project',
      project.path,
      '--recordings-directory',
      'custom_recordings',
      if (journey != null) ...['--journey', journey],
    ]);

    setUp(() async {
      project = await Directory.systemTemp.createTemp('patrol_cli_validation_');
      await File('${project.path}/pubspec.yaml')
          .writeAsString('name: example\n');
      await Directory('${project.path}/lib').create();
      await File('${project.path}/lib/main.dart')
          .writeAsString('void main() {}');
      await Directory('${project.path}/custom_recordings').create();
      for (final id in ['login_demo', 'old_login', 'yaml_login']) {
        await File(
          '${project.path}/custom_recordings/$id.yml',
        ).writeAsString(recording(id, missingScreenshots: id != 'login_demo'));
      }
    });

    tearDown(() => project.delete(recursive: true));

    test(
      'batch failure lists all missing captures and a valid selection',
      () async {
        final result = await generate();

        expect(result.exitCode, 1);
        expect(result.stderr, contains('Batch validation checks every .yml'));
        expect(result.stderr, contains('custom_recordings/ (3 selected)'));
        for (final id in ['old_login', 'yaml_login']) {
          expect(
            result.stderr,
            contains('$id.yml: Missing recorded screenshots:'),
          );
          expect(result.stderr, contains('artifacts/$id/login_page.png'));
          expect(result.stderr, contains('artifacts/$id/account_overview.png'));
          expect(result.stderr, contains('re-record "$id" in DevTools'));
        }
        expect(result.stderr, contains('relative to the app project:'));
        expect(result.stderr, contains(await project.resolveSymbolicLinks()));
        expect(result.stderr, contains('No output files were written'));
        expect(result.stderr, contains('blocks the entire batch'));
        expect(result.stderr, contains('Valid journeys: login_demo'));
        expect(
          result.stderr,
          contains('--journey login_demo to your original command'),
        );
        expect(result.stdout, isNot(contains('Generated:')));
        expect(
          await Directory('${project.path}/patrol_test').exists(),
          isFalse,
        );
      },
    );

    test(
      'selecting a valid journey ignores unrelated invalid recordings',
      () async {
        final result = await generate('login_demo');

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stderr, isEmpty);
        expect(result.stdout, contains('Generated:'));
        final outputs = Directory(
          '${project.path}/patrol_test/recorded_journeys/login_demo',
        );
        expect(await outputs.list().length, 4);
        for (final id in ['old_login', 'yaml_login']) {
          expect(
            await Directory('${outputs.parent.path}/$id').exists(),
            isFalse,
          );
        }
      },
    );

    test(
      'selecting an invalid journey still validates all its captures',
      () async {
        final result = await generate('yaml_login');

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains('only the selected journey "yaml_login"'),
        );
        expect(result.stderr, contains('artifacts/yaml_login/login_page.png'));
        expect(
          result.stderr,
          contains('artifacts/yaml_login/account_overview.png'),
        );
        expect(result.stderr, isNot(contains('old_login.yml:')));
        expect(result.stderr, isNot(contains('Valid journeys:')));
        expect(result.stderr, contains('No output files were written'));
        expect(
          await Directory('${project.path}/patrol_test').exists(),
          isFalse,
        );
      },
    );

    test(
      'invalid YAML is reported without unrelated selector advice',
      () async {
        await File('${project.path}/custom_recordings/login_demo.yml')
            .writeAsString('not: [valid YAML');

        final result = await generate();

        expect(result.exitCode, 1);
        expect(result.stderr, contains('login_demo.yml:'));
        expect(result.stderr, contains('old_login.yml:'));
        expect(result.stderr, contains('yaml_login.yml:'));
        expect(result.stderr, isNot(contains('Valid journeys:')));
        expect(
          result.stderr,
          isNot(contains('fix its identified widget keys')),
        );
        expect(
          await Directory('${project.path}/patrol_test').exists(),
          isFalse,
        );
      },
    );

    test('failed batch leaves existing generated files unchanged', () async {
      final selected = await generate('login_demo');
      expect(selected.exitCode, 0, reason: '${selected.stderr}');
      final outputs = Directory(
        '${project.path}/patrol_test/recorded_journeys/login_demo',
      );
      final originals = <String, String>{};
      await for (final file in outputs.list()) {
        originals[file.path] = await File(file.path).readAsString();
      }
      final source = File('${project.path}/custom_recordings/login_demo.yml');
      await source.writeAsString(
        (await source.readAsString()).replaceFirst(
          'Test journey',
          'Updated flow',
        ),
      );

      final batch = await generate();

      expect(batch.exitCode, 1);
      expect(batch.stderr, contains('No output files were written'));
      for (final entry in originals.entries) {
        expect(await File(entry.key).readAsString(), entry.value);
      }
    });
  });
}
