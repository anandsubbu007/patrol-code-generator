import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

import 'support/recording.dart';

Finder targetFinder(RecorderTarget target) {
  Finder selector(RecorderSelector s) => switch (s.kind) {
    SelectorKind.key => find.byKey(ValueKey<String>(s.value)),
    SelectorKind.semanticsIdentifier => find.bySemanticsIdentifier(s.value),
    SelectorKind.semanticsLabel => find.bySemanticsLabel(s.value),
    SelectorKind.fieldLabel => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == s.value,
    ),
    SelectorKind.text => find.text(s.value),
    SelectorKind.richText => find.text(s.value, findRichText: true),
    SelectorKind.widgetType => find.byType(
      s.value == 'IconButton' ? IconButton : FilledButton,
    ),
  };
  final finder = selector(target.selector!);
  return target.scope == null
      ? finder
      : find.descendant(of: selector(target.scope!), matching: finder);
}

class PublicWidgetPage extends StatelessWidget {
  const PublicWidgetPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Plain page'));
}

void main() {
  testWidgets('screenshot naming falls back to the public page widget type', (
    tester,
  ) async {
    await recording(tester, const PublicWidgetPage(), (recorder) async {
      final image = await captureScreen(tester, recorder);
      expect(image.suggestedName, 'public_widget_page');
      expect(image.nameSource, 'page widget type');
    });
  });

  testWidgets(
    'screenshot names prefer current page semantics and active dialogs',
    (tester) async {
      await recording(
        tester,
        Semantics(
          identifier: 'profile_page',
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Profile',
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Semantics(
                  identifier: 'confirmation_dialog',
                  scopesRoute: true,
                  namesRoute: true,
                  explicitChildNodes: true,
                  label: 'Confirm',
                  child: const AlertDialog(title: Text('Confirm action')),
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
        (recorder) async {
          final page = await captureScreen(tester, recorder);
          expect(page.suggestedName, 'profile_page');
          await tester.tap(find.text('Open dialog'));
          await tester.pumpAndSettle();
          final dialog = await captureScreen(tester, recorder);
          expect(dialog.suggestedName, 'confirmation_dialog');
          expect(dialog.nameSource, 'page semantics identifier');
        },
      );
    },
  );

  test(
    'screenshot names are safe and recorder bootstrap metadata is optional',
    () {
      expect(screenshotName('AccountSettingsPage'), 'account_settings_page');
      expect(screenshotName('/settings/preferences'), 'settings_preferences');
      expect(screenshotName('../ 42 Profile?'), 'screen_42_profile');
      expect(screenshotName(''), 'screen');
      final recorder = RecorderController();
      expect(recorder.config.appImport, isNull);
      expect(
        RecorderAppConfig.fromJson(recorder.config.toJson()).appBuilder,
        isNull,
      );
      recorder.dispose();
    },
  );

  testWidgets(
    'an unrelated private region does not make public labels unsupported',
    (tester) async {
      await recording(
        tester,
        Column(
          children: [
            const RecorderSensitive(child: Text('PRIVATE_SENTINEL')),
            FilledButton(onPressed: () {}, child: const Text('Public one')),
            FilledButton(onPressed: () {}, child: const Text('Public two')),
          ],
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.tap(find.text('Public two'));
          final step = recorder.steps.single;
          expect(step.target.issue, isNull);
          expect(targetFinder(step.target), findsOneWidget);
          expect(
            jsonEncode(recorder.snapshot()),
            isNot(contains('PRIVATE_SENTINEL')),
          );
        },
      );
    },
  );

  testWidgets('dropdown open and menu selection produce replayable targets', (
    tester,
  ) async {
    var selected = 'one';
    await recording(
      tester,
      StatefulBuilder(
        builder: (context, update) => DropdownButton<String>(
          key: const ValueKey('choice'),
          value: selected,
          items: const [
            DropdownMenuItem(value: 'one', child: Text('One')),
            DropdownMenuItem(value: 'two', child: Text('Two')),
          ],
          onChanged: (value) => update(() => selected = value!),
        ),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('choice')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Two').last);
        await tester.pumpAndSettle();
        expect(selected, 'two');
        expect(recorder.steps.length, 2);
        expect(recorder.steps.first.target.key, 'choice');
        expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
      },
    );
  });

  testWidgets(
    'capture works before actions, while recording, and after stopping',
    (tester) async {
      await recording(
        tester,
        FilledButton(
          key: const ValueKey('go'),
          onPressed: () {},
          child: const Text('Go'),
        ),
        (recorder) async {
          final before = await captureScreen(tester, recorder);
          expect(before.stepId, isNull);
          recorder.start();
          await tester.pump();
          final during = await captureScreen(tester, recorder);
          expect(during.sessionId, before.sessionId);
          expect(during.captureId, isNot(before.captureId));
          await tester.tap(find.text('Go'));
          recorder.stop();
          final after = await captureScreen(tester, recorder);
          expect(after.stepId, recorder.steps.single.id);
          expect(after.captureId, isNot(during.captureId));
          expect(after.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        },
      );
    },
  );

  testWidgets('capture masks private pixels but keeps the visible viewport', (
    tester,
  ) async {
    await recording(
      tester,
      const Column(
        children: [
          RecorderSensitive(
            child: SizedBox(
              width: 100,
              height: 100,
              child: ColoredBox(color: Colors.red),
            ),
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: ColoredBox(color: Colors.green),
          ),
        ],
      ),
      (recorder) async {
        final screenshot = await captureScreen(tester, recorder);
        final codec = await tester.runAsync(
          () => ui.instantiateImageCodec(screenshot.bytes),
        );
        final frame = await tester.runAsync(() => codec!.getNextFrame());
        final pixels = await tester.runAsync(
          () => frame!.image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final privatePoint = tester.getCenter(find.byType(RecorderSensitive));
        final offset =
            (privatePoint.dy.toInt() * screenshot.width +
                privatePoint.dx.toInt()) *
            4;
        expect(pixels!.buffer.asUint8List().sublist(offset, offset + 4), [
          32,
          32,
          32,
          255,
        ]);
        frame!.image.dispose();
        codec!.dispose();
      },
    );
  });

  testWidgets(
    'background taps and standard toggles do not become unsupported actions',
    (tester) async {
      var enabled = false;
      await recording(
        tester,
        StatefulBuilder(
          builder: (context, update) => Column(
            children: [
              const SizedBox(key: ValueKey('blank'), width: 200, height: 100),
              Switch(
                key: const ValueKey('toggle'),
                value: enabled,
                onChanged: (v) => update(() => enabled = v),
              ),
              Checkbox(
                key: const ValueKey('check'),
                value: enabled,
                onChanged: (v) => update(() => enabled = v!),
              ),
              ListTile(
                key: const ValueKey('tile'),
                title: const Text('Open item'),
                onTap: () {},
              ),
            ],
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('blank')),
            warnIfMissed: false,
          );
          expect(recorder.steps, isEmpty);
          for (final key in ['toggle', 'check', 'tile']) {
            await tester.tap(find.byKey(ValueKey(key)));
            await tester.pump();
          }
          expect(recorder.steps.map((s) => s.target.key), [
            'toggle',
            'check',
            'tile',
          ]);
          expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        },
      );
    },
  );

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
        expect(target.key ?? target.scope?.value, 'second');
        expect(targetFinder(target), findsOneWidget);
      },
    );
  });

  testWidgets('nested tap handlers identify the innermost control', (
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
        expect(recorder.steps.single.target.issue, isNull);
        expect(targetFinder(recorder.steps.single.target), findsOneWidget);
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
          final screenshot = await captureScreen(tester, recorder);
          expect(screenshot.redactedRegions, greaterThan(0));
          recorder.stop();
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
        expect(target.key ?? target.scope?.value, 'shipping');
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
        expect(recorder.steps.single.action, RecordedAction.unsupported);
        expect(
          recorder.steps.single.target.issue,
          contains('Drag needs review'),
        );
        expect(recorder.error, isNull);
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
    'obscured fields automatically use secrets and are masked in screenshots',
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
          final image = await captureScreen(tester, recorder);
          expect(image.redactedRegions, greaterThan(0));
          expect(recorder.state, RecordingState.recording);
          recorder.stop();
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
