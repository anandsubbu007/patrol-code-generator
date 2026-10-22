import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_style/dart_style.dart';
import 'package:patrol_recorder/model.dart';
import 'package:yaml/yaml.dart';

String dartLiteral(String value) => jsonEncode(value).replaceAll(r'$', r'\$');

String validateRelativePath(String value) {
  if (value.isEmpty ||
      value.length > 200 ||
      !RegExp(r'^[a-zA-Z0-9_./-]+$').hasMatch(value) ||
      value
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw const FormatException(
      'Use a relative path without traversal, empty segments, or special characters.',
    );
  }
  return value;
}

class ExportConfig {
  ExportConfig({
    this.outputDirectory = 'patrol_test/recorded_journeys',
    this.journeyId = 'login',
    this.caseId = 'sign_in',
    this.caseName = 'Sign in with demonstration profile',
    this.profile = 'demo',
  }) {
    validateRelativePath(outputDirectory);
    requireIdentifier(journeyId, 'Journey ID');
    requireIdentifier(caseId, 'Case ID');
    requireIdentifier(profile, 'Profile name');
    if (caseName.trim().isEmpty ||
        caseName.length > 120 ||
        caseName.codeUnits.any((c) => c < 32)) {
      throw const FormatException(
        'Case name must contain 1-120 printable characters.',
      );
    }
  }

  final String outputDirectory;
  final String journeyId;
  final String caseId;
  final String caseName;
  final String profile;

  String get directory => '$outputDirectory/$journeyId';
  String get testPath => '$directory/${journeyId}_test.dart';
  String get tag => 'recorder_${journeyId}_$caseId';

  String command({bool singleCase = true, bool web = true}) =>
      'patrol test --target $testPath${singleCase ? ' --tags $tag' : ''}'
      ' --dart-define RECORDER_PROFILE=$profile'
      '${web ? ' --device chrome --web-headless' : ''}';

  String toYaml() =>
      '''
schema_version: 1
output_directory: ${jsonEncode(outputDirectory)}
journey_id: ${jsonEncode(journeyId)}
case_id: ${jsonEncode(caseId)}
case_name: ${jsonEncode(caseName)}
profile: ${jsonEncode(profile)}
''';

  factory ExportConfig.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap || document['schema_version'] != 1) {
      throw const FormatException(
        'recorder_config.yaml requires schema_version: 1.',
      );
    }
    const keys = {
      'schema_version',
      'output_directory',
      'journey_id',
      'case_id',
      'case_name',
      'profile',
    };
    if (document.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('Unknown recorder configuration field.');
    }
    String field(String key, String fallback) {
      final value = document[key];
      if (value == null) return fallback;
      if (value is! String) {
        throw FormatException('Configuration field $key must be a string.');
      }
      return value;
    }

    return ExportConfig(
      outputDirectory: field(
        'output_directory',
        'patrol_test/recorded_journeys',
      ),
      journeyId: field('journey_id', 'login'),
      caseId: field('case_id', 'sign_in'),
      caseName: field('case_name', 'Sign in with demonstration profile'),
      profile: field('profile', 'demo'),
    );
  }
}

class GeneratedJourney {
  const GeneratedJourney({
    required this.test,
    required this.data,
    required this.config,
  });
  final String test;
  final String data;
  final ExportConfig config;

  Map<String, Uint8List> files() => {
    config.testPath: Uint8List.fromList(utf8.encode(test)),
    '${config.directory}/${config.journeyId}_data.dart': Uint8List.fromList(
      utf8.encode(data),
    ),
    'recorder_config.yaml': Uint8List.fromList(utf8.encode(config.toYaml())),
  };
}

