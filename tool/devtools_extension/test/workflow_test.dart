import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';
import 'package:patrol_recorder_devtools/recorder_panel.dart';
import 'package:patrol_recorder_devtools/src/backend.dart';
import 'package:patrol_recorder_devtools/src/expectation_dialog.dart';
import 'package:patrol_recorder_devtools/src/recording_writer.dart';

class TestFiles implements WorkspaceFiles {
  final content = <Uri, Uint8List>{};
  bool failWrites = false;
  @override
  Future<bool> exists(Uri uri) async => content.containsKey(uri);
  @override
  Future<String?> read(Uri uri) async =>
      content[uri] == null ? null : utf8.decode(content[uri]!);
  @override
  Future<void> write(Uri uri, Uint8List bytes) async {
    if (failWrites) throw StateError('Test write failed');
    content[uri] = bytes;
  }
}

class TestBackend implements RecorderBackend {
  TestBackend() {
    files.content[root.resolve('pubspec.yaml')] = Uint8List.fromList(
      utf8.encode('''
name: example
recorder_config:
  journey_id: ui_flow
  case_name: UI flow
  screenshots_directory: artifacts/captures
'''),
    );
  }
  final root = Uri.parse('file:///example/');
  @override
  final TestFiles files = TestFiles();
  String state = 'ready';
  int session = 0, captures = 0;
  List<RecordedStep> recorded = [];
  bool selecting = false;
  RecorderTarget? selection;
  @override
  Future<List<Uri>> projects() async => [root, root];
  @override
  Future<Map<String, dynamic>> command(
    String command, {
    Map<String, String> parameters = const {},
  }) async {
    if (command == 'start') {
      state = 'recording';
      session++;
      recorded = [];
    }
    if (command == 'stop') state = 'stopped';
    if (command == 'selectTarget') {
      selecting = true;
      selection = null;
    }
    if (command == 'confirmExpectation') {
      recorded.add(
        RecordedStep(
          id: 'step_${(recorded.length + 1).toString().padLeft(4, '0')}',
          action: RecordedAction.expect,
          target: selection!,
          source: ObservationSource.authored,
          expectation: ExpectationSpec.fromJson(
            jsonDecode(parameters['expectation']!) as Map<String, dynamic>,
          ),
        ),
      );
    }
    if (command == 'cancelSelection' || command == 'confirmExpectation') {
      selecting = false;
      selection = null;
    }
    final snapshot = <String, dynamic>{
      'protocolVersion': recorderProtocolVersion,
      'sessionId': 'session_$session',
      'state': state,
      'sequence': recorded.length,
      'steps': recorded.map((s) => s.toJson()).toList(),
      'config': RecorderAppConfig(
        appImport: 'package:example/app.dart',
        appBuilder: 'createApp',
      ).toJson(),
      'error': null,
      'capabilities': ['expectationPicker'],
      'selecting': selecting,
      'selection': selection?.toJson(),
    };
    if (command == 'capture') {
      snapshot['screenshot'] = {
        'kind': 'flutterContent',
        'sessionId': 'session_$session',
        'captureId': 'capture_${++captures}',
        'suggestedName': 'account_overview',
        'nameSource': 'page semantics identifier',
        'stepId': recorded.isEmpty ? null : recorded.last.id,
        'redactedRegions': 0,
        'width': 1,
        'height': 1,
        'png': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      };
    }
    return snapshot;
  }
}

Future<void> mount(WidgetTester tester, TestBackend backend) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: RecorderPanel(backend: backend)));
  await tester.pumpAndSettle();
}

