import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';
import 'package:patrol_recorder_generator/src/local_generation.dart';

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

    Future<ProcessResult> generate([
      String? journey,
      String? input,
      List<String> options = const [],
    ]) async {
      final arguments = [
        'run',
        'patrol_recorder_generator:generate',
        '--project',
        project.path,
        '--recordings-directory',
        'custom_recordings',
        if (journey != null) ...['--journey', journey],
        if (input != null) '--interactive',
        ...options,
      ];
      if (input == null) return Process.run('dart', arguments);
      final process = await Process.start('dart', arguments);
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(input);
      await process.stdin.close();
      return ProcessResult(
        process.pid,
        await process.exitCode,
        await output,
        await errors,
      );
    }

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
      'menu selects a valid journey without validating stale ones',
      () async {
        final result = await generate(null, '1\n1\n');

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stdout, contains('Which journey?'));
        expect(result.stdout, contains('login_demo'));
        expect(result.stdout, contains('Generated:'));
        expect(result.stderr, isEmpty);
        expect(
          await Directory(
            '${project.path}/patrol_test/recorded_journeys/old_login',
          ).exists(),
          isFalse,
        );
      },
    );

    test(
      'failed interactive batch can recover by choosing a journey',
      () async {
        final result = await generate(null, '2\n1\n1\n');

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stderr, contains('No output files were written'));
        expect(result.stderr, contains('Choose another journey'));
        expect(result.stdout, contains('Generated:'));
      },
    );

    test('preview and selector inspection do not write files', () async {
      for (final action in [3, 4]) {
        final result = await generate(null, '$action\n1\n');

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          result.stdout,
          contains(action == 3 ? 'Preview:' : '"journey_id": "login_demo"'),
        );
        expect(
          await Directory('${project.path}/patrol_test').exists(),
          isFalse,
        );
      }
    });

    test('menu handles no recordings and cancelled or invalid input', () async {
      for (final file in await Directory(
        '${project.path}/custom_recordings',
      ).list().toList()) {
        await file.delete();
      }
      final result = await generate(null, 'invalid\n1\n6\n0\n');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('No .yml journeys found'));
      expect(result.stdout, contains('Invalid choice'));
      expect(result.stdout, contains('DevTools'));
      expect(result.stdout, contains('Cancelled'));
      expect(await Directory('${project.path}/patrol_test').exists(), isFalse);
    });

    test('menu also handles a missing recordings directory and EOF', () async {
      await Directory('${project.path}/custom_recordings')
          .delete(recursive: true);
      final result = await generate(null, '');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('No .yml journeys found'));
      expect(result.stdout, contains('Cancelled'));
    });

    test('reset requires the exact confirmation before deleting', () async {
      final result = await generate(null, '5\n3\nyes\n0\n');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('INCLUDING user-owned inputs and tests'));
      expect(result.stdout, contains('Type DELETE'));
      expect(result.stdout, contains('Reset cancelled'));
      expect(
        await Directory('${project.path}/custom_recordings').list().length,
        3,
      );
    });

    test('each reset scope deletes only its explicitly listed files', () async {
      for (final scope in [1, 2, 3]) {
        for (final id in ['login_demo', 'old_login', 'yaml_login']) {
          await File('${project.path}/custom_recordings/$id.yml')
              .writeAsString(recording(id, missingScreenshots: true));
          final folder = await Directory('${project.path}/artifacts/$id')
              .create(recursive: true);
          for (final name in ['login_page', 'account_overview']) {
            await File('${folder.path}/$name.png').writeAsBytes([1, 2, 3]);
          }
        }
        final generated = await generate('login_demo');
        expect(generated.exitCode, 0, reason: '${generated.stderr}');
        final output = Directory(
          '${project.path}/patrol_test/recorded_journeys/login_demo',
        );
        final unrelated = File('${output.path}/notes.txt');
        await unrelated.writeAsString('preserve me');
        final asset = File('${project.path}/custom_recordings/fixture.json');
        await asset.writeAsString('{}');
        final orphan = File('${project.path}/artifacts/login_demo/orphan.png');
        await orphan.writeAsBytes([4, 5]);

        final result = await generate(null, '5\n$scope\nDELETE\n0\n');

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          result.stdout,
          contains(
            'Deleted ${scope == 1
                ? 3
                : scope == 2
                ? 9
                : 13} files.',
          ),
        );
        expect(result.stdout, contains('No .yml journeys found'));
        expect(
          await File('${project.path}/custom_recordings/login_demo.yml')
              .exists(),
          isFalse,
        );
        expect(
          await File('${project.path}/artifacts/login_demo/login_page.png')
              .exists(),
          scope == 1,
        );
        for (final suffix in [
          'steps.g.dart',
          'inputs.g.dart',
          'inputs.dart',
          'test.dart',
        ]) {
          expect(
            await File('${output.path}/login_demo_$suffix').exists(),
            scope != 3,
          );
        }
        expect(await unrelated.readAsString(), 'preserve me');
        expect(await asset.exists(), isTrue);
        expect(await orphan.exists(), isTrue);
      }
    });

    test(
      'malformed YAML can be reset without guessing capture paths',
      () async {
        await File('${project.path}/custom_recordings/login_demo.yml')
            .writeAsString('not: [valid YAML');
        final result = await generate(null, '5\n2\n5\n1\nDELETE\n0\n');

        expect(result.exitCode, 1);
        expect(result.stderr, contains('Generation failed:'));
        expect(result.stdout, contains('Deleted 3 files'));
        expect(
          await File('${project.path}/custom_recordings/login_demo.yml')
              .exists(),
          isFalse,
        );
      },
    );

    test('reset refuses symlinked paths without deleting recordings', () async {
      final target = File('${project.path}/outside.png');
      await target.writeAsBytes([1]);
      await Directory('${project.path}/artifacts/old_login')
          .create(recursive: true);
      await Link('${project.path}/artifacts/old_login/login_page.png')
          .create(target.path);
      final result = await generate(null, '5\n2\n0\n');

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Symlinked generator paths'));
      expect(await target.exists(), isTrue);
      expect(
        await Directory('${project.path}/custom_recordings').list().length,
        3,
      );
    });

    test('reset rejects files changed after the plan was shown', () async {
      final catalog = await LocalRecordings.open(
        project,
        recordingsDirectory: 'custom_recordings',
      );
      final plan = await catalog.resetPlan(
        screenshots: false,
        generatedCode: false,
      );
      await File('${project.path}/custom_recordings/yaml_login.yml')
          .writeAsString('changed while confirming');

      await expectLater(
        catalog.deletePlanned(plan),
        throwsA(isA<StateError>()),
      );
      expect(
        await Directory('${project.path}/custom_recordings').list().length,
        3,
      );
    });

    test(
      'reset includes all cases under the configured output directory',
      () async {
        await File('${project.path}/pubspec.yaml').writeAsString('''
name: example
recorder_config:
  output_directory: generated/custom
''');
        final source = RecordedJourney(
          id: 'login_demo',
          name: 'Login cases',
          caseId: 'test_case',
          profile: 'demo',
          state: 'stopped',
          steps: [],
          cases: [
            for (final id in ['happy', 'empty'])
              JourneyCase(
                id: id,
                name: id,
                profile: 'demo',
                steps: [
                  RecordedStep(
                    id: 'tap',
                    action: RecordedAction.tap,
                    target: RecorderTarget(key: 'login'),
                  ),
                ],
              ),
          ],
        );
        await File('${project.path}/custom_recordings/login_demo.yml')
            .writeAsString(source.toYaml());
        final generated = await generateProject(
          project,
          journey: 'login_demo',
          recordingsDirectory: 'custom_recordings',
        );
        expect(generated.result.written, hasLength(8));
        final catalog = await LocalRecordings.open(
          project,
          recordingsDirectory: 'custom_recordings',
        );
        final plan = await catalog.resetPlan(
          screenshots: true,
          generatedCode: true,
        );
        expect(plan, hasLength(11));
        for (final path in generated.result.written) {
          expect(plan, contains(catalog.root.resolve(path)));
        }

        await catalog.deletePlanned(plan);

        for (final path in generated.result.written) {
          expect(
            await File.fromUri(catalog.root.resolve(path)).exists(),
            isFalse,
          );
        }
        expect(
          await File('${project.path}/lib/main.dart').readAsString(),
          'void main() {}',
        );
      },
    );

    test(
      'explicit journey bypasses the menu and incompatible options fail',
      () async {
        final selected = await generate('login_demo', '');
        expect(selected.exitCode, 0, reason: '${selected.stderr}');
        expect(selected.stdout, isNot(contains('What would you like to do?')));
        for (final options in [
          ['--all'],
          ['--case', 'test_case'],
        ]) {
          final result = await generate(
            options.first == '--all' ? 'login_demo' : null,
            '',
            options,
          );
          expect(result.exitCode, 1);
          expect(result.stderr, contains('Generation failed:'));
          expect(result.stdout, isNot(contains('What would you like to do?')));
        }
      },
    );

    test(
      '--all and --no-interactive retain unattended batch validation',
      () async {
        for (final options in [
          ['--all'],
          ['--no-interactive'],
        ]) {
          final result = await generate(null, '1\n1\n', options);

          expect(result.exitCode, 1);
          expect(result.stderr, contains('Batch validation checks every .yml'));
          expect(result.stdout, isNot(contains('What would you like to do?')));
        }
      },
    );

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
