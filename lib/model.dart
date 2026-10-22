/// Transport types shared by the application and the DevTools extension.
library;

import 'dart:convert';

const recorderProtocolVersion = 5;
const recorderServiceMethod = 'ext.patrol_recorder.command';
const recorderEventKind = 'patrol_recorder.changed';

enum RecordingState { ready, recording, stopped }

enum RecordedAction {
  tap,
  tapText,
  longPress,
  enterText,
  scrollUntilVisible,
  unsupported,
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
  }) {
    requireIdentifier(id, 'Step ID');
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
      if (scrollView?.selector == null || scrollDirection == null) {
        throw const FormatException(
          'A scroll needs an identified viewport and direction.',
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
  };

  factory RecordedStep.fromJson(Map<String, dynamic> json) {
    final action = switch (json['action']) {
      'tap' => RecordedAction.tap,
      'tapText' => RecordedAction.tapText,
      'longPress' => RecordedAction.longPress,
      'scrollUntilVisible' => RecordedAction.scrollUntilVisible,
      'enterText' => RecordedAction.enterText,
      'unsupported' => RecordedAction.unsupported,
      _ => throw const FormatException('Unsupported recorded action.'),
    };
    if (json['id'] is! String ||
        json['target'] is! Map<String, dynamic> ||
        json['secret'] is! bool ||
        (json['input'] != null && json['input'] is! String) ||
        (json['text'] != null && json['text'] is! String) ||
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
    );
  }
}

/// Optional legacy/project-identification hints. New YAML contains no bootstrap or values.
class RecorderAppConfig {
  RecorderAppConfig({
    this.appImport,
    this.appBuilder,
    Map<String, Map<String, String>> safeProfiles = const {'demo': {}},
  }) : safeProfiles = Map.unmodifiable({
         for (final entry in safeProfiles.entries)
           entry.key: Map<String, String>.unmodifiable(entry.value),
       }) {
    if ((appImport == null) != (appBuilder == null) ||
        appImport != null &&
            (!RegExp(r'^package:[a-z][a-z0-9_]*/[a-zA-Z0-9_/]+\.dart$')
                    .hasMatch(appImport!) ||
                !RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(appBuilder!))) {
      throw const FormatException(
        'Configure a package Dart import and a public no-argument widget builder.',
      );
    }
    if (safeProfiles.isEmpty) {
      throw const FormatException(
        'At least one safe data profile is required.',
      );
    }
    for (final entry in safeProfiles.entries) {
      requireIdentifier(entry.key, 'Profile name');
      for (final key in entry.value.keys) {
        requireIdentifier(key, 'Input name');
        if (RegExp(r'password|token|secret|credential|api_key').hasMatch(key)) {
          throw const FormatException(
            'Credential fields cannot have recorded defaults.',
          );
        }
      }
    }
  }

  final String? appImport;
  final String? appBuilder;
  final Map<String, Map<String, String>> safeProfiles;

  Map<String, Object?> toJson() => {
    'appImport': appImport,
    'appBuilder': appBuilder,
    'safeProfiles': safeProfiles,
  };

  factory RecorderAppConfig.fromJson(Map<String, dynamic> json) {
    if (json['appImport'] != null && json['appImport'] is! String ||
        json['appBuilder'] != null && json['appBuilder'] is! String ||
        json['safeProfiles'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid app configuration.');
    }
    final profiles = <String, Map<String, String>>{};
    for (final entry
        in (json['safeProfiles'] as Map<String, dynamic>).entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw const FormatException('Invalid profile.');
      }
      final fields = <String, String>{};
      for (final field in (entry.value as Map<String, dynamic>).entries) {
        if (field.value is! String) {
          throw const FormatException('M1 profile values must be strings.');
        }
        fields[field.key] = field.value as String;
      }
      profiles[entry.key] = fields;
    }
    return RecorderAppConfig(
      appImport: json['appImport'] as String?,
      appBuilder: json['appBuilder'] as String?,
      safeProfiles: profiles,
    );
  }
}