Future<void> start(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Record'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Record and save YAML'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'exact text is prefilled and edits survive changing expectation kinds',
    (tester) async {
      ExpectationSpec? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showDialog<ExpectationSpec>(
                    context: context,
                    builder: (_) => ExpectationDialog(
                      target: RecorderTarget(key: 'title'),
                      suggestedText: 'Account overview',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      Future<void> choose(String label) async {
        await tester.tap(
          find.byType(DropdownButtonFormField<RecordedExpectation>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await choose('Exact text');
      final text = find.widgetWithText(TextFormField, 'Expected text');
      expect(
        tester.widget<TextFormField>(text).controller!.text,
        'Account overview',
      );
      await tester.enterText(text, 'Custom expected text');
      await choose('Match count');
      final count = find.widgetWithText(TextFormField, 'Expected count');
      expect(tester.widget<TextFormField>(count).controller!.text, '1');
      await tester.enterText(count, '2');
      await choose('Exact text');
      expect(
        tester.widget<TextFormField>(text).controller!.text,
        'Custom expected text',
      );
      await tester.tap(find.text('Save expectation'));
      await tester.pumpAndSettle();
      expect(saved!.value, 'Custom expected text');
    },
  );

  testWidgets('expectation form validates values on a narrow viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ExpectationSpec? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showDialog<ExpectationSpec>(
                  context: context,
                  builder: (_) =>
                      ExpectationDialog(target: RecorderTarget(key: 'status')),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<RecordedExpectation>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match count').last);
    await tester.pumpAndSettle();
    final count = find.widgetWithText(TextFormField, 'Expected count');
    final timeout = find.widgetWithText(TextFormField, 'Timeout (ms)');
    await tester.enterText(count, '-1');
    await tester.tap(find.text('Save expectation'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Enter a nonnegative integer.'), findsOneWidget);
    await tester.enterText(count, '2');
    await tester.enterText(timeout, '99');
    await tester.tap(find.text('Save expectation'));
    await tester.pumpAndSettle();
    expect(find.text('Enter 100-120000 milliseconds.'), findsOneWidget);
    await tester.enterText(timeout, '250');
    await tester.tap(find.text('Save expectation'));
    await tester.pumpAndSettle();
    expect(saved!.kind, RecordedExpectation.count);
    expect(saved!.value, 2);
    expect(saved!.timeoutMs, 250);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picked expectations are confirmed into YAML and cancellation adds nothing',
    (tester) async {
      final backend = TestBackend();
      await mount(tester, backend);
      await start(tester);
      await tester.tap(find.text('Add expectation'));
      await tester.pumpAndSettle();
      expect(backend.selecting, true);
      expect(backend.recorded, isEmpty);
      backend.selection = RecorderTarget(key: 'confirmation');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Save expectation'), findsOneWidget);
      await tester.tap(find.text('Save expectation'));
      await tester.pumpAndSettle();
      final yaml = (await backend.files.read(
        backend.root.resolve('patrol_recorder/ui_flow.yml'),
      ))!;
      final saved = RecordedJourney.fromYaml(yaml);
      expect(saved.steps.single.action, RecordedAction.expect);
      expect(saved.steps.single.target.key, 'confirmation');
      expect(saved.steps.single.expectation!.kind, RecordedExpectation.visible);
      expect(backend.selecting, false);
      await tester.tap(find.text('Add expectation'));
      await tester.pumpAndSettle();
      backend.selection = RecorderTarget(key: 'other');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(backend.recorded, hasLength(1));
      expect(backend.selecting, false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'screenshot suggestions are unique and can be named for a specific state',
    (tester) async {
      final backend = TestBackend();
      await mount(tester, backend);
      await start(tester);
      await tester.tap(find.text('Capture visible screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture visible screen'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(
        TextFormField,
        'Screenshot name (without .png)',
      );
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'account_overview_2',
      );
      await tester.enterText(field, 'account_overview');
      await tester.tap(find.text('Save screenshot'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Name already used in this recording.'),
        findsOneWidget,
      );
      await tester.enterText(field, 'account_expanded');
      await tester.tap(find.text('Save screenshot'));
      await tester.pumpAndSettle();
      final yaml = (await backend.files.read(
        backend.root.resolve('patrol_recorder/ui_flow.yml'),
      ))!;
      final doc = RecordedJourney.fromYaml(yaml);
      expect(doc.screenshots.map((s) => s.name), [
        'account_overview',
        'account_expanded',
      ]);
      expect(yaml, isNot(contains('session_')));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('stable capture paths do not overwrite unrelated PNGs', () async {
    final backend = TestBackend();
    final writer = await RecordingWriter.open(
      root: backend.root,
      config: ExportConfig(journeyId: 'ui_flow', screenshotsDirectory: 'shots'),
      files: backend.files,
      app: RecorderAppConfig(),
    );
    await backend.command('start');
    final snapshot = await backend.command('capture');
    final info = Map<String, dynamic>.from(snapshot['screenshot'] as Map);
    final image = CapturedScreen(
      base64Decode(info.remove('png') as String),
      info,
      name: 'account',
    );
    final uri = backend.root.resolve('shots/ui_flow/account.png');
    backend.files.content[uri] = Uint8List.fromList([1, 2, 3]);
    await expectLater(
      writer.persist(
        snapshot,
        captures: [image],
        excluded: {},
        acknowledgedIncomplete: false,
      ),
      throwsStateError,
    );
    expect(backend.files.content[uri], [1, 2, 3]);
  });

  testWidgets(
    'Record creates YAML immediately, autosaves references, and Stop finalizes it',
    (tester) async {
      final backend = TestBackend();
      await mount(tester, backend);
      await start(tester);
      final uri = backend.root.resolve('patrol_recorder/ui_flow.yml');
      var yaml = await backend.files.read(uri);
      expect(yaml, isNotNull);
      expect(RecordedJourney.fromYaml(yaml!).state, 'recording');
      expect(RecordedJourney.fromYaml(yaml).steps, isEmpty);
      backend.recorded = [
        RecordedStep(
          id: 'step_0001',
          action: RecordedAction.enterText,
          target: RecorderTarget(key: 'user_name'),
          input: 'user_name',
        ),
      ];
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      yaml = await backend.files.read(uri);
      expect(yaml, contains('input: "{{user_name}}"'));
      await tester.tap(find.text('Stop recording'));
      await tester.pumpAndSettle();
      expect(
        RecordedJourney.fromYaml((await backend.files.read(uri))!).state,
        'stopped',
      );
      expect(find.text('Copy generator command'), findsOneWidget);
      expect(
        backend.files.content.keys.any((u) => u.path.endsWith('.dart')),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'same name replaces YAML and screenshot directory is honored immediately',
    (tester) async {
      final backend = TestBackend();
      await mount(tester, backend);
      await start(tester);
      await tester.tap(find.text('Capture visible screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save screenshot'));
      await tester.pumpAndSettle();
      final uri = backend.root.resolve('patrol_recorder/ui_flow.yml');
      var doc = RecordedJourney.fromYaml((await backend.files.read(uri))!);
      expect(
        doc.screenshots.single.path,
        'artifacts/captures/ui_flow/account_overview.png',
      );
      expect(doc.screenshots.single.name, 'account_overview');
      final firstRecording = doc.toYaml();
      expect(
        await backend.files.exists(
          backend.root.resolve(doc.screenshots.single.path),
        ),
        isTrue,
      );
      await tester.tap(find.text('Stop recording'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Record'));
      await start(tester);
      doc = RecordedJourney.fromYaml((await backend.files.read(uri))!);
      expect(doc.toYaml(), isNot(contains('session_')));
      expect(doc.screenshots, isEmpty);
      expect(
        backend.files.content.keys.where((u) => u.path.endsWith('.yml')),
        hasLength(1),
      );
      await tester.tap(find.text('Capture visible screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save screenshot'));
      await tester.pumpAndSettle();
      doc = RecordedJourney.fromYaml((await backend.files.read(uri))!);
      expect(
        doc.screenshots.single.path,
        'artifacts/captures/ui_flow/account_overview.png',
      );
      expect(doc.toYaml(), firstRecording);
      expect(
        backend.files.content.keys.where((u) => u.path.endsWith('.png')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'save failure is explicit and retry persists the retained recording',
    (tester) async {
      final backend = TestBackend();
      await mount(tester, backend);
      backend.files.failWrites = true;
      await start(tester);
      expect(find.textContaining('YAML NOT UP TO DATE'), findsOneWidget);
      expect(find.text('Journey YAML saved'), findsNothing);
      backend.files.failWrites = false;
      await tester.tap(find.text('Retry YAML save'));
      await tester.pumpAndSettle();
      expect(find.text('Journey YAML saved'), findsOneWidget);
      expect(
        await backend.files.exists(
          backend.root.resolve('patrol_recorder/ui_flow.yml'),
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('writer refuses foreign YAML and concurrent changes', () async {
    final backend = TestBackend();
    final app = RecorderAppConfig(
      appImport: 'package:example/app.dart',
      appBuilder: 'createApp',
    );
    final config = ExportConfig(journeyId: 'ui_flow');
    final uri = backend.root.resolve(config.yamlPath);
    backend.files.content[uri] = Uint8List.fromList(
      utf8.encode('user-authored: true'),
    );
    await expectLater(
      RecordingWriter.open(
        root: backend.root,
        config: config,
        files: backend.files,
        app: app,
      ),
      throwsStateError,
    );
    backend.files.content.remove(uri);
    final writer = await RecordingWriter.open(
      root: backend.root,
      config: config,
      files: backend.files,
      app: app,
    );
    expect(
      writer.generateCommand,
      'dart run patrol_recorder_generator:generate --journey ui_flow'
      ' --recordings-directory patrol_recorder',
    );
    await writer.persist(
      await backend.command('start'),
      captures: [],
      excluded: {},
      acknowledgedIncomplete: false,
    );
    backend.files.content[uri] = Uint8List.fromList(
      utf8.encode('another writer'),
    );
    await expectLater(
      writer.persist(
        await backend.command('stop'),
        captures: [],
        excluded: {},
        acknowledgedIncomplete: false,
      ),
      throwsStateError,
    );
    expect(await backend.files.read(uri), 'another writer');
  });
}
