/// Transport types shared by the application and the DevTools extension.
library;

import 'dart:convert';

const recorderProtocolVersion = 8;
const recorderServiceMethod = 'ext.patrol_recorder.command';
const recorderEventKind = 'patrol_recorder.changed';

enum RecordingState { ready, recording, stopped }

enum RecordedAction {
  tap,
  tapText,
  longPress,
  enterText,
  scrollUntilVisible,
  expect,
  unsupported,
}

enum RecordedExpectation { exists, absent, visible, text, count }

class ExpectationSpec {
  ExpectationSpec({required this.kind, this.value, this.timeoutMs = 10000}) {
    if (timeoutMs < 100 || timeoutMs > 120000) {
      throw const FormatException('Expectation timeout_ms must be 100-120000.');
    }
    final valid = switch (kind) {
      RecordedExpectation.text =>
        value is String &&
            (value as String).isNotEmpty &&
            (value as String).length <= 1000,
      RecordedExpectation.count => value is int && (value as int) >= 0,
      _ => value == null,
    };
    if (!valid) {
      throw FormatException('Invalid value for expect ${kind.name}.');
    }
  }

  final RecordedExpectation kind;
  final Object? value;
  final int timeoutMs;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (value != null) 'value': value,
    'timeout_ms': timeoutMs,
  };

  factory ExpectationSpec.fromJson(Map<String, dynamic> json) {
    final kinds = RecordedExpectation.values.where(
      (kind) => kind.name == json['kind'],
    );
    if (kinds.length != 1 ||
        json.keys.any(
          (key) => !{'kind', 'value', 'timeout_ms'}.contains(key),
        ) ||
        json['timeout_ms'] != null && json['timeout_ms'] is! int) {
      throw const FormatException('Unsupported or incomplete expectation.');
    }
    return ExpectationSpec(
      kind: kinds.single,
      value: json['value'],
      timeoutMs: json['timeout_ms'] as int? ?? 10000,
    );
  }
}

enum RecordedScrollDirection { up, down, left, right }

enum SelectorKind {
  key,
  semanticsIdentifier,
  semanticsLabel,
  fieldLabel,
  text,
  richText,
  widgetType,
}

enum ObservationSource {
  authored,
  pointerGesture,
  semanticsAction,
  focusedController,
  scrollNotification,
}

const supportedWidgetTypes = {
  'FilledButton',
  'ElevatedButton',
  'TextButton',
  'OutlinedButton',
  'IconButton',
  'FloatingActionButton',
  'InkWell',
  'GestureDetector',
  'TextField',
  'TextFormField',
  'EditableText',
  'Switch',
  'Checkbox',
  'ListTile',
  'SwitchListTile',
  'CheckboxListTile',
  'InkResponse',
  'RichText',
  'Scrollable',
  'ListView',
  'GridView',
  'CustomScrollView',
  'SingleChildScrollView',
};

class RecorderSelector {
  RecorderSelector(this.kind, this.value) {
    if (value.isEmpty ||
        value.length > 256 ||
        (kind == SelectorKind.widgetType &&
            !supportedWidgetTypes.contains(value))) {
      throw const FormatException('Invalid or unsupported selector.');
    }
  }

  final SelectorKind kind;
  final String value;

  Map<String, Object> toJson() => {'kind': kind.name, 'value': value};

  factory RecorderSelector.fromJson(Map<String, dynamic> json) {
    final kind = SelectorKind.values.where((kind) => kind.name == json['kind']);
    if (kind.length != 1 || json['value'] is! String) {
      throw const FormatException('Invalid selector encoding.');
    }
    return RecorderSelector(kind.single, json['value'] as String);
  }
}

String requireIdentifier(String value, String field) {
  if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
    throw FormatException(
      '$field must be a lowercase identifier (1-64 characters).',
    );
  }
  return value;
}

String screenshotName(String value) {
  var name = value
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (name.isEmpty) return 'screen';
  if (!RegExp(r'^[a-z]').hasMatch(name)) name = 'screen_$name';
  if (name.length > 48) {
    name = name.substring(0, 48).replaceAll(RegExp(r'_+$'), '');
  }
  return name;
}

class RecorderTarget {
  RecorderTarget({
    String? key,
    String? semanticsIdentifier,
    RecorderSelector? selector,
    this.scope,
    this.issue,
  }) : selector =
           selector ??
           (key != null
               ? RecorderSelector(SelectorKind.key, key)
               : semanticsIdentifier != null
               ? RecorderSelector(
                   SelectorKind.semanticsIdentifier,
                   semanticsIdentifier,
                 )
               : null) {
    if ((this.selector == null) != (issue != null) ||
        (issue != null && (issue!.isEmpty || scope != null))) {
      throw const FormatException(
        'A target needs a selector or an unresolved reason.',
      );
    }
  }

  final RecorderSelector? selector;
  final RecorderSelector? scope;
  final String? issue;
  String? get key =>
      selector?.kind == SelectorKind.key ? selector!.value : null;
  String get identity => jsonEncode(toJson());

  Map<String, Object?> toJson() => {
    'selector': selector?.toJson(),
    'scope': scope?.toJson(),
    'issue': issue,
  };

