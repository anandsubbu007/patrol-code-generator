import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

import 'support/recording.dart';

/// A design-system button: the key is on the wrapper, not on the InkWell.
class _AppButton extends StatelessWidget {
  const _AppButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: Text(label)),
    ),
  );
}

Widget _rows(int count, {Key? key, Widget Function(int)? row}) =>
    ListView.builder(
      key: key,
      itemCount: count,
      itemExtent: 56,
      itemBuilder: (_, i) => row?.call(i) ?? Text('Item'),
    );

void main() {
  test('a scroll needs an identified viewport or destination', () {
    RecordedStep scroll(RecorderTarget target, RecorderTarget? view) =>
        RecordedStep(
          id: 'step_0001',
          action: RecordedAction.scrollUntilVisible,
          target: target,
          scrollView: view,
          scrollDirection: RecordedScrollDirection.down,
        );
    expect(scroll(RecorderTarget(key: 'row_9'), null).scrollView, isNull);
    expect(
      scroll(
        RecorderTarget(issue: 'none'),
        RecorderTarget(key: 'feed'),
      ).scrollView!.key,
      'feed',
    );
    expect(
      () => scroll(RecorderTarget(issue: 'none'), null),
      throwsFormatException,
    );
    expect(
      () => scroll(RecorderTarget(key: 'row_9'), RecorderTarget(issue: 'x')),
      throwsFormatException,
    );
    final json = scroll(RecorderTarget(key: 'row_9'), null).toJson();
    expect(json.containsKey('scrollView'), isFalse);
    expect(
      RecordedStep.fromJson(json).scrollDirection,
      RecordedScrollDirection.down,
    );
  });

  testWidgets('text inside a keyed wrapper records the wrapper key', (
    tester,
  ) async {
    var saved = 0;
    await recording(
      tester,
      Column(
        children: [
          _AppButton(
            key: const ValueKey('save_action'),
            label: 'Save',
            onTap: () => saved++,
          ),
          _AppButton(label: 'Cancel', onTap: () {}),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.tap(find.text('Cancel'));
        expect(saved, 1);
        expect(recorder.steps.first.target.key, 'save_action');
        // Without any key, the visible label remains the fallback.
        expect(recorder.steps.last.target.key, isNull);
        expect(recorder.steps.last.target.selector!.value, 'Cancel');
      },
    );
  });

  testWidgets('a key wrapping several controls is not claimed by one', (
    tester,
  ) async {
    await recording(
      tester,
      Container(
        key: const ValueKey('toolbar'),
        child: Row(
          children: [
            InkWell(onTap: () {}, child: const Text('Left')),
            InkWell(onTap: () {}, child: const Text('Right')),
          ],
        ),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Left'));
        final target = recorder.steps.single.target;
        expect(target.key, isNull);
        expect(target.selector!.value, 'Left');
      },
    );
  });

  testWidgets('a nested control key is not used for its parent action', (
    tester,
  ) async {
    var opened = 0;
    var deleted = 0;
    await recording(
      tester,
      ListTile(
        title: const Text('Open settings'),
        onTap: () => opened++,
        trailing: IconButton(
          key: const ValueKey('delete_row'),
          icon: const Icon(Icons.delete),
          onPressed: () => deleted++,
        ),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Open settings'));
        await tester.tap(find.byKey(const ValueKey('delete_row')));
        expect((opened, deleted), (1, 1));
        expect(recorder.steps.first.target.key, isNull);
        expect(recorder.steps.first.target.selector!.value, 'Open settings');
        expect(recorder.steps.last.target.key, 'delete_row');
      },
    );
  });

  testWidgets('back-and-forth scrolling records one net scroll to the tap', (
    tester,
  ) async {
    int? selected;
    await recording(
      tester,
      SizedBox(
        height: 240,
        child: _rows(
          80,
          key: const ValueKey('feed'),
          row: (i) => ListTile(
            key: ValueKey('product_$i'),
            title: Text('Product $i'),
            onTap: () => selected = i,
          ),
        ),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        final feed = find.byKey(const ValueKey('feed'));
        await tester.drag(feed, const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.drag(feed, const Offset(0, 200));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('product_9')));
        expect(selected, 9);
        expect(recorder.steps.map((s) => s.action), [
          RecordedAction.scrollUntilVisible,
          RecordedAction.tap,
        ]);
        final scroll = recorder.steps.first;
        expect(scroll.scrollDirection, RecordedScrollDirection.down);
        expect(scroll.scrollView!.key, 'feed');
        expect(scroll.target.key, 'product_9');
      },
    );
  });

  testWidgets('scrolling away and back again records nothing', (tester) async {
    await recording(
      tester,
      SizedBox(
        height: 240,
        child: _rows(
          40,
          key: const ValueKey('feed'),
          row: (i) => Text('Row $i', key: ValueKey('row_$i')),
        ),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        final feed = find.byKey(const ValueKey('feed'));
        await tester.drag(feed, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(recorder.steps, hasLength(1));
        await tester.drag(feed, const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(recorder.steps, isEmpty);
      },
    );
  });

  testWidgets('an unkeyed scroll view is replaced by a keyed destination', (
    tester,
  ) async {
    await recording(
      tester,
      Row(
        children: [
          Expanded(
            child: _rows(
              60,
              row: (i) => i == 30
                  ? ListTile(
                      key: const ValueKey('promo_30'),
                      title: const Text('Item'),
                      onTap: () {},
                    )
                  : const Text('Item'),
            ),
          ),
          Expanded(child: _rows(60)),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1400),
        );
        await tester.pumpAndSettle();
        // The visible keyed item identifies the destination; no view key needed.
        final scroll = recorder.steps.single;
        expect(scroll.action, RecordedAction.scrollUntilVisible);
        expect(scroll.scrollView, isNull);
        expect(scroll.target.key, 'promo_30');
        expect(scroll.scrollDirection, RecordedScrollDirection.down);
      },
    );
  });

  testWidgets(
    'an unidentifiable scroll needs review until a tap identifies its objective',
    (tester) async {
      var tapped = 0;
      await recording(
        tester,
        Row(
          children: [
            Expanded(
              child: _rows(
                60,
                row: (i) => i == 30
                    ? Semantics(
                        identifier: 'favorite_30',
                        child: IconButton(
                          icon: const Icon(Icons.star),
                          onPressed: () => tapped++,
                        ),
                      )
                    : const Text('Item'),
              ),
            ),
            Expanded(child: _rows(60)),
          ],
        ),
        (recorder) async {
          recorder.start();
          await tester.pump();
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -1400),
          );
          await tester.pumpAndSettle();
          expect(recorder.steps.single.action, RecordedAction.unsupported);
          expect(recorder.steps.single.target.issue, contains('Tap the item'));
          await tester.tap(find.byIcon(Icons.star));
          expect(tapped, 1);
          expect(recorder.steps.map((s) => s.action), [
            RecordedAction.scrollUntilVisible,
            RecordedAction.tap,
          ]);
          final scroll = recorder.steps.first;
          expect(scroll.scrollView, isNull);
          expect(scroll.scrollDirection, RecordedScrollDirection.down);
          expect(scroll.target.selector!.value, 'favorite_30');
          expect(recorder.steps.every((s) => s.target.issue == null), isTrue);
        },
      );
    },
  );
}
