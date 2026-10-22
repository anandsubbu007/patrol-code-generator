import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/file_export.dart';
import 'package:patrol_recorder_generator/generator.dart';

final app = RecorderAppConfig(
  appImport: 'package:example/app.dart',
  appBuilder: 'createApp',
  safeProfiles: const {
    'demo': {'email': 'demo@example.invalid'},
    'secondary': {'email': 'secondary@example.invalid'},
  },
);

List<RecordedStep> steps() => [
  RecordedStep(
    id: 'step_0001',
    action: RecordedAction.enterText,
    target: RecorderTarget(key: 'email'),
    input: 'email',
  ),
  RecordedStep(
    id: 'step_0002',
    action: RecordedAction.enterText,
    target: RecorderTarget(key: 'password'),
    input: 'password',
    secret: true,
  ),
  RecordedStep(
    id: 'step_0003',
    action: RecordedAction.tap,
    target: RecorderTarget(semanticsIdentifier: 'demo.login'),
  ),
];

class MemoryFiles implements WorkspaceFiles {
  MemoryFiles({this.dropWrites = false, this.corruptWrites = false});
  final bool dropWrites;
  final bool corruptWrites;
  final content = <Uri, Uint8List>{};
  @override
  Future<bool> exists(Uri uri) async => content.containsKey(uri);
  @override
  Future<String?> read(Uri uri) async =>
      content[uri] == null ? null : utf8.decode(content[uri]!);
  @override
  Future<void> write(Uri uri, Uint8List bytes) async {
    if (!dropWrites) {
      content[uri] = corruptWrites ? Uint8List.fromList([0]) : bytes;
    }
  }
}

