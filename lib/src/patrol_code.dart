import 'dart:convert';

import '../model.dart';

String _literal(String value) => jsonEncode(value).replaceAll(r'$', r'\$');

String _input(String name) =>
    const {
      'assert',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'do',
      'else',
      'enum',
      'extends',
      'false',
      'final',
      'finally',
      'for',
      'if',
      'in',
      'is',
      'new',
      'null',
      'rethrow',
      'return',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'var',
      'void',
      'while',
      'with',
      'await',
      'yield',
    }.contains(name)
    ? '${name}Value'
    : name;

String _selector(RecorderSelector selector) {
  final value = _literal(selector.value);
  return switch (selector.kind) {
    SelectorKind.key => 'find.byKey(const ValueKey($value))',
    SelectorKind.text => 'find.text($value)',
    SelectorKind.richText => 'find.text($value, findRichText: true)',
    SelectorKind.semanticsIdentifier =>
      'find.bySemanticsIdentifier(RegExp(${_literal('^${RegExp.escape(selector.value)}\$')}))',
    SelectorKind.semanticsLabel =>
      'find.bySemanticsLabel(RegExp(${_literal('^${RegExp.escape(selector.value)}\$')}))',
    SelectorKind.fieldLabel =>
      'find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == $value)',
    SelectorKind.widgetType => 'find.byType(${selector.value})',
  };
}

String _finder(RecorderTarget target) {
  if (target.selector == null) {
    throw FormatException(target.issue ?? 'Unresolved target.');
  }
  final finder = _selector(target.selector!);
  return target.scope == null
      ? finder
      : 'find.descendant(of: ${_selector(target.scope!)}, matching: $finder)';
}

String _patrol(RecorderTarget target) {
  if (target.scope == null && target.key != null) {
    return '\$(const ValueKey(${_literal(target.key!)}))';
  }
  if (target.scope == null && target.selector?.kind == SelectorKind.text) {
    return '\$(${_literal(target.selector!.value)})';
  }
  return '\$(${_finder(target)})';
}

/// Statements to paste inside a Patrol test callback with tester `$`.
///
/// Input identifiers are supplied by the test author; recorded values never
/// enter this output. Unresolved actions must be reviewed, not silently skipped.
String patrolCode(Iterable<RecordedStep> steps) => steps
    .map((step) {
      if (step.action == RecordedAction.unsupported) {
        throw FormatException('${step.id}: Unsupported action needs review.');
      }
      final target = _patrol(step.target);
      switch (step.action) {
        case RecordedAction.tap:
          return 'await $target.tap();';
        case RecordedAction.longPress:
          return 'await $target.longPress();';
        case RecordedAction.enterText:
          return 'await \$.enterText(${_finder(step.target)}, ${_input(step.input!)}, enablePatrolLog: false);';
        case RecordedAction.scrollUntilVisible:
          if (step.scrollView == null) {
            throw FormatException(
              '${step.id}: Add a stable key to the scroll view and re-record. '
              'Choosing the first scrollable could replay in the wrong viewport.',
            );
          }
          final view =
              'view: find.descendant(of: ${_finder(step.scrollView!)}, matching: find.byType(Scrollable), matchRoot: true), ';
          return 'await $target.scrollTo(${view}scrollDirection: AxisDirection.${step.scrollDirection!.name});';
        case RecordedAction.tapText:
          return 'await \$.tester.tapOnText(find.textRange.ofSubstring(${_literal(step.text!)}, descendentOf: ${_finder(step.target)}));\nawait \$.pump();';
        case RecordedAction.expect:
          final expectation = step.expectation!;
          final timeout =
              'const Duration(milliseconds: ${expectation.timeoutMs})';
          final count = expectation.kind == RecordedExpectation.absent
              ? 0
              : expectation.value;
          final textTarget =
              '\$(find.descendant(of: ${_finder(step.target)}, matching: find.byType(RichText), matchRoot: true))';
          return switch (expectation.kind) {
            RecordedExpectation.visible =>
              'await $target.waitUntilVisible(timeout: $timeout);',
            RecordedExpectation.exists =>
              'await $target.waitUntilExists(timeout: $timeout);\nexpect($target, findsOneWidget);',
            RecordedExpectation.absent || RecordedExpectation.count =>
              'for (var elapsed = 0; elapsed < ${expectation.timeoutMs} && $target.evaluate().length != $count; elapsed += 100) {\n'
                  '  await \$.tester.pump(const Duration(milliseconds: 100));\n'
                  '}\nexpect($target, findsNWidgets($count));',
            RecordedExpectation.text =>
              'await $textTarget.waitUntilVisible(timeout: $timeout);\n'
                  'expect($textTarget, findsOneWidget);\n'
                  'for (var elapsed = 0; elapsed < ${expectation.timeoutMs} && $textTarget.text != ${_literal(expectation.value! as String)}; elapsed += 100) {\n'
                  '  await \$.tester.pump(const Duration(milliseconds: 100));\n'
                  '}\nexpect($textTarget.text, ${_literal(expectation.value! as String)});',
          };
        case RecordedAction.unsupported:
          throw StateError('Unsupported action.');
      }
    })
    .join('\n');
