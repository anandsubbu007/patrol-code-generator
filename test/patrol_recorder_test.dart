import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

Future<void> recording(
  WidgetTester tester,
  Widget child,
  Future<void> Function(RecorderController recorder) body, {
  int maxSteps = 500,
}) async {
  final recorder = RecorderController(
    config: RecorderAppConfig(
      appImport: 'package:example/app.dart',
      appBuilder: 'createApp',
      safeProfiles: const {
        'demo': {'email': 'demo@example.invalid'},
      },
    ),
    maxSteps: maxSteps,
  );
  try {
    await tester.pumpWidget(
      RecorderScope(
        controller: recorder,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await body(recorder);
  } finally {
    if (recorder.state == RecordingState.recording) recorder.stop();
    await tester.pumpWidget(const SizedBox());
    recorder.dispose();
  }
}

Finder targetFinder(RecorderTarget target) {
  Finder selector(RecorderSelector s) => switch (s.kind) {
    SelectorKind.key => find.byKey(ValueKey<String>(s.value)),
    SelectorKind.semanticsIdentifier => find.bySemanticsIdentifier(s.value),
    SelectorKind.semanticsLabel => find.bySemanticsLabel(s.value),
    SelectorKind.fieldLabel => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == s.value,
    ),
    SelectorKind.text => find.text(s.value),
    SelectorKind.widgetType => find.byType(
      s.value == 'IconButton' ? IconButton : FilledButton,
    ),
  };
  final finder = selector(target.selector!);
  return target.scope == null
      ? finder
      : find.descendant(of: selector(target.scope!), matching: finder);
}

void main() {
  testWidgets('plain text fallback excludes offstage duplicates', (
    tester,
  ) async {
    await recording(
      tester,
      ExcludeSemantics(
        child: Column(
          children: [
            FilledButton(onPressed: () {}, child: const Text('Unique')),
            Offstage(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Unique'),
              ),
            ),
          ],
        ),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Unique'));
        final target = recorder.steps.single.target;
        expect(target.selector?.kind, SelectorKind.text);
        expect(targetFinder(target), findsOneWidget);
      },
    );
  });

  testWidgets('identical icon types resolve only with unique parent scope', (
    tester,
  ) async {
    await recording(
      tester,
      Column(
        children: [
          for (final name in ['first', 'second'])
            Container(
              key: ValueKey(name),
              child: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
            ),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('second')),
            matching: find.byType(IconButton),
          ),
        );
        final target = recorder.steps.single.target;
        expect(target.selector?.kind, SelectorKind.widgetType);
        expect(target.scope?.value, 'second');
        expect(targetFinder(target), findsOneWidget);
      },
    );
  });

  testWidgets('nested competing tap handlers are visibly unresolved', (
    tester,
  ) async {
    await recording(
      tester,
      FilledButton(
        key: const ValueKey('outer'),
        onPressed: () {},
        child: GestureDetector(onTap: () {}, child: const Text('Nested')),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Nested'));
        expect(
          recorder.steps.single.target.issue,
          contains('Nested tap handlers'),
        );
      },
    );
  });

  testWidgets(
    'sensitive labels are not serialized and ignore excludes field activity',
    (tester) async {
      await recording(
        tester,
        Column(
          children: [
            RecorderSensitive(
              child: FilledButton(
                key: const ValueKey('safe'),
                onPressed: () {},
                child: const Text('SECRET_LABEL_SENTINEL'),
              ),
            ),
            const RecorderIgnore(child: TextField()),
          ],
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('safe')));
          await tester.tap(find.byType(TextField));
          await tester.pump();
          tester.testTextInput.enterText('SECRET_INPUT_SENTINEL');
          await tester.pump();
          expect(recorder.steps, hasLength(1));
          expect(jsonEncode(recorder.snapshot()), isNot(contains('SENTINEL')));
          recorder.stop();
          await expectLater(recorder.capture(), throwsStateError);
        },
      );
    },
  );

  testWidgets('focus controller replacement and unmount detach old listeners', (
    tester,
  ) async {
    final first = TextEditingController();
    final second = TextEditingController();
    var current = first;
    late StateSetter rebuild;
    await recording(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return TextField(key: const ValueKey('entry'), controller: current);
        },
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.byType(TextField));
        await tester.pump();
        rebuild(() => current = second);
        await tester.pump();
        first.text = 'OLD_CONTROLLER_SENTINEL';
        expect(recorder.steps, isEmpty);
        tester.testTextInput.enterText('NEW_CONTROLLER_SENTINEL');
        await tester.pump();
        expect(recorder.steps.single.input, 'entry');
        expect(jsonEncode(recorder.snapshot()), isNot(contains('SENTINEL')));
      },
    );
    first.text = 'AFTER_UNMOUNT';
    second.text = 'AFTER_UNMOUNT';
    first.dispose();
    second.dispose();
  });

  testWidgets('bounded discovery rejects a tree beyond the element limit', (
    tester,
  ) async {
    await recording(
      tester,
      Column(
        children: [
          FilledButton(
            key: const ValueKey('go'),
            onPressed: () {},
            child: const Text('Go'),
          ),
          for (var i = 0; i < 10000; i++) const SizedBox.shrink(),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Go'));
        expect(recorder.steps.single.target.issue, contains('10000'));
      },
    );
  });

  testWidgets(
    'automatic taps preserve callbacks and prefer keys over semantics',
    (tester) async {
      var taps = 0;
      await recording(
        tester,
        Semantics(
          identifier: 'demo.login',
          child: FilledButton(
            key: const ValueKey('login'),
            onPressed: () => taps++,
            child: const Text('Login'),
          ),
        ),
        (recorder) async {
          await tester.tap(find.text('Login'));
          expect(recorder.steps, isEmpty);
          recorder.start();
          await tester.pump();
          await tester.tap(find.text('Login'));
          expect(recorder.steps.single.target.key, 'login');
          expect(targetFinder(recorder.steps.single.target), findsOneWidget);
          final step = RecordedStep.fromJson(
            jsonDecode(jsonEncode(recorder.steps.single.toJson()))
                as Map<String, dynamic>,
          );
          expect(step.source, ObservationSource.pointerGesture);
          expect(step.target.identity, recorder.steps.single.target.identity);
          recorder.stop();
          await tester.tap(find.text('Login'));
          expect(recorder.steps, hasLength(1));
          expect(taps, 3);
        },
      );
    },
  );

  testWidgets('duplicate labels and widget types use unique ancestor scopes', (
    tester,
  ) async {
    var selected = '';
    await recording(
      tester,
      Column(
        children: [
          for (final name in ['billing', 'shipping'])
            Container(
              key: ValueKey(name),
              child: FilledButton(
                onPressed: () => selected = name,
                child: const Text('Continue'),
              ),
            ),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('shipping')),
            matching: find.text('Continue'),
          ),
        );
        final target = recorder.steps.single.target;
        expect(target.issue, isNull);
        expect(target.scope?.value, 'shipping');
        expect(targetFinder(target), findsOneWidget);
        expect(selected, 'shipping');
      },
    );
  });

  testWidgets(
    'unscoped duplicates stay unresolved without index or coordinates',
    (tester) async {
      await recording(
        tester,
        Column(
          children: [
            FilledButton(onPressed: () {}, child: const Text('Continue')),
            FilledButton(onPressed: () {}, child: const Text('Continue')),
          ],
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.tap(find.text('Continue').last);
          expect(recorder.steps.single.target.selector, isNull);
          expect(
            recorder.steps.single.target.issue,
            contains('No unique selector'),
          );
          final json = jsonEncode(recorder.snapshot());
          expect(json, isNot(contains('"position"')));
          expect(json, isNot(contains('"index"')));
        },
      );
    },
  );

  testWidgets('keyless controls use semantics or text and then a public type', (
    tester,
  ) async {
    await recording(
      tester,
      Column(
        children: [
          Semantics(
            identifier: 'confirm',
            child: FilledButton(onPressed: () {}, child: const Text('Confirm')),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Confirm'));
        final first = recorder.steps.single.target;
        expect(first.selector?.kind, SelectorKind.semanticsIdentifier);
        expect(targetFinder(first), findsOneWidget);
        await tester.tap(find.byType(IconButton));
        final last = recorder.steps.last.target;
        expect(last.selector?.kind, SelectorKind.widgetType);
        expect(targetFinder(last), findsOneWidget);
      },
    );
  });

  testWidgets('disabled, ignored and cancelled controls do not record', (
    tester,
  ) async {
    var taps = 0;
    await recording(
      tester,
      Column(
        children: [
          const FilledButton(onPressed: null, child: Text('Disabled')),
          RecorderIgnore(
            child: FilledButton(
              onPressed: () => taps++,
              child: const Text('Ignored'),
            ),
          ),
          FilledButton(onPressed: () => taps++, child: const Text('Cancel')),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Disabled'));
        await tester.tap(find.text('Ignored'));
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Cancel')),
        );
        await gesture.cancel();
        expect(recorder.steps, isEmpty);
        expect(taps, 1);
        expect(recorder.error, isNull);
      },
    );
  });

  testWidgets('drags and long holds are not silently converted into taps', (
    tester,
  ) async {
    await recording(
      tester,
      FilledButton(onPressed: () {}, child: const Text('Drag')),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.drag(find.text('Drag'), const Offset(100, 0));
        expect(recorder.steps, isEmpty);
        expect(recorder.error, contains('Drag/long press'));
      },
    );
  });

  testWidgets('automatic field observation uses references, never values', (
    tester,
  ) async {
    await recording(tester, const TextField(key: ValueKey('email')), (
      recorder,
    ) async {
      recorder.start();
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.enterText('SUPER_SECRET_SENTINEL');
      await tester.pump();
      tester.testTextInput.enterText('SECOND_SENTINEL');
      await tester.pump();
      expect(recorder.steps, hasLength(1));
      final step = recorder.steps.single;
      expect(step.input, 'email');
      expect(step.source, ObservationSource.focusedController);
      expect(step.secret, isFalse);
      final json = jsonEncode(recorder.snapshot());
      expect(json, isNot(contains('SENTINEL')));
      expect(step.toJson().keys, isNot(contains('value')));
      recorder.stop();
      tester.testTextInput.enterText('AFTER_STOP');
      expect(recorder.steps, hasLength(1));
    });
  });

  testWidgets(
    'keyless fields use labels; already focused fields are discovered',
    (tester) async {
      await recording(
        tester,
        const TextField(decoration: InputDecoration(labelText: 'Email')),
        (recorder) async {
          await tester.tap(find.byType(TextField));
          await tester.pump();
          recorder.start();
          await tester.pump();
          tester.testTextInput.enterText('FICTIONAL');
          await tester.pump();
          final step = recorder.steps.single;
          expect(step.input, 'input_0001');
          expect(step.target.selector?.kind, SelectorKind.fieldLabel);
          expect(targetFinder(step.target), findsOneWidget);
        },
      );
    },
  );

  testWidgets(
    'obscured fields automatically use secrets and block screenshots',
    (tester) async {
      await recording(
        tester,
        const TextField(key: ValueKey('password'), obscureText: true),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.tap(find.byType(TextField));
          await tester.pump();
          tester.testTextInput.enterText('SECRET_SENTINEL');
          await tester.pump();
          expect(recorder.steps.single.secret, isTrue);
          expect(
            jsonEncode(recorder.snapshot()),
            isNot(contains('SECRET_SENTINEL')),
          );
          recorder.stop();
          await expectLater(recorder.capture(), throwsStateError);
        },
      );
    },
  );

  testWidgets('limit stops visibly without preventing application actions', (
    tester,
  ) async {
    var taps = 0;
    await recording(
      tester,
      FilledButton(
        key: const ValueKey('go'),
        onPressed: () => taps++,
        child: const Text('Go'),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Go'));
        await tester.tap(find.text('Go'));
        expect(taps, 2);
        expect(recorder.steps, hasLength(1));
        expect(recorder.state, RecordingState.stopped);
        expect(recorder.error, contains('limit'));
      },
      maxSteps: 1,
    );
  });

  testWidgets('accessibility tap requests are recorded without pointer input', (
    tester,
  ) async {
    var taps = 0;
    await recording(
      tester,
      FilledButton(
        key: const ValueKey('go'),
        onPressed: () => taps++,
        child: const Text('Go'),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        final node = tester.getSemantics(find.byKey(const ValueKey('go')));
        tester.binding.platformDispatcher.onSemanticsActionEvent!(
          ui.SemanticsActionEvent(
            type: ui.SemanticsAction.tap,
            viewId: tester.view.viewId,
            nodeId: node.id,
          ),
        );
        await tester.pump();
        expect(taps, 1);
        expect(recorder.steps.single.source, ObservationSource.semanticsAction);
        expect(recorder.steps.single.target.key, 'go');
      },
    );
  });

  test(
    'invalid targets, arbitrary types and profile credentials are rejected',
    () {
      expect(() => RecorderTarget(key: ''), throwsFormatException);
      expect(
        () => RecorderSelector(SelectorKind.widgetType, 'Evil()'),
        throwsFormatException,
      );
      expect(() => RecorderTarget(), throwsFormatException);
      expect(
        () => RecorderAppConfig(
          appImport: 'package:example/app.dart',
          appBuilder: 'createApp',
          safeProfiles: const {
            'demo': {'password': 'never_export'},
          },
        ),
        throwsFormatException,
      );
    },
  );
}