void main() {
  test('new scaffolds document required wiring and Patrol execution', () {
    final output = generateJourney(
      steps: steps(),
      app: app,
      config: ExportConfig(
        journeyId: 'custom_login',
        outputDirectory: 'patrol_test/custom',
        profile: 'secondary',
      ),
      deferredInputs: {'email', 'password'},
    );
    expect(output.data, contains('TODO: Connect inputEmail'));
    expect(output.data, contains('TODO: Connect inputPassword'));
    expect(output.data, contains('never hardcode real secrets'));
    expect(output.data, contains('/// User-owned input implementation'));
    expect(output.data, contains('/// Loads test fixtures'));
    expect(output.test, contains('TODO: Complete required getters'));
    expect(output.test, contains('custom_login_inputs.dart before running'));
    expect(
      output.test,
      contains(
        'patrol test --target patrol_test/custom/custom_login/custom_login_test.dart '
        '--dart-define RECORDER_PROFILE=secondary',
      ),
    );
    expect(output.test, contains('application directory'));
    expect(output.test, contains("not the IDE's standard Run Test"));
    expect(output.test, contains('Do not edit or commit test_bundle.dart'));
    expect(output.test, contains('TODO: Add bounded waits and assertions'));
    expect(output.steps, contains('callers must assert'));

    final environmentSecret = generateJourney(
      steps: steps(),
      app: app,
      config: ExportConfig(),
    );
    expect(
      environmentSecret.data,
      contains('TODO: Supply RECORDER_SECRET_PASSWORD'),
    );
    expect(environmentSecret.test, contains('TODO: Complete required getters'));

    final noInputs = generateJourney(
      steps: [steps().last],
      app: app,
      config: ExportConfig(),
    );
    expect(noInputs.data, isNot(contains('TODO:')));
    expect(noInputs.test, isNot(contains('TODO: Complete required getters')));
    expect(noInputs.test, contains('TODO: Add bounded waits and assertions'));
  });

  test(
    'input validation accepts explicit provider wiring, never secret literals',
    () {
      final noDefaults = RecorderAppConfig(
        appImport: 'package:example/app.dart',
        appBuilder: 'createApp',
      );
      expect(
        () => generateJourney(
          steps: steps(),
          app: noDefaults,
          config: ExportConfig(),
        ),
        throwsFormatException,
      );
      final output = generateJourney(
        steps: steps(),
        app: noDefaults,
        config: ExportConfig(),
        deferredInputs: {'email'},
      );
      expect(output.needsImplementation, isTrue);
      expect(output.data, contains('Connect inputEmail'));
      expect(output.contract, contains('inputPassword'));
      expect(
        () => generateJourney(
          steps: steps(),
          app: app,
          config: ExportConfig(),
          inputValues: {'password': 'DO_NOT_EXPORT'},
        ),
        throwsFormatException,
      );
      final custom = generateJourney(
        steps: steps(),
        app: noDefaults,
        config: ExportConfig(profile: 'custom'),
        inputValues: {'email': 'custom@example.invalid'},
      );
      expect(custom.data, contains('custom@example.invalid'));
    },
  );

  test('regeneration changes only generated contracts and steps', () async {
    final memory = MemoryFiles();
    final root = Uri.parse('file:///workspace/');
    final first = generateJourney(
      steps: steps(),
      app: app,
      config: ExportConfig(),
    );
    await exportFiles(
      workspace: memory,
      projectRoot: root,
      files: first.files(),
      userOwnedPaths: first.userOwnedPaths,
    );
    final owned = Uint8List.fromList(
      utf8.encode('// my custom fixture provider'),
    );
    final ownedTest = Uint8List.fromList(
      utf8.encode('// my custom test and assertions'),
    );
    memory.content[root.resolve(first.config.inputsPath)] = owned;
    memory.content[root.resolve(first.config.testPath)] = ownedTest;
    final second = generateJourney(
      steps: [
        ...steps(),
        RecordedStep(
          id: 'step_0004',
          action: RecordedAction.tap,
          target: RecorderTarget(key: 'next'),
        ),
      ],
      app: app,
      config: ExportConfig(),
    );
    final result = await exportFiles(
      workspace: memory,
      projectRoot: root,
      files: second.files(),
      userOwnedPaths: second.userOwnedPaths,
      updateGenerated: true,
      generatedMarkers: {
        for (final p in second.generatedPaths) p: second.config.marker,
      },
    );
    expect(
      result.preserved,
      containsAll([second.config.inputsPath, second.config.testPath]),
    );
    expect(memory.content[root.resolve(first.config.inputsPath)], owned);
    expect(memory.content[root.resolve(first.config.testPath)], ownedTest);
    expect(
      utf8.decode(memory.content[root.resolve(second.config.stepsPath)]!),
      contains('target4'),
    );
    memory.content[root.resolve(second.config.stepsPath)] = Uint8List.fromList(
      utf8.encode('handwritten'),
    );
    await expectLater(
      exportFiles(
        workspace: memory,
        projectRoot: root,
        files: second.files(),
        userOwnedPaths: second.userOwnedPaths,
        updateGenerated: true,
        generatedMarkers: {
          for (final p in second.generatedPaths) p: second.config.marker,
        },
      ),
      throwsStateError,
    );
  });

  test(
    'generates normal Patrol with separate profiles and secret references',
    () {
      final output = generateJourney(
        steps: steps(),
        app: app,
        config: ExportConfig(),
      );
      expect(output.test, contains("patrolTest("));
      expect(output.test, contains('login_inputs.dart'));
      expect(output.steps, contains('find.bySemanticsIdentifier'));
      expect(output.steps, contains('ensureSemantics'));
      expect(output.steps, contains('enablePatrolLog: false'));
      expect(output.steps, contains('findsOneWidget'));
      expect(output.steps, contains('final target1 ='));
      expect(output.steps, isNot(contains('final target_step')));
      expect(output.steps, isNot(contains('tapAt')));
      expect(output.steps, isNot(contains('demo@example.invalid')));
      expect(output.contract, contains('abstract class JourneyInputs'));
      expect(output.contract, contains('String get inputEmail;'));
      expect(output.data, contains('extends JourneyInputs'));
      expect(output.files().keys, hasLength(4));
      expect(output.files().keys, isNot(contains('recorder_config.yaml')));
      expect(output.data, contains('demo@example.invalid'));
      expect(output.data, contains('secondary@example.invalid'));
      expect(output.data, contains('RECORDER_SECRET_PASSWORD'));
      expect(output.data, contains('RECORDER_PROFILE'));
      expect(output.data, isNot(contains('SUPER_SECRET_SENTINEL')));
    },
  );

  test(
    'key-first scoped selectors and all supported fallback shapes generate',
    () {
      for (final kind in SelectorKind.values) {
        final target = RecorderTarget(
          selector: RecorderSelector(
            kind,
            kind == SelectorKind.widgetType ? 'FilledButton' : 'Continue',
          ),
          scope: RecorderSelector(SelectorKind.key, 'shipping'),
        );
        final output = generateJourney(
          steps: [
            RecordedStep(
              id: 'step_0001',
              action: RecordedAction.tap,
              target: target,
            ),
          ],
          app: app,
          config: ExportConfig(),
        );
        expect(output.steps, contains('find.descendant'));
        expect(output.steps, contains('findsOneWidget'));
        expect(output.steps, isNot(contains('.first')));
        expect(output.steps, isNot(contains('tapAt')));
      }
      final preferred = RecorderTarget(
        key: 'login',
        semanticsIdentifier: 'demo.login',
      );
      expect(preferred.selector!.kind, SelectorKind.key);
    },
  );

  test(
    'unresolved target blocks runnable code rather than dropping a step',
    () {
      expect(
        () => generateJourney(
          steps: [
            RecordedStep(
              id: 'step_0001',
              action: RecordedAction.tap,
              target: RecorderTarget(issue: 'Ambiguous selector'),
            ),
          ],
          app: app,
          config: ExportConfig(),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'configuration validates schema, paths, unknown keys and field types',
    () {
      final config = ExportConfig.fromPubspec('name: example');
      expect(
        config.testPath,
        'patrol_test/recorded_journeys/login/login_test.dart',
      );
      for (final path in [
        '/tmp/test',
        '../outside',
        'a/../b',
        'a\\b',
        'a//b',
        'a%2fb',
      ]) {
        expect(
          () => ExportConfig(outputDirectory: path),
          throwsFormatException,
        );
      }
      expect(
        () =>
            ExportConfig.fromPubspec('name: wrong', expectedPackage: 'example'),
        throwsFormatException,
      );
      expect(
        () => ExportConfig.fromPubspec(
          'name: example\nrecorder_config:\n  profile: 42',
        ),
        throwsFormatException,
      );
      expect(
        () => ExportConfig.fromPubspec(
          'name: example\nrecorder_config:\n  extra: true',
        ),
        throwsFormatException,
      );
      expect(
        () => ExportConfig(journeyId: 'bad;command'),
        throwsFormatException,
      );
    },
  );

  test(
    'escaping and manual identifiers cannot inject Dart or shell syntax',
    () {
      expect(dartLiteral(r"$value\'"), contains(r'\$'));
      final output = generateJourney(
        steps: [
          RecordedStep(
            id: 'step_0001',
            action: RecordedAction.tap,
            target: RecorderTarget(key: "quote'\n\$key"),
          ),
        ],
        app: app,
        config: ExportConfig(caseName: r'Case $name'),
      );
      expect(output.steps, contains(r'\$key'));
      expect(output.steps, contains(r'\$name'));
      expect(
        ExportConfig().command(),
        contains('--tags recorder_login_sign_in'),
      );
    },
  );

  test(
    'multiple files are independent and conflicting classifications fail',
    () {
      final first = generateJourney(
        steps: steps(),
        app: app,
        config: ExportConfig(),
      );
      final second = generateJourney(
        steps: steps(),
        app: app,
        config: ExportConfig(journeyId: 'accounts'),
      );
      expect(first.files().keys, isNot(contains(second.config.testPath)));
      expect(first.test, isNot(contains('suite_test.dart')));
      expect(
        () => generateJourney(
          steps: [
            ...steps(),
            RecordedStep(
              id: 'step_0004',
              action: RecordedAction.enterText,
              target: RecorderTarget(key: 'email'),
              input: 'password',
            ),
          ],
          app: app,
          config: ExportConfig(),
        ),
        throwsFormatException,
      );
    },
  );

  test('DTD export policy preserves user inputs and refuses existing generated files', () async {
    final memory = MemoryFiles();
    final root = Uri.parse('file:///workspace/');
    memory.content[root.resolve('inputs.dart')] = Uint8List.fromList(
      utf8.encode('user implementation'),
    );
    final files = {
      'inputs.dart': Uint8List.fromList([0]),
      'patrol_test/new.png': Uint8List.fromList([0, 127, 128, 255]),
      'patrol_test/new.dart': Uint8List.fromList(
        utf8.encode('const name = "caf\u00e9";'),
      ),
    };
    final result = await exportFiles(
      workspace: memory,
      projectRoot: root,
      files: files,
      userOwnedPaths: {'inputs.dart'},
    );
    expect(result.written, ['patrol_test/new.png', 'patrol_test/new.dart']);
    expect(result.preserved, ['inputs.dart']);
    expect(
      utf8.decode(memory.content[root.resolve('inputs.dart')]!),
      'user implementation',
    );
    expect(memory.content[root.resolve('patrol_test/new.png')], [
      0,
      127,
      128,
      255,
    ]);
    await expectLater(
      exportFiles(workspace: memory, projectRoot: root, files: files),
      throwsStateError,
    );
    await expectLater(
      exportFiles(
        workspace: memory,
        projectRoot: root,
        files: {'../outside': Uint8List(0)},
      ),
      throwsFormatException,
    );
  });

  test(
    'export surfaces missing PNG and mismatched text after writing',
    () async {
      final root = Uri.parse('file:///workspace/');
      for (final entry in {
        'image.png': MemoryFiles(dropWrites: true),
        'test.dart': MemoryFiles(corruptWrites: true),
      }.entries) {
        await expectLater(
          exportFiles(
            workspace: entry.value,
            projectRoot: root,
            files: {
              entry.key: Uint8List.fromList(utf8.encode('expected content')),
            },
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(
                'Export verification failed for ${entry.key}. 1 files saved.',
              ),
            ),
          ),
        );
      }
    },
  );
}
