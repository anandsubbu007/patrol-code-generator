import 'dart:convert';

import 'package:patrol_recorder/model.dart';

import 'generator.dart';

typedef JourneyExpectation = RecordedExpectation;

class ExpectStep extends RecordedStep {
  ExpectStep({
    required super.id,
    required super.target,
    required JourneyExpectation expectation,
    Object? value,
    int? timeoutMs,
  }) : super(
         action: RecordedAction.expect,
         source: ObservationSource.authored,
         expectation: ExpectationSpec(
           kind: expectation,
           value: value,
           timeoutMs: timeoutMs ?? 10000,
         ),
       );
}

enum JourneyAssetFormat { text, json }

class JourneyAsset {
  JourneyAsset({required this.path, required this.format}) {
    validateRelativePath(path);
    if (!path.startsWith('assets/')) {
      throw const FormatException(
        'Asset path must be relative to the journey root under assets/.',
      );
    }
  }

  final String path;
  final JourneyAssetFormat format;

  Map<String, Object?> toMap() => {'path': path, 'format': format.name};

  Object decode(String source) {
    if (utf8.encode(source).length > 1024 * 1024) {
      throw FormatException('Asset $path exceeds 1 MiB.');
    }
    try {
      if (format == JourneyAssetFormat.text) return source;
      final decoded = jsonDecode(source);
      if (!JourneyInput(type: JourneyInputType.json).accepts(decoded)) {
        throw const FormatException('Invalid JSON value.');
      }
      return decoded as Object;
    } on FormatException catch (_) {
      throw FormatException('Asset $path must contain valid, non-null JSON.');
    }
  }
}

class AssetStep extends RecordedStep {
  AssetStep({required super.id, required this.asset})
    : super(
        action: RecordedAction.unsupported,
        source: ObservationSource.authored,
        target: RecorderTarget(issue: 'User-owned fixture adapter required'),
      ) {
    requireIdentifier(asset, 'Asset reference');
  }

  final String asset;
}

class GroupStep extends RecordedStep {
  GroupStep({required super.id, required this.group})
    : super(
        action: RecordedAction.unsupported,
        source: ObservationSource.authored,
        target: RecorderTarget(issue: 'Reusable group reference'),
      ) {
    requireIdentifier(group, 'Group reference');
  }
  final String group;
}

enum JourneyInputType { string, integer, number, boolean, json }

class JourneyInput {
  JourneyInput({required this.type, this.secret = false}) {
    if (secret && type != JourneyInputType.string) {
      throw const FormatException('Secret inputs must have type string.');
    }
  }

  final JourneyInputType type;
  final bool secret;
  String get dartType => switch (type) {
    JourneyInputType.string => 'String',
    JourneyInputType.integer => 'int',
    JourneyInputType.number => 'double',
    JourneyInputType.boolean => 'bool',
    JourneyInputType.json => 'Object',
  };

  bool accepts(Object? value) => switch (type) {
    JourneyInputType.string => value is String,
    JourneyInputType.integer => value is int,
    JourneyInputType.number => value is num && value.isFinite,
    JourneyInputType.boolean => value is bool,
    JourneyInputType.json => _jsonValue(value),
  };

  Map<String, Object?> toMap() => {'type': type.name, 'secret': secret};
}

bool _jsonValue(Object? value, [int depth = 0]) {
  if (depth > 20 || value == null) return false;
  if (value is String || value is bool || value is num && value.isFinite) {
    return true;
  }
  if (value is List) {
    return value.every((item) => item == null || _jsonValue(item, depth + 1));
  }
  if (value is Map) {
    return value.entries.every(
      (entry) =>
          entry.key is String &&
          (entry.value == null || _jsonValue(entry.value, depth + 1)),
    );
  }
  return false;
}

class JourneyCase {
  JourneyCase({
    required this.id,
    required this.name,
    required this.profile,
    required List<RecordedStep> steps,
    List<String> setup = const [],
    Map<String, Object?> data = const {},
    Map<String, RecorderTarget> selectorOverrides = const {},
    Set<String> excluded = const {},
  }) : steps = List.unmodifiable(steps),
       setup = List.unmodifiable(setup),
       data = freezeJourneyData(data),
       selectorOverrides = Map.unmodifiable(selectorOverrides),
       excluded = Set.unmodifiable(excluded) {
    requireIdentifier(id, 'Case ID');
    requireIdentifier(profile, 'Profile name');
    if (name.trim().isEmpty ||
        name.length > 120 ||
        name.codeUnits.any((unit) => unit < 32)) {
      throw const FormatException(
        'Case name must contain 1-120 printable characters.',
      );
    }
    final ids = steps.map((step) => step.id).toSet();
    if (ids.length != steps.length ||
        steps.length > 500 ||
        excluded.any((id) => !ids.contains(id))) {
      throw FormatException(
        'Case $id has duplicate, unknown, or excessive step IDs.',
      );
    }
    for (final reference in setup) {
      requireIdentifier(reference, 'Setup reference');
    }
    for (final entry in selectorOverrides.entries) {
      requireIdentifier(entry.key, 'Selector override step ID');
      if (entry.value.selector == null) {
        throw FormatException('Case $id: selector overrides must be resolved.');
      }
    }
  }

  final String id, name, profile;
  final List<RecordedStep> steps;
  final List<String> setup;
  final Map<String, Object?> data;
  final Map<String, RecorderTarget> selectorOverrides;
  final Set<String> excluded;
}

Map<String, Object?> freezeJourneyData(Map<String, Object?> data) {
  Object? freeze(Object? value, int depth) {
    if (depth > 20) {
      throw const FormatException('Typed data exceeds 20 levels of nesting.');
    }
    if (value is List) {
      return List<Object?>.unmodifiable(
        value.map((item) => freeze(item, depth + 1)),
      );
    }
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw const FormatException('Typed data keys must be strings.');
      }
      return Map<String, Object?>.unmodifiable({
        for (final entry in value.entries)
          entry.key as String: freeze(entry.value, depth + 1),
      });
    }
    return value;
  }

  return freeze(data, 0) as Map<String, Object?>;
}
