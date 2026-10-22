import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_devtools/src/exporter.dart';
import 'package:patrol_recorder_devtools/src/generator.dart';

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
  test(
    'generates normal Patrol with separate profiles and secret references',
    () {
      final output = generateJourney(
        steps: steps(),
        app: app,
        config: ExportConfig(),
      );
      expect(output.test, contains("patrolTest("));
      expect(output.test, contains('login_data.dart'));
      expect(output.test, contains('find.bySemanticsIdentifier'));
      expect(output.test, contains('ensureSemantics'));
      expect(output.test, contains('enablePatrolLog: false'));
      expect(output.test, contains('findsOneWidget'));
      expect(output.test, contains('final target1 ='));
      expect(output.test, isNot(contains('final target_step')));
      expect(output.test, isNot(contains('tapAt')));
      expect(output.test, isNot(contains('demo@example.invalid')));
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
        expect(output.test, contains('find.descendant'));
        expect(output.test, contains('findsOneWidget'));
        expect(output.test, isNot(contains('.first')));
        expect(output.test, isNot(contains('tapAt')));
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
      final config = ExportConfig.fromYaml(ExportConfig().toYaml());
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
        () => ExportConfig.fromYaml('schema_version: 2'),
        throwsFormatException,
      );
      expect(
        () => ExportConfig.fromYaml('schema_version: 1\nprofile: 42'),
        throwsFormatException,
      );
      expect(
        () => ExportConfig.fromYaml('schema_version: 1\nextra: true'),
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
      expect(output.test, contains(r'\$key'));
      expect(output.test, contains(r'\$name'));
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

  test(
    'DTD export policy preserves config and refuses existing user files',
    () async {
      final memory = MemoryFiles();
      final root = Uri.parse('file:///workspace/');
      memory.content[root.resolve('recorder_config.yaml')] = Uint8List.fromList(
        utf8.encode('user configuration'),
      );
      final files = {
        'recorder_config.yaml': Uint8List.fromList([0]),
        'patrol_test/new.png': Uint8List.fromList([0, 127, 128, 255]),
        'patrol_test/new.dart': Uint8List.fromList(
          utf8.encode('const name = "caf\u00e9";'),
        ),
      };
      final written = await exportNewFiles(
        workspace: memory,
        projectRoot: root,
        files: files,
      );
      expect(written, ['patrol_test/new.png', 'patrol_test/new.dart']);
      expect(
        utf8.decode(memory.content[root.resolve('recorder_config.yaml')]!),
        'user configuration',
      );
      expect(memory.content[root.resolve('patrol_test/new.png')], [
        0,
        127,
        128,
        255,
      ]);
      await expectLater(
        exportNewFiles(workspace: memory, projectRoot: root, files: files),
        throwsStateError,
      );
      await expectLater(
        exportNewFiles(
          workspace: memory,
          projectRoot: root,
          files: {'../outside': Uint8List(0)},
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'export surfaces missing PNG and mismatched text after writing',
    () async {
      final root = Uri.parse('file:///workspace/');
      for (final entry in {
        'image.png': MemoryFiles(dropWrites: true),
        'test.dart': MemoryFiles(corruptWrites: true),
      }.entries) {
        await expectLater(
          exportNewFiles(
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