GeneratedJourney generateJourney({
  required List<RecordedStep> steps,
  required RecorderAppConfig app,
  required ExportConfig config,
}) {
  if (steps.isEmpty) {
    throw const FormatException('Record at least one supported action.');
  }
  for (final step in steps) {
    if (step.target.issue != null) {
      throw FormatException('${step.id}: ${step.target.issue}');
    }
  }
  if (!app.safeProfiles.containsKey(config.profile)) {
    throw const FormatException(
      'The selected profile is not declared by the example/app.',
    );
  }
  final inputKinds = <String, bool>{};
  for (final step in steps.where((s) => s.input != null)) {
    final previous = inputKinds[step.input];
    if (previous != null && previous != step.secret) {
      throw const FormatException(
        'An input cannot be both secret and non-secret.',
      );
    }
    inputKinds[step.input!] = step.secret;
  }
  final plain = inputKinds.keys.where((key) => !inputKinds[key]!).toList()
    ..sort();
  final secrets = inputKinds.keys.where((key) => inputKinds[key]!).toList()
    ..sort();
  final formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );
  final profileEntries = app.safeProfiles.entries
      .map((profile) {
        final values = plain
            .map(
              (key) =>
                  '${dartLiteral(key)}: ${dartLiteral(profile.value[key] ?? '')}',
            )
            .join(',');
        return '${dartLiteral(profile.key)}: {$values}';
      })
      .join(',');
  final secretEntries = secrets
      .map(
        (key) =>
            '${dartLiteral(key)}: const String.fromEnvironment(${dartLiteral('RECORDER_SECRET_${key.toUpperCase()}')})',
      )
      .join(',');
  final data = formatter.format('''
class JourneyData {
  const JourneyData(this.name, this.values);
  final String name;
  final Map<String, String> values;

  String value(String name) {
    final result = values[name];
    if (result == null || result.isEmpty) {
      throw StateError('Missing non-secret profile field: \$name');
    }
    return result;
  }

  String secret(String name) {
    const secrets = <String, String>{$secretEntries};
    final result = secrets[name];
    if (result == null || result.isEmpty) {
      throw StateError('Missing secret reference: \$name (use a private dart-define file)');
    }
    return result;
  }
}

// Edit non-secret values here. Never add passwords or tokens.
const profiles = <String, Map<String, String>>{$profileEntries};

JourneyData loadProfile() {
  const name = String.fromEnvironment('RECORDER_PROFILE', defaultValue: ${dartLiteral(config.profile)});
  final values = profiles[name];
  if (values == null) {
    throw StateError('Unknown RECORDER_PROFILE; inspect the journey data file.');
  }
  final result = JourneyData(name, values);
  for (final field in <String>[${plain.map(dartLiteral).join(',')}]) {
    result.value(field);
  }
  for (final field in <String>[${secrets.map(dartLiteral).join(',')}]) {
    result.secret(field);
  }
  return result;
}
''');
  final selectors = [
    for (final step in steps) ...[
      step.target.selector!,
      if (step.target.scope != null) step.target.scope!,
    ],
  ];
  final useSemantics = selectors.any(
    (s) =>
        s.kind == SelectorKind.semanticsIdentifier ||
        s.kind == SelectorKind.semanticsLabel,
  );
  String selector(RecorderSelector s) {
    final literal = dartLiteral(s.value);
    return switch (s.kind) {
      SelectorKind.key => 'find.byKey(const ValueKey<String>($literal))',
      SelectorKind.semanticsIdentifier =>
        'find.bySemanticsIdentifier($literal)',
      SelectorKind.semanticsLabel => 'find.bySemanticsLabel($literal)',
      SelectorKind.fieldLabel =>
        'find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == $literal)',
      SelectorKind.text => 'find.text($literal)',
      SelectorKind.widgetType => 'find.byType(${s.value})',
    };
  }

  String finder(RecorderTarget target) {
    final selected = selector(target.selector!);
    return target.scope == null
        ? selected
        : 'find.descendant(of: ${selector(target.scope!)}, matching: $selected)';
  }

  final actions = steps.indexed
      .map((entry) {
        final (index, step) = entry;
        final name = 'target${index + 1}';
        final action = switch (step.action) {
          RecordedAction.tap => 'await \$($name).tap();',
          RecordedAction.enterText =>
            'await \$.enterText($name, data.${step.secret ? 'secret' : 'value'}(${dartLiteral(step.input!)}), enablePatrolLog: false);',
        };
        return '''
final $name = ${finder(step.target)};
await \$($name).waitUntilExists();
expect($name, findsOneWidget, reason: ${dartLiteral('${step.id}: selector must match exactly one widget')});
$action
''';
      })
      .join('\n');
  final body =
      '''
await \$.pumpWidgetAndSettle(app.${app.appBuilder}());
$actions
''';
  final test = formatter.format('''
${selectors.any((s) => s.kind == SelectorKind.key || s.kind == SelectorKind.widgetType || s.kind == SelectorKind.fieldLabel) ? "import 'package:flutter/material.dart';" : ''}
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '${app.appImport}' as app;
import '${config.journeyId}_data.dart';

void main() {
  final data = loadProfile();
  patrolTest(${dartLiteral(config.caseName)} ' [\${data.name}]', (\$) async {
    ${useSemantics ? 'final semantics = \$.tester.ensureSemantics(); try { $body } finally { semantics.dispose(); }' : body}
  }, tags: [${dartLiteral(config.tag)}]);
}
''');
  return GeneratedJourney(test: test, data: data, config: config);
}
