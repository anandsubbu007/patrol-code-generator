import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

import 'support/recording.dart';

class _CustomSurface extends StatelessWidget {
  const _CustomSurface({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            TapGestureRecognizer.new,
            (recognizer) => recognizer.onTap = onTap,
          ),
    },
    child: const SizedBox(width: 100, height: 60, child: Text('Custom action')),
  );
}

void main() {
  testWidgets('custom recognizer surface is found without a widget-name list', (
    tester,
  ) async {
    var taps = 0;
    await recording(
      tester,
      _CustomSurface(key: const ValueKey('custom'), onTap: () => taps++),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Custom action'));
        expect(taps, 1);
        expect(recorder.steps.single.target.key, 'custom');
        expect(
          patrolCode(recorder.steps),
          r'await $(const ValueKey("custom")).tap();',
        );
      },
    );
  });

  testWidgets('missing keys suggest the InkWell owner, not its text leaf', (
    tester,
  ) async {
    await recording(
      tester,
      Column(
        children: [
          for (var i = 0; i < 2; i++)
            InkWell(
              onTap: () {},
              child: const Card(
                child: SizedBox(width: 100, height: 60, child: Text('Same')),
              ),
            ),
          const SizedBox(key: ValueKey('ink_well_1')),
        ],
      ),
      (recorder) async {
        recorder.configure(addKey: true);
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Same').first);
        expect(recorder.steps.single.target.selector, isNull);
        final suggestions = recorder.snapshot()['keySuggestions']! as List;
        expect(suggestions, hasLength(1));
        expect((suggestions.single as Map)['widget'], 'InkWell');
        expect((suggestions.single as Map)['key'], 'ink_well_2');
        expect(find.byKey(const ValueKey('ink_well_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('ink_well_2')), findsNothing);
        await tester.tap(find.text('Same').last);
        final both = recorder.snapshot()['keySuggestions']! as List;
        expect(both, hasLength(2));
        expect((both.first as Map)['tree'], isNot((both.last as Map)['tree']));
        expect((both.first as Map)['key'], isNot((both.last as Map)['key']));
      },
    );
  });

  testWidgets('semantics-only actions are not invented for pointer taps', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    await recording(
      tester,
      Semantics(
        key: const ValueKey('semantic'),
        onTap: () => taps++,
        onLongPress: () => holds++,
        child: const Text('Accessible action'),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Accessible action'));
        expect(taps, 0);
        expect(recorder.steps, isEmpty);
        final node = tester.getSemantics(
          find.byKey(const ValueKey('semantic')),
        );
        tester.binding.platformDispatcher.onSemanticsActionEvent!(
          ui.SemanticsActionEvent(
            type: ui.SemanticsAction.longPress,
            viewId: tester.view.viewId,
            nodeId: node.id,
          ),
        );
        await tester.pump();
        expect(holds, 1);
        expect(recorder.steps.single.action, RecordedAction.longPress);
        expect(recorder.steps.single.target.key, 'semantic');
      },
    );
  });

  testWidgets('key suggestions are opt-in', (tester) async {
    await recording(
      tester,
      Column(
        children: [
          for (var i = 0; i < 2; i++)
            InkWell(onTap: () {}, child: const Text('Same')),
        ],
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        await tester.tap(find.text('Same').first);
        expect(recorder.snapshot()['keySuggestions'], isEmpty);
      },
    );
  });

  testWidgets('text and component picking resolve different tree nodes', (
    tester,
  ) async {
    await recording(
      tester,
      InkWell(
        key: const ValueKey('action'),
        onTap: () {},
        child: const Text('Label', key: ValueKey('label')),
      ),
      (recorder) async {
        recorder.start();
        await tester.pump();
        recorder.beginSelection(text: true);
        await tester.pump();
        await tester.tapAt(tester.getCenter(find.text('Label')));
        expect((recorder.snapshot()['selection'] as Map)['selector'], {
          'kind': 'key',
          'value': 'label',
        });
        recorder.cancelSelection();
        recorder.beginSelection();
        await tester.pump();
        await tester.tapAt(tester.getCenter(find.text('Label')));
        expect((recorder.snapshot()['selection'] as Map)['selector'], {
          'kind': 'key',
          'value': 'action',
        });
        recorder.cancelSelection();
      },
    );
  });
}
