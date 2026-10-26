import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

RecordedStep step(
  RecordedAction action, {
  RecorderTarget? target,
  String? input,
  ExpectationSpec? expectation,
}) => RecordedStep(
  id: 'step_0001',
  action: action,
  target: target ?? RecorderTarget(key: 'save'),
  input: input,
  expectation: expectation,
);

void main() {
  test('fifteen simple actions produce fifteen lines, not a framework', () {
    final code = patrolCode(List.generate(15, (_) => step(RecordedAction.tap)));
    expect(code.split('\n'), hasLength(15));
    expect(code.split('\n').first, r'await $(const ValueKey("save")).tap();');
    expect(code, isNot(contains('try {')));
  });

  test('unresolved and unsupported actions block copying', () {
    expect(
      () => patrolCode([
        step(RecordedAction.tap, target: RecorderTarget(issue: 'Ambiguous')),
      ]),
      throwsFormatException,
    );
    expect(
      () => patrolCode([step(RecordedAction.unsupported)]),
      throwsFormatException,
    );
  });

  test('literals escape interpolation, quotes, newlines and slashes', () {
    expect(
      patrolCode([
        step(RecordedAction.tap, target: RecorderTarget(key: 'a"\n\\\$b')),
      ]),
      r'await $(const ValueKey("a\"\n\\\$b")).tap();',
    );
  });

  test('input code contains only a reference and disables Patrol logging', () {
    expect(
      patrolCode([step(RecordedAction.enterText, input: 'email')]),
      r'await $.enterText(find.byKey(const ValueKey("save")), email, enablePatrolLog: false);',
    );
  });

  test('unidentified scroll view blocks first-scrollable guessing', () {
    expect(
      () => patrolCode([
        RecordedStep(
          id: 'step_0001',
          action: RecordedAction.scrollUntilVisible,
          target: RecorderTarget(key: 'row'),
          scrollDirection: RecordedScrollDirection.down,
        ),
      ]),
      throwsFormatException,
    );
  });

  test(
    'emitted code compiles and replays against the actual Patrol API',
    () async {
      final actions = [
        step(
          RecordedAction.enterText,
          target: RecorderTarget(key: 'email'),
          input: 'email',
        ),
        step(RecordedAction.tap),
        step(RecordedAction.longPress),
        step(
          RecordedAction.expect,
          expectation: ExpectationSpec(kind: RecordedExpectation.exists),
        ),
        step(
          RecordedAction.expect,
          expectation: ExpectationSpec(kind: RecordedExpectation.visible),
        ),
        step(
          RecordedAction.expect,
          expectation: ExpectationSpec(
            kind: RecordedExpectation.text,
            value: 'Saved',
          ),
        ),
        step(
          RecordedAction.expect,
          expectation: ExpectationSpec(
            kind: RecordedExpectation.count,
            value: 1,
          ),
        ),
        step(
          RecordedAction.expect,
          target: RecorderTarget(key: 'missing'),
          expectation: ExpectationSpec(kind: RecordedExpectation.absent),
        ),
      ];
      final directory = await Directory('test').createTemp('direct_patrol_');
      final otherActions = [
        step(
          RecordedAction.tap,
          target: RecorderTarget(
            selector: RecorderSelector(
              SelectorKind.semanticsIdentifier,
              'semantic_action',
            ),
          ),
        ),
        step(
          RecordedAction.tap,
          target: RecorderTarget(
            selector: RecorderSelector(
              SelectorKind.semanticsLabel,
              'Semantic action',
            ),
          ),
        ),
        step(
          RecordedAction.enterText,
          target: RecorderTarget(
            selector: RecorderSelector(SelectorKind.fieldLabel, 'Email'),
          ),
          input: 'email',
        ),
        step(
          RecordedAction.tap,
          target: RecorderTarget(
            selector: RecorderSelector(SelectorKind.text, 'Save'),
            scope: RecorderSelector(SelectorKind.key, 'toolbar'),
          ),
        ),
        RecordedStep(
          id: 'step_0001',
          action: RecordedAction.tapText,
          target: RecorderTarget(key: 'paragraph'),
          text: 'Link',
        ),
        RecordedStep(
          id: 'step_0001',
          action: RecordedAction.scrollUntilVisible,
          target: RecorderTarget(key: 'row_25'),
          scrollView: RecorderTarget(key: 'feed'),
          scrollDirection: RecordedScrollDirection.down,
        ),
        step(RecordedAction.tap, target: RecorderTarget(key: 'row_25')),
      ];
      final delayedExpectations = [
        step(
          RecordedAction.expect,
          target: RecorderTarget(key: 'badge'),
          expectation: ExpectationSpec(
            kind: RecordedExpectation.count,
            value: 1,
          ),
        ),
        step(
          RecordedAction.expect,
          target: RecorderTarget(key: 'transient'),
          expectation: ExpectationSpec(kind: RecordedExpectation.absent),
        ),
        step(
          RecordedAction.expect,
          target: RecorderTarget(key: 'status'),
          expectation: ExpectationSpec(
            kind: RecordedExpectation.text,
            value: 'Done',
          ),
        ),
      ];
      try {
        final replay = File('${directory.path}/replay_test.dart');
        await replay.writeAsString('''
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
void main() {
  patrolWidgetTest('direct output replays', (\$) async {
    var taps = 0;
    var holds = 0;
    const email = 'demo@example.invalid';
    await \$.pumpWidgetAndSettle(MaterialApp(home: Scaffold(body: Column(children: [
      const TextField(key: ValueKey('email')),
      GestureDetector(key: const ValueKey('save'), onTap: () => taps++, onLongPress: () => holds++, child: const Text('Saved')),
    ]))));
    ${patrolCode(actions)}
    expect(taps, 1);
    expect(holds, 1);
    expect(find.text(email), findsOneWidget);
  });
  patrolWidgetTest('scoped selectors, semantics, links and lazy scrolling replay', (\$) async {
    var taps = 0;
    var selected = -1;
    const email = 'demo@example.invalid';
    final link = TapGestureRecognizer()..onTap = () => taps++;
    addTearDown(link.dispose);
    await \$.pumpWidgetAndSettle(MaterialApp(home: Scaffold(body: Column(children: [
      Semantics(identifier: 'semantic_action', label: 'Semantic action', excludeSemantics: true,
        child: GestureDetector(onTap: () => taps++, child: const Text('Semantic target'))),
      const TextField(decoration: InputDecoration(labelText: 'Email')),
      Row(key: const ValueKey('toolbar'), children: [TextButton(onPressed: () => taps++, child: const Text('Save'))]),
      const Text('Save'),
      Text.rich(TextSpan(children: [TextSpan(text: 'Link', recognizer: link)]), key: const ValueKey('paragraph')),
      SizedBox(height: 150, child: Row(children: [
        Expanded(child: ListView.builder(itemExtent: 50, itemCount: 40, itemBuilder: (_, i) => Text('Other \$i'))),
        Expanded(child: ListView.builder(key: const ValueKey('feed'), itemExtent: 50, itemCount: 40,
          itemBuilder: (_, i) => ListTile(key: ValueKey('row_\$i'), title: Text('Row \$i'), onTap: () => selected = i))),
      ])),
    ]))));
    ${patrolCode(otherActions)}
    expect(taps, 4);
    expect(selected, 25);
    expect(find.text(email), findsOneWidget);
    final other = \$.tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(other.position.pixels, 0);
  });
  patrolWidgetTest('expectations wait for delayed changes', (\$) async {
    var initialized = false;
    var badge = false;
    var transient = true;
    var status = 'Pending';
    final timers = <Timer>[];
    addTearDown(() { for (final timer in timers) { timer.cancel(); } });
    await \$.pumpWidgetAndSettle(MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      if (!initialized) {
        initialized = true;
        timers.add(Timer(const Duration(milliseconds: 200), () => setState(() => badge = true)));
        timers.add(Timer(const Duration(milliseconds: 400), () => setState(() => transient = false)));
        timers.add(Timer(const Duration(milliseconds: 600), () => setState(() => status = 'Done')));
      }
      return Column(children: [
        if (badge) const Text('Badge', key: ValueKey('badge')),
        if (transient) const Text('Transient', key: ValueKey('transient')),
        Text(status, key: const ValueKey('status')),
      ]);
    })));
    ${patrolCode(delayedExpectations)}
  });
}
''');
        final result = await Process.run('flutter', [
          'test',
          '--reporter',
          'expanded',
          replay.path,
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
