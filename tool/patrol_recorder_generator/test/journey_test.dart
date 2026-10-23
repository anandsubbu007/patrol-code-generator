import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';
import 'package:patrol_recorder_generator/src/local_generation.dart';

final testApp = RecorderAppConfig(
  appImport: 'package:example/app.dart',
  appBuilder: 'createApp',
);

RecordedJourney recording({
  String state = 'stopped',
  bool more = false,
  String name = 'Login',
}) => RecordedJourney(
  id: 'login',
  name: name,
  caseId: 'sign_in',
  profile: 'demo',
  state: state,
  steps: [
    RecordedStep(
      id: 'step_0001',
      action: RecordedAction.enterText,
      target: RecorderTarget(key: 'user_name'),
      input: 'user_name',
      source: ObservationSource.focusedController,
    ),
    RecordedStep(
      id: 'step_0002',
      action: RecordedAction.enterText,
      target: RecorderTarget(key: 'password'),
      input: 'password',
      secret: true,
      source: ObservationSource.focusedController,
    ),
    RecordedStep(
      id: 'step_0003',
      action: RecordedAction.tap,
      target: RecorderTarget(key: 'login'),
    ),
    if (more)
      RecordedStep(
        id: 'step_0004',
        action: RecordedAction.enterText,
        target: RecorderTarget(key: 'note'),
        input: 'note',
      ),
  ],
);