  factory RecorderTarget.fromJson(Map<String, dynamic> json) {
    if ((json['selector'] != null &&
            json['selector'] is! Map<String, dynamic>) ||
        (json['scope'] != null && json['scope'] is! Map<String, dynamic>) ||
        (json['issue'] != null && json['issue'] is! String)) {
      throw const FormatException('Invalid recorder target.');
    }
    return RecorderTarget(
      selector: json['selector'] == null
          ? null
          : RecorderSelector.fromJson(json['selector'] as Map<String, dynamic>),
      scope: json['scope'] == null
          ? null
          : RecorderSelector.fromJson(json['scope'] as Map<String, dynamic>),
      issue: json['issue'] as String?,
    );
  }
}

class RecordedStep {
  RecordedStep({
    required this.id,
    required this.action,
    required this.target,
    this.input,
    this.secret = false,
    this.source = ObservationSource.pointerGesture,
    this.text,
    this.scrollView,
    this.scrollDirection,
    this.expectation,
  }) {
    requireIdentifier(id, 'Step ID');
    if (action == RecordedAction.expect) {
      if (expectation == null || target.selector == null) {
        throw const FormatException(
          'Expect requires a resolved target and expectation.',
        );
      }
    } else if (expectation != null) {
      throw const FormatException(
        'Only expect steps can contain an expectation.',
      );
    }
    if (action == RecordedAction.enterText) {
      if (input == null) {
        throw const FormatException('Text entry requires an input reference.');
      }
      requireIdentifier(input!, 'Input reference');
    } else if (input != null || secret) {
      throw const FormatException('A tap cannot contain input data.');
    }
    if (action == RecordedAction.tapText) {
      if (text == null || text!.trim().isEmpty || text!.length > 256) {
        throw const FormatException(
          'A text-span tap needs unique, nonempty link text.',
        );
      }
    } else if (text != null) {
      throw const FormatException(
        'Only a text-span tap can contain link text.',
      );
    }
    if (action == RecordedAction.scrollUntilVisible) {
      // Without a viewport selector, replay discovers the Scrollable from the
      // resolved destination target, so one of the two must be identified.
      if (scrollDirection == null ||
          scrollView != null && scrollView!.selector == null ||
          scrollView == null && target.selector == null) {
        throw const FormatException(
          'A scroll needs a direction and an identified viewport or destination.',
        );
      }
    } else if (scrollView != null || scrollDirection != null) {
      throw const FormatException(
        'Only scroll actions can contain a viewport or direction.',
      );
    }
  }

  final String id;
  final RecordedAction action;
  final RecorderTarget target;
  final String? input;
  final bool secret;
  final ObservationSource source;
  final String? text;
  final RecorderTarget? scrollView;
  final RecordedScrollDirection? scrollDirection;
  final ExpectationSpec? expectation;

  Map<String, Object?> toJson() => {
    'id': id,
    'action': action.name,
    'target': target.toJson(),
    'input': input,
    'secret': secret,
    'source': source.name,
    if (text != null) 'text': text,
    if (scrollView != null) 'scrollView': scrollView!.toJson(),
    if (scrollDirection != null) 'scrollDirection': scrollDirection!.name,
    if (expectation != null) 'expectation': expectation!.toJson(),
  };

  factory RecordedStep.fromJson(Map<String, dynamic> json) {
    final action = switch (json['action']) {
      'tap' => RecordedAction.tap,
      'tapText' => RecordedAction.tapText,
      'longPress' => RecordedAction.longPress,
      'scrollUntilVisible' => RecordedAction.scrollUntilVisible,
      'enterText' => RecordedAction.enterText,
      'expect' => RecordedAction.expect,
      'unsupported' => RecordedAction.unsupported,
      _ => throw const FormatException('Unsupported recorded action.'),
    };
    if (json['id'] is! String ||
        json['target'] is! Map<String, dynamic> ||
        json['secret'] is! bool ||
        (json['input'] != null && json['input'] is! String) ||
        (json['text'] != null && json['text'] is! String) ||
        (json['expectation'] != null &&
            json['expectation'] is! Map<String, dynamic>) ||
        (json['scrollView'] != null &&
            json['scrollView'] is! Map<String, dynamic>)) {
      throw const FormatException('Invalid recorded step.');
    }
    final sources = ObservationSource.values.where(
      (s) => s.name == json['source'],
    );
    if (sources.length != 1) {
      throw const FormatException('Invalid observation source.');
    }
    final directions = RecordedScrollDirection.values.where(
      (d) => d.name == json['scrollDirection'],
    );
    if (json['scrollDirection'] != null && directions.length != 1) {
      throw const FormatException('Invalid scroll direction.');
    }
    return RecordedStep(
      id: json['id'] as String,
      action: action,
      target: RecorderTarget.fromJson(json['target'] as Map<String, dynamic>),
      input: json['input'] as String?,
      secret: json['secret'] as bool,
      source: sources.single,
      text: json['text'] as String?,
      scrollView: json['scrollView'] == null
          ? null
          : RecorderTarget.fromJson(json['scrollView'] as Map<String, dynamic>),
      scrollDirection: directions.isEmpty ? null : directions.single,
      expectation: json['expectation'] == null
          ? null
          : ExpectationSpec.fromJson(
              json['expectation'] as Map<String, dynamic>,
            ),
    );
  }
}
