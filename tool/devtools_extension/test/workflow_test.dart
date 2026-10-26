import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';
import 'package:patrol_recorder_devtools/recorder_panel.dart';
import 'package:patrol_recorder_devtools/src/backend.dart';

class TestBackend implements RecorderBackend {
  String state = 'ready';
  int session = 0;
  bool connected = true;
  bool addKey = true;
  bool configFails = false;
  List<Map<String, String>> suggestions = [];
  String? error;
  String? selectionKind;
  List<RecordedStep> steps = [];
  final commands = <(String, Map<String, String>)>[];

  @override
  Future<bool> addKeyEnabled() async {
    if (configFails) throw StateError('Invalid app configuration');
    return addKey;
  }

  @override
  Future<Map<String, dynamic>> command(
    String command, {
    Map<String, String> parameters = const {},
  }) async {
    if (!connected) throw StateError('Disconnected');
    commands.add((command, parameters));
    if (command == 'start') {
      state = 'recording';
      session++;
      steps = [];
    }
    if (command == 'stop') state = 'stopped';
    if (command == 'selectTarget') selectionKind = parameters['kind'];
    return {
      'sessionId': '$session',
      'state': state,
      'steps': steps.map((step) => step.toJson()).toList(),
      'error': error,
      'selecting': false,
      'keySuggestions': suggestions,
    };
  }
}

Future<void> mount(WidgetTester tester, TestBackend backend) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: RecorderPanel(backend: backend)));
  await tester.pumpAndSettle();
}

RecordedStep tap({bool unresolved = false}) => RecordedStep(
  id: 'step_0001',
  action: RecordedAction.tap,
  target: unresolved
      ? RecorderTarget(issue: 'Ambiguous target')
      : RecorderTarget(key: 'save'),
);

void main() {
  testWidgets('configuration errors survive successful snapshot polls', (
    tester,
  ) async {
    final backend = TestBackend()..configFails = true;
    await mount(tester, backend);
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid app configuration'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Invalid app configuration'), findsOneWidget);
    expect(backend.state, 'ready');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('suggestions identify owners without applying source edits', (
    tester,
  ) async {
    final backend = TestBackend()
      ..suggestions = [
        {
          'widget': 'InkWell',
          'key': 'ink_well_1',
          'tree': 'Column[0] > InkWell[1]',
        },
      ];
    await mount(tester, backend);
    expect(find.textContaining('Suggested key for InkWell'), findsOneWidget);
    expect(
      find.textContaining('No source edits have been applied.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  test('pubspec addkey is optional and strictly boolean', () {
    expect(parseAddKeyEnabled('name: app'), isFalse);
    expect(parseAddKeyEnabled('recorder_config:\n  addkey: true'), isTrue);
    expect(
      () => parseAddKeyEnabled('recorder_config:\n  addkey: "true"'),
      throwsFormatException,
    );
    expect(
      () => parseAddKeyEnabled('recorder_config: invalid'),
      throwsFormatException,
    );
  });

  testWidgets('record configures keys and copies direct Dart without setup', (
    tester,
  ) async {
    final backend = TestBackend();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(tester, backend);
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(backend.commands.firstWhere((call) => call.$1 == 'configure').$2, {
      'addkey': 'true',
    });
    expect(backend.state, 'recording');
    backend.steps = [tap()];
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.text(r'await $(const ValueKey("save")).tap();'),
      findsOneWidget,
    );
    await tester.tap(find.text('Copy Patrol code'));
    await tester.pumpAndSettle();
    expect(clipboard, r'await $(const ValueKey("save")).tap();');
    expect(find.textContaining('YAML'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unresolved action blocks copying until explicitly excluded', (
    tester,
  ) async {
    final backend = TestBackend()
      ..state = 'stopped'
      ..steps = [tap(unresolved: true)];
    await mount(tester, backend);
    OutlinedButton copy() =>
        tester.widget(find.widgetWithText(OutlinedButton, 'Copy Patrol code'));
    expect(copy().onPressed, isNull);
    expect(find.textContaining('Review required:'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('step_0001')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Review required:'), findsNothing);
    expect(copy().onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'incomplete recording requires review and disconnect retains code',
    (tester) async {
      final backend = TestBackend()
        ..state = 'stopped'
        ..steps = [tap()]
        ..error = 'Step limit';
      await mount(tester, backend);
      final copy = find.widgetWithText(OutlinedButton, 'Copy Patrol code');
      expect(tester.widget<OutlinedButton>(copy).onPressed, isNull);
      await tester.tap(find.text('Incomplete recording: Step limit'));
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(copy).onPressed, isNotNull);
      backend.connected = false;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('last code retained'), findsOneWidget);
      expect(
        find.text(r'await $(const ValueKey("save")).tap();'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('expectation selection distinguishes text from component', (
    tester,
  ) async {
    final backend = TestBackend()..state = 'recording';
    await mount(tester, backend);
    await tester.tap(find.text('Validate text instead of component'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expectation'));
    await tester.pumpAndSettle();
    expect(backend.selectionKind, 'text');
    await tester.tap(find.text('Validate text instead of component'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expectation'));
    await tester.pumpAndSettle();
    expect(backend.selectionKind, 'component');
    await tester.pumpWidget(const SizedBox());
  });
}