void main() {
  test(
    'generated expectations compile and execute with Flutter and Patrol',
    () async {
      final project = Directory(
        Platform.environment['PATROL_RECORDER_TEST_EXAMPLE'] ?? '../../example',
      ).absolute;
      final temporary = await Directory('${project.path}/.dart_tool')
          .createTemp('expectations_probe_');
      addTearDown(() => temporary.delete(recursive: true));
      final config = ExportConfig(journeyId: 'checks');
      final generated = generateJourney(
        steps: [
          RecordedStep(
            id: 'ready',
            action: RecordedAction.expect,
            target: RecorderTarget(key: 'status'),
            expectation: ExpectationSpec(kind: RecordedExpectation.exists),
          ),
          RecordedStep(
            id: 'tap_status',
            action: RecordedAction.tap,
            target: RecorderTarget(key: 'status'),
          ),
        ],
        app: RecorderAppConfig(
          appImport: 'package:patrol_recorder_example/app.dart',
          appBuilder: 'createApp',
        ),
        config: config,
      );
      await File('${temporary.path}/checks_inputs.g.dart')
          .writeAsString(generated.contract);
      final probe = File('${temporary.path}/expectations_test.dart');
      await probe.writeAsString(
        generated.steps +
            r'''
void main() {
  testWidgets('generated enabled checks support old and new semantics APIs', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr,
        child: Column(children: [
          Semantics(enabled: false, child: const Text('Disabled', key: ValueKey('disabled'))),
          Semantics(enabled: true, child: const Text('Enabled', key: ValueKey('enabled'))),
          const Text('No enabled state', key: ValueKey('unspecified')),
        ])));
      expect(_recorderEnabled(find.byKey(const ValueKey('disabled')).evaluate().single), isFalse);
      expect(_recorderEnabled(find.byKey(const ValueKey('enabled')).evaluate().single), isTrue);
      expect(_recorderEnabled(find.byKey(const ValueKey('unspecified')).evaluate().single), isTrue);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('bounded generated expectations', (tester) async {
    var ready = false;
    late StateSetter update;
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr,
      child: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return Column(children: [
          Text(ready ? 'Ready' : 'Loading', key: const ValueKey('status')),
          const Text('Repeated'), const Text('Repeated'),
          const Offstage(child: Text('Hidden', key: ValueKey('hidden'))),
        ]);
      })));
    final status = find.byKey(const ValueKey('status'));
    Future<void>.delayed(const Duration(milliseconds: 100), () => update(() => ready = true));
    await _recorderExpect(tester, status, 'text', 'Ready', const Duration(milliseconds: 300), 'delayed_text');
    await _recorderExpect(tester, status, 'exists', null, const Duration(milliseconds: 100), 'exists');
    await _recorderExpect(tester, status, 'visible', null, const Duration(milliseconds: 100), 'visible');
    await _recorderExpect(tester, find.text('Missing'), 'absent', null, const Duration(milliseconds: 100), 'absent');
    await _recorderExpect(tester, find.text('Repeated'), 'count', 2, const Duration(milliseconds: 100), 'count');
    await _recorderExpect(tester, find.text('Missing'), 'count', 0, const Duration(milliseconds: 100), 'zero');
    for (final scenario in <(Finder, String, Object?)>[
      (find.text('Repeated'), 'exists', null),
      (find.byKey(const ValueKey('hidden'), skipOffstage: false), 'visible', null),
      (status, 'text', 'Wrong'), (status, 'absent', null),
    ]) {
      await expectLater(() => _recorderExpect(tester, scenario.$1, scenario.$2, scenario.$3,
        const Duration(milliseconds: 100), 'failed_step'),
        throwsA(isA<TestFailure>().having((error) => error.message, 'step context', contains('failed_step'))));
    }
  });
}
''',
      );
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      final result = await Process.run(
        flutterRoot == null ? 'flutter' : '$flutterRoot/bin/flutter',
        ['test', probe.path, '--reporter', 'expanded'],
        workingDirectory: project.path,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  test('all expectation forms roundtrip and generate bounded assertions', () {
    for (final kind in RecordedExpectation.values) {
      final step = RecordedStep(
        id: 'expected_result',
        action: RecordedAction.expect,
        source: ObservationSource.authored,
        target: RecorderTarget(key: 'result'),
        expectation: ExpectationSpec(
          kind: kind,
          value: switch (kind) {
            RecordedExpectation.text => r'Ready "$value"',
            RecordedExpectation.count => 0,
            _ => null,
          },
          timeoutMs: 250,
        ),
      );
      final flow = RecordedJourney(
        id: 'checks',
        name: 'Checks',
        caseId: 'ready',
        profile: 'demo',
        state: 'stopped',
        steps: [step],
      );
      final parsed = RecordedJourney.fromYaml(flow.toYaml());
      expect(
        parsed.steps.single.expectation!.toJson(),
        step.expectation!.toJson(),
      );
      final output = parsed.generate(ExportConfig(), app: testApp);
      expect(output.steps, contains('_recorderExpect'));
      expect(output.steps, contains('milliseconds: 250'));
      expect(output.steps, contains('pumped >= timeout'));
      expect(output.steps, isNot(contains('_recorderEnabled')));
      expect(output.steps, isNot(contains('waitUntilVisible')));
      expect(output.steps, contains('Matching widgets:'));
      expect(
        () => RecordedJourney.fromYaml(
          flow.toYaml().replaceFirst(
            'schema_version: $journeySchemaVersion',
            'schema_version: 3',
          ),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'invalid missing unsupported and misplaced expectations are rejected',
    () {
      for (final raw in <Map<String, dynamic>>[
        {},
        {'kind': 'unsupported'},
        {'kind': 'text'},
        {'kind': 'text', 'value': ''},
        {'kind': 'count', 'value': -1},
        {'kind': 'count', 'value': '2'},
        {'kind': 'visible', 'value': true},
        {'kind': 'exists', 'timeout_ms': 99},
        {'kind': 'exists', 'timeout_ms': 120001},
        {'kind': 'exists', 'timeout_ms': '1000'},
        {'kind': 'visible', 'unknown': true},
      ]) {
        expect(() => ExpectationSpec.fromJson(raw), throwsFormatException);
      }
      final raw = RecordedStep(
        id: 'check',
        action: RecordedAction.expect,
        target: RecorderTarget(key: 'result'),
        expectation: ExpectationSpec(kind: RecordedExpectation.exists),
      ).toJson();
      expect(
        () => RecordedStep.fromJson({...raw, 'expectation': null}),
        throwsFormatException,
      );
      expect(
        () => RecordedStep.fromJson({...raw, 'action': 'tap'}),
        throwsFormatException,
      );
      expect(
        () => RecordedStep.fromJson({
          ...raw,
          'target': RecorderTarget(issue: 'Missing').toJson(),
        }),
        throwsFormatException,
      );
      final flow = RecordedJourney(
        id: 'checks',
        name: 'Checks',
        caseId: 'ready',
        profile: 'demo',
        state: 'stopped',
        steps: [RecordedStep.fromJson(raw)],
      );
      expect(
        () => RecordedJourney.fromYaml(
          flow.toYaml().replaceFirst('kind: "exists"', 'kind: "unknown"'),
        ),
        throwsFormatException,
      );
      expect(
        () => RecordedJourney.fromYaml(
          flow.toYaml().replaceFirst('expectation:', 'unsupported:'),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'new interactions roundtrip and emit bounded native Patrol/Flutter APIs',
    () {
      final flow = RecordedJourney(
        id: 'async_flow',
        name: 'Async flow',
        caseId: 'ready',
        profile: 'demo',
        state: 'stopped',
        steps: [
          RecordedStep(
            id: 'step_0001',
            action: RecordedAction.tapText,
            target: RecorderTarget(key: 'legal'),
            text: 'Terms',
          ),
          RecordedStep(
            id: 'step_0002',
            action: RecordedAction.scrollUntilVisible,
            target: RecorderTarget(key: 'item_40'),
            scrollView: RecorderTarget(key: 'items'),
            scrollDirection: RecordedScrollDirection.down,
            source: ObservationSource.scrollNotification,
          ),
          RecordedStep(
            id: 'step_0003',
            action: RecordedAction.longPress,
            target: RecorderTarget(key: 'hold'),
          ),
        ],
      );
      final parsed = RecordedJourney.fromYaml(flow.toYaml());
      expect(parsed.steps[1].scrollView!.key, 'items');
      expect(parsed.steps.first.text, 'Terms');
      final output = parsed.generate(
        ExportConfig(waitTimeoutMs: 25000, maxScrolls: 80),
        app: testApp,
      );
      expect(output.steps, contains('find.textRange.ofSubstring'));
      expect(output.steps, contains('tapOnText'));
      expect(output.steps, contains('scrollUntilVisible'));
      expect(output.steps, contains('maxScrolls: 80'));
      expect(output.steps, contains('milliseconds: 25000'));
      expect(output.steps, contains('SettlePolicy.noSettle'));
      expect(output.steps, contains('_recorderEnabled'));
      expect(
        output.steps,
        contains('hasFlag(ui.SemanticsFlag.hasEnabledState)'),
      );
      expect(output.steps, isNot(contains('flagsCollection')));
      expect(output.steps, isNot(contains('ui.Tristate')));
      expect(output.steps, isNot(contains('pumpAndSettle')));
      expect(output.steps, isNot(contains('tapAt')));
      expect(output.steps, contains('ValueKey'));
      expect(output.steps, contains('Failure type:'));
    },
  );

  test('invalid async wait settings fail with usable messages', () {
    expect(() => ExportConfig(waitTimeoutMs: 0), throwsFormatException);
    expect(() => ExportConfig(maxScrolls: 201), throwsFormatException);
    expect(
      () => ExportConfig.fromPubspec(
        'name: example\nrecorder_config:\n  max_scrolls: many',
      ),
      throwsFormatException,
    );
    final config = ExportConfig.fromPubspec(
      'name: example\nrecorder_config:\n  wait_timeout_ms: 20000\n  max_scrolls: 75',
    );
    expect(config.waitTimeoutMs, 20000);
    expect(config.maxScrolls, 75);
  });

  test(
    'legacy YAML can be read, but new serialization drops app and session IDs',
    () {
      final current = recording().toYaml();
      final legacy = current
          .replaceFirst(
            'schema_version: $journeySchemaVersion',
            'schema_version: 1',
          )
          .replaceFirst('state: "stopped"', '''
state: "stopped"
session_id: "session_123"
app:
  import: "package:example/app.dart"
  builder: "createApp"''');
      final parsed = RecordedJourney.fromYaml(legacy);
      expect(parsed.legacyApp?.appBuilder, 'createApp');
      expect(parsed.toYaml(), current);
      expect(
        () => RecordedJourney.fromYaml('$current\nsession_id: "session_123"\n'),
        throwsFormatException,
      );
    },
  );

  test('main is inferred and a custom builder is configured once in pubspec', () async {
    final temp = await Directory.systemTemp.createTemp('patrol_bootstrap_');
    addTearDown(() => temp.delete(recursive: true));
    final root = Directory(await temp.resolveSymbolicLinks()).uri;
    final files = LocalWorkspaceFiles(root);
    await Directory('${temp.path}/lib').create();
    await File('${temp.path}/lib/main.dart')
        .writeAsString('Future<void> main() async {}');
    final inferred = await resolveAppBootstrap(
      files,
      root,
      'name: example',
      ExportConfig(),
    );
    expect(inferred.appImport, 'package:example/main.dart');
    expect(inferred.appBuilder, 'main');
    final output = recording().generate(ExportConfig(), app: inferred);
    expect(output.steps, contains('Future<void>.sync(app.main)'));
    expect(output.steps, isNot(contains('app.createApp')));
    await File('${temp.path}/lib/main.dart')
        .writeAsString('void main(List<String> args) {}');
    await expectLater(
      resolveAppBootstrap(files, root, 'name: example', ExportConfig()),
      throwsStateError,
    );
    await File('${temp.path}/lib/fixture.dart')
        .writeAsString('Object createApp() => Object();');
    const pubspec =
        'name: example\nrecorder_config:\n  app_import: package:example/fixture.dart\n  app_builder: createApp';
    final explicit = await resolveAppBootstrap(
      files,
      root,
      pubspec,
      ExportConfig.fromPubspec(pubspec),
    );
    expect(explicit.appBuilder, 'createApp');
    expect(explicit.appImport, 'package:example/fixture.dart');
  });

  test('YAML uses quoted dynamic references and no captured defaults', () {
    final yaml = recording(name: 'Login: "test"').toYaml();
    expect(yaml, contains('input: "{{user_name}}"'));
    expect(yaml, contains('input: "{{password}}"'));
    expect(yaml, isNot(contains('NOT_FOR_YAML')));
    final parsed = RecordedJourney.fromYaml(yaml);
    expect(parsed.toYaml(), yaml);
    expect(parsed.steps.first.input, 'user_name');
    expect(parsed.steps[1].secret, isTrue);
    expect(yaml, isNot(contains('session_id:')));
    expect(yaml, isNot(contains('\napp:')));
    final output = parsed.generate(ExportConfig(), app: testApp);
    expect(output.contract, contains('String get inputUserName;'));
    expect(output.data, contains('Connect inputUserName'));
    expect(output.data, isNot(contains('NOT_FOR_YAML')));
    expect(output.steps, contains('inputs.inputUserName'));
    expect(output.test, contains('runRecordedJourney'));
  });

  test('literal values, unknown selectors, versions, and paths are rejected', () {
    final yaml = recording().toYaml();
    for (final bad in [
      yaml.replaceFirst('"{{user_name}}"', '"actual user data"'),
      yaml.replaceFirst(
        'schema_version: $journeySchemaVersion',
        'schema_version: 99',
      ),
      yaml.replaceFirst(
        'schema_version: $journeySchemaVersion',
        'schema_version: 4.0',
      ),
      yaml.replaceFirst('key: "user_name"', 'coordinates: "user_name"'),
      '$yaml'
          'unexpected: true\n',
    ]) {
      expect(() => RecordedJourney.fromYaml(bad), throwsFormatException);
    }
    expect(
      () => ExportConfig.fromPubspec(
        'name: example\nrecorder_config:\n  screenshots_directory: ../outside',
      ),
      throwsFormatException,
    );
    expect(() => recording(name: 'Bad\nname'), throwsFormatException);
  });

  test(
    'recording and included unsupported steps cannot produce runnable code',
    () {
      expect(
        () =>
            recording(state: 'recording')
                .generate(ExportConfig(), app: testApp),
        throwsStateError,
      );
      final source = recording();
      final unresolved = RecordedJourney(
        id: source.id,
        name: source.name,
        caseId: source.caseId,
        profile: source.profile,
        state: 'stopped',
        steps: [
          ...source.steps,
          RecordedStep(
            id: 'step_0004',
            action: RecordedAction.unsupported,
            target: RecorderTarget(issue: 'Unrecorded scroll'),
          ),
        ],
      );
      expect(
        () => unresolved.generate(ExportConfig(), app: testApp),
        throwsFormatException,
      );
      final reviewed = RecordedJourney(
        id: source.id,
        name: source.name,
        caseId: source.caseId,
        profile: source.profile,
        state: 'stopped',
        steps: unresolved.steps,
        excluded: {'step_0004'},
      );
      expect(RecordedJourney.fromYaml(reviewed.toYaml()).excluded, {
        'step_0004',
      });
      expect(
        reviewed.generate(ExportConfig(), app: testApp).steps,
        isNot(contains('target4')),
      );
    },
  );

  test(
    'CLI generation regenerates contracts/steps and preserves manual providers',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'patrol_yaml_generation_',
      );
      addTearDown(() => temp.delete(recursive: true));
      await File('${temp.path}/pubspec.yaml').writeAsString('name: example');
      await Directory('${temp.path}/lib').create();
      await File('${temp.path}/lib/main.dart').writeAsString('void main() {}');
      final source = File('${temp.path}/patrol_recorder/login.yml');
      await source.parent.create();
      await source.writeAsString(recording().toYaml());
      final first = await generateProject(temp);
      expect(first.result.written.length, 4);
      final provider = File.fromUri(
        first.root.resolve(first.journeys.single.config.inputsPath),
      );
      await provider.writeAsString('// MY MANUAL PROVIDER');
      final test = File.fromUri(
        first.root.resolve(first.journeys.single.config.testPath),
      );
      await test.writeAsString('// MY MANUAL ASSERTIONS');
      await source.writeAsString(
        recording(more: true, name: 'Updated flow').toYaml(),
      );
      final second = await generateProject(temp, journey: 'login');
      expect(second.result.written.length, 2);
      expect(second.result.preserved.length, 2);
      expect(await provider.readAsString(), '// MY MANUAL PROVIDER');
      expect(await test.readAsString(), '// MY MANUAL ASSERTIONS');
      final contract = File.fromUri(
        second.root.resolve(second.journeys.single.config.contractPath),
      );
      expect(await contract.readAsString(), contains('inputNote'));
      final steps = File.fromUri(
        second.root.resolve(second.journeys.single.config.stepsPath),
      );
      expect(await steps.readAsString(), contains('Updated flow'));
      expect(
        await source.readAsString(),
        recording(more: true, name: 'Updated flow').toYaml(),
      );
    },
  );

  test(
    'batch validation fails before writing and symlinked paths are refused',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'patrol_yaml_validation_',
      );
      addTearDown(() => temp.delete(recursive: true));
      await File('${temp.path}/pubspec.yaml').writeAsString('name: example');
      await Directory('${temp.path}/lib').create();
      await File('${temp.path}/lib/main.dart').writeAsString('void main() {}');
      await Directory('${temp.path}/patrol_recorder').create();
      await File('${temp.path}/patrol_recorder/login.yml')
          .writeAsString(recording(state: 'recording').toYaml());
      await expectLater(generateProject(temp), throwsStateError);
      expect(await Directory('${temp.path}/patrol_test').exists(), isFalse);
      await expectLater(
        generateProject(temp, journey: '../outside'),
        throwsFormatException,
      );
      if (!Platform.isWindows) {
        final destination = Directory('${temp.path}/outside');
        await destination.create();
        await Link('${temp.path}/patrol_test').create(destination.path);
        await File('${temp.path}/patrol_recorder/login.yml')
            .writeAsString(recording().toYaml());
        await expectLater(
          generateProject(temp),
          throwsA(isA<FileSystemException>()),
        );
      }
    },
  );
}
