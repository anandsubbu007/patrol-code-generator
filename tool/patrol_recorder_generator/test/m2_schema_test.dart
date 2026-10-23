import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';
import 'package:patrol_recorder_generator/src/local_generation.dart';

const document = '''
schema_version: 5
journey: {id: authored, name: Authored cases}
state: stopped
assets:
  customer: {path: assets/customer.json, format: json}
  message: {path: assets/message.txt, format: text}
inputs:
  email: {type: string}
  attempts: {type: integer}
  ratio: {type: number}
  enabled: {type: boolean}
  metadata: {type: json}
  password: {type: string, secret: true}
profiles:
  demo: {email: demo@example.invalid, attempts: 2, ratio: 0.5, enabled: true, metadata: {role: tester}}
setup:
  fixtures:
    - {id: seed, action: asset, asset: customer}
groups:
  login:
    - {id: email, action: enterText, target: {key: email}, input: '{{email}}', secret: false}
    - {id: submit, action: tap, target: {key: old_submit}}
cases:
  - id: happy
    name: Happy path
    profile: demo
    setup: [fixtures]
    data: {attempts: 3}
    selector_overrides:
      login_submit: {key: login, within: {key: form}}
    steps:
      - {id: login, action: group, group: login}
      - {id: title, action: expect, target: {key: title}, expectation: {kind: text, value: Ready, timeout_ms: 250}}
      - {id: text_fixture, action: asset, asset: message}
  - id: missing
    name: Empty state
    profile: demo
    steps:
      - {id: empty, action: expect, target: {key: missing}, expectation: {kind: absent}}
''';

Future<Directory> project() async {
  final directory = await Directory.systemTemp.createTemp('recorder_m2_');
  addTearDown(() => directory.delete(recursive: true));
  await File('${directory.path}/pubspec.yaml').writeAsString('name: example');
  await Directory('${directory.path}/lib').create();
  await File('${directory.path}/lib/main.dart').writeAsString('void main() {}');
  await Directory('${directory.path}/patrol_recorder/assets')
      .create(recursive: true);
  await File('${directory.path}/patrol_recorder/authored.yml')
      .writeAsString(document);
  await File('${directory.path}/patrol_recorder/assets/customer.json')
      .writeAsString(r'{"name":"Fixture $safe"}');
  await File('${directory.path}/patrol_recorder/assets/message.txt')
      .writeAsString('Test fixture');
  return directory;
}

