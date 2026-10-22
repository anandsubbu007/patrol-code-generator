import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// API feasibility tests, not the shipped recorder's automatic-observation mode.
ButtonStyleButton? buttonAt(PointerDownEvent event) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    final creator = target.debugCreator;
    if (creator is! DebugCreator) continue;
    ButtonStyleButton? button;
    creator.element.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is ButtonStyleButton) {
        button = widget;
        return false;
      }
      return true;
    });
    if (button != null) return button;
  }
  return null;
}

EditableText? focusedEditor() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null) return null;
  EditableText? editor;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is EditableText && identical(widget.focusNode, focus)) {
      editor = widget;
      return false;
    }
    return true;
  });
  return editor;
}

void main() {
  testWidgets(
    'passive hit testing discovers uninstrumented buttons, including disabled ones',
    (tester) async {
      var activations = 0;
      final candidates = <Key?, bool>{};
      final events = <Type>[];
      void observe(PointerEvent event) {
        events.add(event.runtimeType);
        if (event is PointerDownEvent) {
          final button = buttonAt(event);
          if (button != null) {
            candidates[button.key] = button.onPressed != null;
          }
        }
      }

      tester.binding.pointerRouter.addGlobalRoute(observe);
      addTearDown(
        () => tester.binding.pointerRouter.removeGlobalRoute(observe),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(
                  key: const ValueKey('enabled'),
                  onPressed: () => activations++,
                  child: const Text('Continue'),
                ),
                const FilledButton(
                  key: ValueKey('disabled'),
                  onPressed: null,
                  child: Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('enabled')));
      await tester.tap(find.byKey(const ValueKey('disabled')));
      expect(activations, 1);
      expect(candidates, {
        const ValueKey('enabled'): true,
        const ValueKey('disabled'): false,
      });
      expect(events.where((type) => type == PointerDownEvent), hasLength(2));
      expect(events.where((type) => type == PointerUpEvent), hasLength(2));

      final cancelled = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('enabled'))),
      );
      await cancelled.cancel();
      expect(events, contains(PointerCancelEvent));
      expect(activations, 1);
    },
  );

  testWidgets(
    'focus discovers an internal text controller without an onChanged hook',
    (tester) async {
      EditableText? discovered;
      TextEditingController? listeningTo;
      var notifications = 0;
      void observeEdit() => notifications++;
      void observeFocus() {
        final editor = focusedEditor();
        if (identical(editor?.controller, listeningTo)) return;
        listeningTo?.removeListener(observeEdit);
        discovered = editor;
        listeningTo = editor?.controller;
        listeningTo?.addListener(observeEdit);
      }

      FocusManager.instance.addListener(observeFocus);
      addTearDown(() {
        FocusManager.instance.removeListener(observeFocus);
        listeningTo?.removeListener(observeEdit);
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(discovered, isNotNull);
      expect(discovered!.obscureText, isTrue);
      expect(discovered!.focusNode.hasFocus, isTrue);

      var before = notifications;
      tester.testTextInput.enterText('FICTIONAL_TEST_INPUT');
      await tester.pump();
      expect(notifications, greaterThan(before));

      // Selection and application writes also notify: this is not user provenance.
      before = notifications;
      discovered!.controller.selection = const TextSelection.collapsed(
        offset: 0,
      );
      expect(notifications, greaterThan(before));
      before = notifications;
      discovered!.controller.text = 'PROGRAMMATIC_TEST_INPUT';
      expect(notifications, greaterThan(before));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(listeningTo, isNull);
    },
  );

  testWidgets(
    'semantics listener observes accessibility requests, not ordinary taps',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var activations = 0;
      final beforeAction = <int>[];
      void observe(ui.SemanticsActionEvent event) {
        if (event.type == ui.SemanticsAction.tap) {
          beforeAction.add(activations);
        }
      }

      tester.binding.addSemanticsActionListener(observe);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilledButton(
                key: const ValueKey('button'),
                onPressed: () => activations++,
                child: const Text('Continue'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('button')));
        await tester.pump();
        expect(activations, 1);
        expect(beforeAction, isEmpty);

        final node = tester.getSemantics(find.byKey(const ValueKey('button')));
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        // Inject at the public platform boundary only in this test; replace no callbacks.
        tester.binding.platformDispatcher.onSemanticsActionEvent!(
          ui.SemanticsActionEvent(
            type: ui.SemanticsAction.tap,
            viewId: tester.view.viewId,
            nodeId: node.id,
          ),
        );
        await tester.pump();
        expect(beforeAction, [1]);
        expect(activations, 2);
      } finally {
        tester.binding.removeSemanticsActionListener(observe);
        semantics.dispose();
      }
    },
  );

  testWidgets('duplicate labels can be scoped without per-button keys', (
    tester,
  ) async {
    var chosen = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Container(
                key: const ValueKey('billing'),
                child: FilledButton(
                  onPressed: () => chosen = 'billing',
                  child: const Text('Continue'),
                ),
              ),
              Container(
                key: const ValueKey('shipping'),
                child: FilledButton(
                  onPressed: () => chosen = 'shipping',
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Continue'), findsNWidgets(2));
    final scoped = find.descendant(
      of: find.byKey(const ValueKey('shipping')),
      matching: find.text('Continue'),
    );
    expect(scoped, findsOneWidget);
    await tester.tap(scoped);
    expect(chosen, 'shipping');
  });
}
