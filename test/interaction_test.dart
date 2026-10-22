import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

import 'support/recording.dart';

void main() {
  testWidgets('scroll position observation survives consumed notifications and detaches on stop', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await recording(tester, NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: SizedBox(height: 240, child: ListView.builder(
        key: const ValueKey('consumed'), controller: controller, itemCount: 40, itemExtent: 60,
        itemBuilder: (_, i) => ListTile(key: ValueKey('consumed_$i'), title: Text('Item $i')),
      )),
    ), (recorder) async {
      recorder.start();
      await tester.pump();
      await tester.drag(find.byKey(const ValueKey('consumed')), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(recorder.steps.single.action, RecordedAction.scrollUntilVisible);
      expect(recorder.steps.single.scrollView!.key, 'consumed');
      recorder.stop();
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(recorder.steps, hasLength(1));
    });
  });

  testWidgets(
    'horizontal and reversed scrolls preserve their replay direction',
    (tester) async {
      await recording(
        tester,
        SizedBox(
          width: 300,
          height: 120,
          child: ListView.builder(
            key: const ValueKey('horizontal'),
            scrollDirection: Axis.horizontal,
            itemCount: 30,
            itemExtent: 100,
            itemBuilder: (_, i) => SizedBox(
              key: ValueKey('horizontal_$i'),
              child: Text('Item $i'),
            ),
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.drag(
            find.byKey(const ValueKey('horizontal')),
            const Offset(-200, 0),
          );
          await tester.pumpAndSettle();
          expect(
            recorder.steps.single.scrollDirection,
            RecordedScrollDirection.right,
          );
        },
      );
      await recording(
        tester,
        SizedBox(
          height: 240,
          child: ListView.builder(
            key: const ValueKey('reversed'),
            reverse: true,
            itemCount: 30,
            itemExtent: 60,
            itemBuilder: (_, i) => ListTile(
              key: ValueKey('reverse_$i'),
              title: Text('Reverse $i'),
            ),
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.drag(
            find.byKey(const ValueKey('reversed')),
            const Offset(0, 180),
          );
          await tester.pumpAndSettle();
          expect(
            recorder.steps.single.scrollDirection,
            RecordedScrollDirection.up,
          );
        },
      );
    },
  );

  testWidgets('mouse-wheel scrolling produces a target-based scroll', (
    tester,
  ) async {
    await recording(
      tester,
      SizedBox(
        height: 240,
        child: ListView.builder(
          key: const ValueKey('wheel_list'),
          itemCount: 40,
          itemExtent: 60,
          itemBuilder: (_, i) =>
              ListTile(key: ValueKey('row_$i'), title: Text('Row $i')),
        ),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(
              find.byKey(const ValueKey('wheel_list')),
            ),
            scrollDelta: const Offset(0, 240),
          ),
        );
        await tester.pumpAndSettle();
        expect(recorder.steps.single.action, RecordedAction.scrollUntilVisible);
        expect(recorder.steps.single.scrollView!.key, 'wheel_list');
        expect(recorder.steps.single.target.issue, isNull);
      },
    );
  });

  testWidgets(
    'accessibility scroll requests use the identified Flutter viewport',
    (tester) async {
      await recording(
        tester,
        SizedBox(
          height: 240,
          child: ListView.builder(
            key: const ValueKey('accessible_list'),
            itemCount: 40,
            itemExtent: 60,
            itemBuilder: (_, i) =>
                ListTile(key: ValueKey('entry_$i'), title: Text('Entry $i')),
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          final rootNode = tester.getSemantics(
            find.byKey(const ValueKey('accessible_list')),
          );
          SemanticsNode? node;
          void visit(SemanticsNode candidate) {
            final data = candidate.getSemanticsData();
            if (data.hasAction(ui.SemanticsAction.scrollDown) ||
                data.hasAction(ui.SemanticsAction.scrollUp)) {
              node = candidate;
            }
            candidate.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(rootNode);
          expect(node, isNotNull);
          final action =
              node!.getSemanticsData().hasAction(ui.SemanticsAction.scrollDown)
              ? ui.SemanticsAction.scrollDown
              : ui.SemanticsAction.scrollUp;
          tester.binding.platformDispatcher.onSemanticsActionEvent!(
            ui.SemanticsActionEvent(
              type: action,
              viewId: tester.view.viewId,
              nodeId: node!.id,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            recorder.steps.single.action,
            RecordedAction.scrollUntilVisible,
          );
          expect(recorder.steps.single.scrollView!.key, 'accessible_list');
        },
      );
    },
  );

  testWidgets(
    'inline hyperlinks record text-range taps inside their keyed paragraph',
    (tester) async {
      var taps = 0;
      final recognizer = TapGestureRecognizer()..onTap = () => taps++;
      addTearDown(recognizer.dispose);
      await recording(
        tester,
        Text.rich(
          key: const ValueKey('legal_text'),
          TextSpan(
            children: [
              const TextSpan(text: 'Read '),
              TextSpan(text: 'Terms', recognizer: recognizer),
              const TextSpan(text: ' first.'),
            ],
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.tapOnText(
            find.textRange.ofSubstring(
              'Terms',
              descendentOf: find.byKey(const ValueKey('legal_text')),
            ),
          );
          expect(taps, 1);
          final step = recorder.steps.single;
          expect(step.action, RecordedAction.tapText);
          expect(step.target.key, 'legal_text');
          expect(step.text, 'Terms');
          expect(jsonEncode(step.toJson()), isNot(contains('position')));
        },
      );
    },
  );

  testWidgets(
    'duplicate inline link text needs an actionable disambiguation error',
    (tester) async {
      final recognizer = TapGestureRecognizer()..onTap = () {};
      addTearDown(recognizer.dispose);
      await recording(
        tester,
        Text.rich(
          key: const ValueKey('links'),
          TextSpan(
            children: [
              TextSpan(text: 'Open', recognizer: recognizer),
              const TextSpan(text: ' or '),
              TextSpan(text: 'Open', recognizer: recognizer),
            ],
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(const ValueKey('links')),
              matching: find.byType(RichText),
            ),
          );
          final box = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 4),
              )
              .single;
          await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
          expect(recorder.steps.single.target.issue, contains('WidgetSpan'));
        },
      );
    },
  );

  testWidgets(
    'accessibility activation of a span records the same text target',
    (tester) async {
      var taps = 0;
      final recognizer = TapGestureRecognizer()..onTap = () => taps++;
      addTearDown(recognizer.dispose);
      await recording(
        tester,
        Text.rich(
          key: const ValueKey('links'),
          TextSpan(
            children: [
              const TextSpan(text: 'Read '),
              TextSpan(text: 'Terms', recognizer: recognizer),
            ],
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          final root = tester.getSemantics(find.byKey(const ValueKey('links')));
          SemanticsNode? link;
          void visit(SemanticsNode node) {
            if (node.label == 'Terms' &&
                node.getSemanticsData().hasAction(ui.SemanticsAction.tap)) {
              link = node;
            }
            node.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(root);
          expect(link, isNotNull);
          tester.binding.platformDispatcher.onSemanticsActionEvent!(
            ui.SemanticsActionEvent(
              type: ui.SemanticsAction.tap,
              viewId: tester.view.viewId,
              nodeId: link!.id,
            ),
          );
          await tester.pump();
          expect(taps, 1);
          expect(recorder.steps.single.action, RecordedAction.tapText);
          expect(
            recorder.steps.single.source,
            ObservationSource.semanticsAction,
          );
        },
      );
    },
  );

  testWidgets(
    'scroll then tap anchors the scroll to the intended lazily built item',
    (tester) async {
      int? selected;
      await recording(
        tester,
        SizedBox(
          height: 240,
          child: ListView.builder(
            key: const ValueKey('products'),
            itemCount: 80,
            itemExtent: 56,
            itemBuilder: (_, i) => ListTile(
              key: ValueKey('product_$i'),
              title: Text('Product $i'),
              onTap: () => selected = i,
            ),
          ),
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.drag(
            find.byKey(const ValueKey('products')),
            const Offset(0, -280),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('product_8')));
          expect(selected, 8);
          expect(recorder.steps.map((s) => s.action), [
            RecordedAction.scrollUntilVisible,
            RecordedAction.tap,
          ]);
          final scroll = recorder.steps.first;
          expect(scroll.scrollView!.key, 'products');
          expect(scroll.scrollDirection, RecordedScrollDirection.down);
          expect(scroll.target.key, 'product_8');
          expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        },
      );
    },
  );

  testWidgets('programmatic scrolling is not misclassified as a user drag', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await recording(
      tester,
      ListView.builder(
        key: const ValueKey('list'),
        controller: controller,
        itemCount: 40,
        itemExtent: 60,
        itemBuilder: (_, i) => Text('Item $i'),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        controller.jumpTo(300);
        await tester.pumpAndSettle();
        expect(recorder.steps, isEmpty);
      },
    );
  });

  testWidgets('long press is recorded as a keyed long press, not a tap', (
    tester,
  ) async {
    var holds = 0;
    await recording(
      tester,
      GestureDetector(
        key: const ValueKey('hold'),
        onLongPress: () => holds++,
        child: const SizedBox(width: 200, height: 100, child: Text('Hold')),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.longPress(find.byKey(const ValueKey('hold')));
        expect(holds, 1);
        expect(recorder.steps.single.action, RecordedAction.longPress);
        expect(recorder.steps.single.target.key, 'hold');
      },
    );
  });
}