void main() {
  test(
    'typed JSON keys and values roundtrip without YAML reinterpretation',
    () {
      final value = <String, Object?>{
        'true': 'text',
        'a: b': 2,
        'line\nbreak': [
          'text',
          {'null': null},
        ],
        'off': true,
      };
      final journey = RecordedJourney(
        id: 'json_keys',
        name: 'JSON keys',
        caseId: 'keys',
        profile: 'demo',
        state: 'stopped',
        inputs: {'metadata': JourneyInput(type: JourneyInputType.json)},
        profiles: {
          'demo': {'metadata': value},
        },
        steps: [
          RecordedStep(
            id: 'ready',
            action: RecordedAction.expect,
            target: RecorderTarget(key: 'ready'),
            expectation: ExpectationSpec(kind: RecordedExpectation.exists),
          ),
        ],
      );
      expect(
        RecordedJourney.fromYaml(journey.toYaml())
            .profiles['demo']!['metadata'],
        value,
      );
      expect(
        () =>
            (journey.profiles['demo']!['metadata'] as Map)['true'] = 'changed',
        throwsUnsupportedError,
      );
    },
  );

  test(
    'generated typed inputs and fixture helpers compile and execute',
    () async {
      final directory = Directory(
        Platform.environment['PATROL_RECORDER_TEST_EXAMPLE'] ?? '../../example',
      ).absolute;
      final temporary = await Directory('${directory.path}/.dart_tool')
          .createTemp('m2_probe_');
      addTearDown(() => temporary.delete(recursive: true));
      final journey = RecordedJourney.fromYaml(document);
      final output = journey.generate(
        ExportConfig(),
        app: RecorderAppConfig(
          appImport: 'package:patrol_recorder_example/app.dart',
          appBuilder: 'createApp',
        ),
        selectedCase: 'happy',
        assetValues: {
          'customer': {'name': 'Fixture'},
          'message': 'Fixture text',
        },
      );
      await File('${temporary.path}/happy_inputs.g.dart')
          .writeAsString(output.contract);
      await File('${temporary.path}/happy_inputs.dart')
          .writeAsString(output.data);
      final probe = File('${temporary.path}/fixtures_test.dart');
      await probe.writeAsString(
        "import 'happy_inputs.dart';\n${output.steps}"
        r'''
class FixtureInputs extends LocalJourneyInputs {
  FixtureInputs() : super('demo');
  final applied = <String>[];
  @override
  Future<void> applyAsset(String name, Object value) async {
    applied.add(name);
  }
}

void main() {
  test('typed defaults and explicit fixture adapter', () async {
    final inputs = FixtureInputs();
    expect(recordedJourneyName, 'Happy path');
    expect(inputs.inputEmail, 'demo@example.invalid');
    expect(inputs.inputAttempts, 3);
    expect(inputs.inputRatio, 0.5);
    expect(inputs.inputEnabled, true);
    expect(inputs.inputMetadata, {'role': 'tester'});
    await _recorderAsset(inputs, 'customer', {'name': 'Fixture'}, const Duration(milliseconds: 100), 'seed');
    await _recorderAsset(inputs, 'message', 'Fixture text', const Duration(milliseconds: 100), 'text');
    expect(inputs.applied, ['customer', 'message']);
    await expectLater(_recorderAsset(const LocalJourneyInputs('demo'), 'customer', {},
      const Duration(milliseconds: 100), 'unwired_seed'),
      throwsA(isA<StateError>().having((error) => error.message, 'step context', contains('unwired_seed'))));
  });
}
''',
      );
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      final result = await Process.run(
        flutterRoot == null ? 'flutter' : '$flutterRoot/bin/flutter',
        ['test', probe.path, '--reporter', 'expanded'],
        workingDirectory: directory.path,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  test('CLI preview and selector inspection are read-only and share generation errors', () async {
    final directory = await project();
    for (final option in ['--preview', '--inspect-selectors']) {
      final result = await Process.run('dart', [
        'run',
        'patrol_recorder_generator:generate',
        '--project',
        directory.path,
        '--journey',
        'authored',
        '--case',
        'happy',
        option,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(
        result.stdout,
        contains(option == '--preview' ? '_recorderAsset' : 'login_submit'),
      );
      expect(await Directory('${directory.path}/patrol_test').exists(), false);
    }
    await File('${directory.path}/patrol_recorder/assets/customer.json')
        .delete();
    final failure = await Process.run('dart', [
      'run',
      'patrol_recorder_generator:generate',
      '--project',
      directory.path,
      '--journey',
      'authored',
      '--preview',
    ]);
    expect(failure.exitCode, 1);
    expect(failure.stderr, contains('missing asset customer'));
  });

  test(
    'schema v5 roundtrips cases setup groups typed data and selector overrides',
    () {
      final journey = RecordedJourney.fromYaml(document);
      expect(
        RecordedJourney.fromYaml(journey.toYaml()).toYaml(),
        journey.toYaml(),
      );
      final steps = journey.expandedSteps(journey.cases.first);
      expect(steps.map((step) => step.id), [
        'setup_fixtures_seed',
        'login_email',
        'login_submit',
        'title',
        'text_fixture',
      ]);
      expect(steps.first, isA<AssetStep>());
      expect(steps[2].target.key, 'login');
      expect(steps[2].target.scope!.value, 'form');
      expect(
        journey
            .inspectSelectors(selectedCase: 'happy')
            .singleWhere((row) => row['id'] == 'login_submit')['overridden'],
        true,
      );
      expect(journey.cases.first.data['attempts'], 3);
      final app = RecorderAppConfig(
        appImport: 'package:example/main.dart',
        appBuilder: 'main',
      );
      expect(
        () => journey.generate(ExportConfig(), app: app),
        throwsStateError,
      );
      expect(
        () => journey.generateCases(ExportConfig(), app: app),
        throwsFormatException,
      );
    },
  );

  test('assets are validated embedded and adapter calls remain ordered and bounded', () async {
    final directory = await project();
    final result = await generateProject(directory);
    expect(result.journeys, hasLength(2));
    final output = result.journeys.first;
    expect(
      output.config.directory,
      'patrol_test/recorded_journeys/authored/cases/happy',
    );
    expect(output.contract, contains('int get inputAttempts;'));
    expect(output.contract, contains('double get inputRatio;'));
    expect(output.contract, contains('bool get inputEnabled;'));
    expect(output.contract, contains('Object get inputMetadata;'));
    expect(output.contract, contains('applyAsset'));
    expect(output.data, contains('=> 3'));
    expect(output.data, contains('RECORDER_SECRET_PASSWORD'));
    expect(
      output.steps.indexOf('await _recorderAsset('),
      lessThan(output.steps.indexOf('inputs.inputEmail')),
    );
    expect(output.steps, contains(r'Fixture \$safe'));
    expect(output.steps, contains('.timeout('));
    expect(output.steps, isNot(contains('File(')));
    expect(output.needsImplementation, true);
    final provider = File.fromUri(
      result.root.resolve(output.config.inputsPath),
    );
    await provider.writeAsString('// retained fixture adapter');
    final repeated = await generateProject(
      directory,
      journey: 'authored',
      selectedCase: 'happy',
    );
    expect(repeated.journeys, hasLength(1));
    expect(await provider.readAsString(), '// retained fixture adapter');
  });

  test('preview validates without writing and supports selected cases and custom recording roots', () async {
    final directory = await project();
    await Directory('${directory.path}/patrol_recorder')
        .rename('${directory.path}/journeys');
    final result = await generateProject(
      directory,
      journey: 'authored',
      selectedCase: 'happy',
      recordingsDirectory: 'journeys',
      preview: true,
    );
    expect(result.journeys, hasLength(1));
    expect(result.result.written, isEmpty);
    expect(await Directory('${directory.path}/patrol_test').exists(), false);
    await expectLater(
      generateProject(directory, selectedCase: 'happy'),
      throwsFormatException,
    );
    await expectLater(
      generateProject(
        directory,
        journey: 'authored',
        selectedCase: 'unknown',
        recordingsDirectory: 'journeys',
      ),
      throwsStateError,
    );
  });

  test('invalid incomplete unsupported and misplaced authored declarations fail with context', () {
    for (final source in [
      document.replaceFirst('format: json', 'format: binary'),
      document.replaceFirst('format: json', 'unsupported: json'),
      document.replaceFirst('path: assets/customer.json, ', ''),
      document.replaceFirst('asset: customer', 'asset: unknown'),
      document.replaceFirst('asset: customer', 'target: {key: customer}'),
      document.replaceFirst(
        'path: assets/customer.json',
        'path: ../outside.json',
      ),
      document.replaceFirst(
        'path: assets/customer.json',
        'path: /tmp/outside.json',
      ),
      document.replaceFirst(
        'path: assets/customer.json',
        'path: assets/../outside.json',
      ),
      document.replaceFirst(
        'path: assets/customer.json',
        'path: file:///tmp/outside',
      ),
      document.replaceFirst(
        'path: assets/customer.json',
        'path: assets/%2e%2e/outside',
      ),
      document.replaceFirst('type: integer', 'type: date'),
      document.replaceFirst('attempts: 3', 'attempts: wrong'),
      document.replaceFirst('data: {attempts: 3}', 'data: {password: secret}'),
      document.replaceFirst('profile: demo', 'profile: unknown'),
      document.replaceFirst('setup: [fixtures]', 'setup: [unknown]'),
      document.replaceFirst('group: login}', 'group: unknown}'),
      document.replaceFirst('login_submit:', 'unknown_step:'),
      document.replaceFirst('id: missing\n', 'id: happy\n'),
      document.replaceFirst('kind: text, value: Ready', 'kind: text'),
      document.replaceFirst('kind: text', 'kind: unsupported'),
      document.replaceFirst('action: expect', 'action: asset'),
      document.replaceFirst('id: title,', 'id: login,'),
    ]) {
      expect(
        () => RecordedJourney.fromYaml(source),
        throwsFormatException,
        reason: source,
      );
    }
    expect(
      () => RecordedJourney.fromYaml(
        document.replaceFirst('kind: text', 'kind: unknown'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'step context',
          contains('case happy/title'),
        ),
      ),
    );
  });

  test(
    'cycles duplicate expanded IDs and excessive expansions fail safely',
    () {
      expect(
        () => RecordedJourney.fromYaml(
          document.replaceFirst(
            '- {id: submit, action: tap, target: {key: old_submit}}',
            '- {id: recurse, action: group, group: login}',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RecordedJourney.fromYaml(
          document.replaceFirst(
            'setup: [fixtures]',
            'setup: [fixtures, fixtures]',
          ),
        ),
        throwsFormatException,
      );
      final repeated = RecordedJourney(
        id: 'bounded',
        name: 'Bounded',
        caseId: 'default_case',
        profile: 'demo',
        state: 'stopped',
        steps: [],
        groups: {
          'many': [
            for (var index = 0; index < 250; index++)
              RecordedStep(
                id: 'item_$index',
                action: RecordedAction.tap,
                target: RecorderTarget(key: 'button'),
              ),
          ],
        },
        cases: [
          JourneyCase(
            id: 'many',
            name: 'Many',
            profile: 'demo',
            steps: [GroupStep(id: 'first', group: 'many')],
          ),
        ],
      );
      expect(repeated.expandedSteps(repeated.cases.single), hasLength(250));
      expect(
        () => RecordedJourney(
          id: 'bounded',
          name: 'Bounded',
          caseId: 'default_case',
          profile: 'demo',
          state: 'stopped',
          steps: [],
          groups: repeated.groups,
          cases: [
            JourneyCase(
              id: 'many',
              name: 'Many',
              profile: 'demo',
              steps: [
                GroupStep(id: 'first', group: 'many'),
                GroupStep(id: 'second', group: 'many'),
              ],
            ),
          ],
        ),
        throwsFormatException,
      );
    },
  );

  test('missing corrupt oversized and symlink assets block generation before writes', () async {
    final directory = await project();
    final fixture = File(
      '${directory.path}/patrol_recorder/assets/customer.json',
    );
    for (final source in ['{', 'null', 'x' * (1024 * 1024 + 1)]) {
      await fixture.writeAsString(source);
      await expectLater(generateProject(directory), throwsStateError);
      expect(await Directory('${directory.path}/patrol_test').exists(), false);
    }
    await fixture.delete();
    await expectLater(generateProject(directory), throwsStateError);
    if (!Platform.isWindows) {
      final outside = File('${directory.path}/outside.json');
      await outside.writeAsString(jsonEncode({'outside': true}));
      await Link(fixture.path).create(outside.path);
      await expectLater(
        generateProject(directory, preview: true),
        throwsStateError,
      );
    }
    expect(await Directory('${directory.path}/patrol_test').exists(), false);
  });
}
