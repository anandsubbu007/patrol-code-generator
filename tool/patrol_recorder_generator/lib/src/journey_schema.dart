part of 'journey.dart';

Map<String, Object?> _stepMap(RecordedStep step, Set<String> excluded) => {
  'id': step.id,
  'action': step is AssetStep
      ? 'asset'
      : step is GroupStep
      ? 'group'
      : step.action.name,
  if (step is AssetStep) 'asset': step.asset,
  if (step is GroupStep) 'group': step.group,
  if (step is! AssetStep && step is! GroupStep) ...{
    if (step.target.issue == null) 'target': _targetYaml(step.target),
    if (step.target.issue != null) 'review': step.target.issue,
  },
  'source': step.source.name,
  'include': !excluded.contains(step.id),
  if (step.input != null) 'input': '{{${step.input}}}',
  if (step.input != null) 'secret': step.secret,
  if (step.text != null) 'text': step.text,
  if (step.scrollView != null) 'scroll_view': _targetYaml(step.scrollView!),
  if (step.scrollDirection != null) 'direction': step.scrollDirection!.name,
  if (step.expectation != null) 'expectation': step.expectation!.toJson(),
};

Map<String, Object?> _overridesMap(Map<String, RecorderTarget> overrides) => {
  for (final entry in overrides.entries) entry.key: _targetYaml(entry.value),
};

Map<String, Object?> _journeyMap(RecordedJourney journey) => {
  'schema_version': journeySchemaVersion,
  'journey': {
    'id': journey.id,
    'name': journey.name,
    'case_id': journey.caseId,
    'profile': journey.profile,
  },
  'state': journey.state,
  'recording_error': journey.recordingError,
  'acknowledged_incomplete': journey.acknowledgedIncomplete,
  if (journey.assets.isNotEmpty)
    'assets': {
      for (final entry in journey.assets.entries)
        entry.key: entry.value.toMap(),
    },
  if (journey.inputs.isNotEmpty)
    'inputs': {
      for (final entry in journey.inputs.entries)
        entry.key: entry.value.toMap(),
    },
  if (journey.profiles.isNotEmpty) 'profiles': journey.profiles,
  if (journey.groups.isNotEmpty)
    'groups': {
      for (final entry in journey.groups.entries)
        entry.key: [for (final step in entry.value) _stepMap(step, {})],
    },
  if (journey.setup.isNotEmpty)
    'setup': {
      for (final entry in journey.setup.entries)
        entry.key: [for (final step in entry.value) _stepMap(step, {})],
    },
  if (journey.selectorOverrides.isNotEmpty)
    'selector_overrides': _overridesMap(journey.selectorOverrides),
  'steps': [for (final step in journey.steps) _stepMap(step, journey.excluded)],
  if (journey.cases.isNotEmpty)
    'cases': [
      for (final item in journey.cases)
        {
          'id': item.id,
          'name': item.name,
          'profile': item.profile,
          'data': item.data,
          'setup': item.setup,
          'selector_overrides': _overridesMap(item.selectorOverrides),
          'steps': [
            for (final step in item.steps) _stepMap(step, item.excluded),
          ],
        },
    ],
  'screenshots': journey.screenshots.map((image) => image.toMap()).toList(),
};

RecordedStep _readStep(Object? raw, String context) {
  final step = _map(raw, context);
  final id = _string(step['id'], '$context.id');
  try {
    _keys(step, {
      'id',
      'action',
      'target',
      'review',
      'source',
      'include',
      'input',
      'secret',
      'text',
      'scroll_view',
      'direction',
      'expectation',
      'asset',
      'group',
    }, 'step');
    if (step.containsKey('include') && step['include'] is! bool) {
      throw const FormatException('include must be a boolean.');
    }
    if (step['action'] == 'asset' || step['action'] == 'group') {
      final field = step['action'] as String;
      _keys(step, {'id', 'action', field, 'source', 'include'}, field);
      if (step['source'] != null && step['source'] != 'authored') {
        throw FormatException('$field source must be authored.');
      }
      final reference = _string(step[field], '$field reference');
      return field == 'asset'
          ? AssetStep(id: id, asset: reference)
          : GroupStep(id: id, group: reference);
    }
    if (step.containsKey('asset') || step.containsKey('group')) {
      throw const FormatException(
        'Asset/group references require the corresponding action.',
      );
    }
    String? input;
    if (step['action'] == 'enterText') {
      final reference = step['input'];
      final match = reference is String
          ? RegExp(r'^\{\{([a-z][a-z0-9_]{0,63})\}\}$').firstMatch(reference)
          : null;
      if (match == null || step['secret'] is! bool) {
        throw const FormatException(
          'Text entry requires a {{name}} input reference and a secret boolean.',
        );
      }
      input = match.group(1);
    } else if (step.containsKey('input') || step.containsKey('secret')) {
      throw const FormatException('Only text entry accepts input/secret.');
    }
    if (step.containsKey('target') && step.containsKey('review')) {
      throw const FormatException('A review step cannot also have a target.');
    }
    final target = step.containsKey('review')
        ? RecorderTarget(issue: _string(step['review'], 'Review reason'))
        : RecordedJourney._resolvedTarget(step['target'], 'target');
    return RecordedStep.fromJson({
      'id': id,
      'action': step['action'],
      'target': target.toJson(),
      'source': step['source'] ?? 'authored',
      'input': input,
      'secret': step['secret'] ?? false,
      if (step.containsKey('text')) 'text': step['text'],
      if (step.containsKey('expectation'))
        'expectation': _map(step['expectation'], 'expectation'),
      if (step.containsKey('direction')) 'scrollDirection': step['direction'],
      if (step.containsKey('scroll_view'))
        'scrollView': RecordedJourney._resolvedTarget(
          step['scroll_view'],
          'scroll_view',
        ).toJson(),
    });
  } on FormatException catch (error) {
    throw FormatException('$context/$id: ${error.message}');
  }
}

(List<RecordedStep>, Set<String>) _readSteps(
  Object? value,
  String context, {
  bool allowExclusions = true,
}) {
  if (value is! List || value.length > 500) {
    throw FormatException('$context must be a list of at most 500 steps.');
  }
  final steps = <RecordedStep>[];
  final excluded = <String>{};
  for (final raw in value) {
    final step = _readStep(raw, context);
    if (_map(raw, context)['include'] == false) {
      if (!allowExclusions) {
        throw FormatException(
          '$context/${step.id}: exclude a group call instead of a reusable definition step.',
        );
      }
      excluded.add(step.id);
    }
    steps.add(step);
  }
  if (steps.map((step) => step.id).toSet().length != steps.length) {
    throw FormatException('$context: duplicate step IDs.');
  }
  return (steps, excluded);
}

Map<String, RecorderTarget> _readOverrides(Object? value, String context) => {
  for (final entry in _map(value ?? {}, context).entries)
    entry.key: RecordedJourney._resolvedTarget(
      entry.value,
      '$context.${entry.key}',
    ),
};

RecordedJourney _parseV5(Map<String, dynamic> map) {
  _keys(map, {
    'schema_version',
    'journey',
    'state',
    'recording_error',
    'acknowledged_incomplete',
    'steps',
    'screenshots',
    'assets',
    'inputs',
    'profiles',
    'groups',
    'setup',
    'cases',
    'selector_overrides',
  }, 'journey file');
  final identity = _map(map['journey'], 'journey');
  _keys(identity, {'id', 'name', 'case_id', 'profile'}, 'journey');
  if (map['recording_error'] != null && map['recording_error'] is! String ||
      map['acknowledged_incomplete'] != null &&
          map['acknowledged_incomplete'] is! bool ||
      map['screenshots'] != null && map['screenshots'] is! List ||
      map['cases'] != null && map['cases'] is! List) {
    throw const FormatException(
      'Invalid journey metadata, cases, or screenshots.',
    );
  }
  final assets = <String, JourneyAsset>{};
  for (final entry in _map(map['assets'] ?? {}, 'assets').entries) {
    final definition = _map(entry.value, 'asset ${entry.key}');
    _keys(definition, {'path', 'format'}, 'asset ${entry.key}');
    final formats = JourneyAssetFormat.values.where(
      (format) => format.name == definition['format'],
    );
    if (formats.length != 1) {
      throw FormatException(
        'Asset ${entry.key}: unsupported or missing format (text/json required).',
      );
    }
    assets[entry.key] = JourneyAsset(
      path: _string(definition['path'], 'Asset ${entry.key} path'),
      format: formats.single,
    );
  }
  final inputs = <String, JourneyInput>{};
  for (final entry in _map(map['inputs'] ?? {}, 'inputs').entries) {
    final definition = _map(entry.value, 'input ${entry.key}');
    _keys(definition, {'type', 'secret'}, 'input ${entry.key}');
    final types = JourneyInputType.values.where(
      (type) => type.name == definition['type'],
    );
    if (types.length != 1 ||
        definition['secret'] != null && definition['secret'] is! bool) {
      throw FormatException(
        'Input ${entry.key}: unsupported type or invalid secret flag.',
      );
    }
    inputs[entry.key] = JourneyInput(
      type: types.single,
      secret: definition['secret'] as bool? ?? false,
    );
  }
  final parsed = _readSteps(map['steps'] ?? [], 'steps');
  return RecordedJourney(
    id: _string(identity['id'], 'Journey ID'),
    name: _string(identity['name'], 'Journey name'),
    caseId: _string(identity['case_id'] ?? 'default_case', 'Case ID'),
    profile: _string(identity['profile'] ?? 'demo', 'Profile'),
    state: _string(map['state'], 'State'),
    steps: parsed.$1,
    excluded: parsed.$2,
    assets: assets,
    inputs: inputs,
    profiles: {
      for (final entry in _map(map['profiles'] ?? {}, 'profiles').entries)
        entry.key: _map(entry.value, 'profile ${entry.key}'),
    },
    groups: {
      for (final entry in _map(map['groups'] ?? {}, 'groups').entries)
        entry.key: _readSteps(
          entry.value,
          'group ${entry.key}',
          allowExclusions: false,
        ).$1,
    },
    setup: {
      for (final entry in _map(map['setup'] ?? {}, 'setup').entries)
        entry.key: _readSteps(
          entry.value,
          'setup ${entry.key}',
          allowExclusions: false,
        ).$1,
    },
    cases: [for (final raw in map['cases'] as List? ?? []) _readCase(raw)],
    selectorOverrides: _readOverrides(
      map['selector_overrides'],
      'selector_overrides',
    ),
    screenshots: [
      for (final raw in map['screenshots'] as List? ?? [])
        JourneyCapture.fromMap(raw),
    ],
    recordingError: map['recording_error'] as String?,
    acknowledgedIncomplete: map['acknowledged_incomplete'] as bool? ?? false,
  );
}

JourneyCase _readCase(Object? raw) {
  final map = _map(raw, 'case');
  _keys(map, {
    'id',
    'name',
    'profile',
    'steps',
    'setup',
    'data',
    'selector_overrides',
  }, 'case');
  if (map['setup'] != null &&
      (map['setup'] is! List ||
          (map['setup'] as List).any((item) => item is! String))) {
    throw const FormatException('Case setup must be a list of names.');
  }
  final parsed = _readSteps(map['steps'], 'case ${map['id']}');
  return JourneyCase(
    id: _string(map['id'], 'Case ID'),
    name: _string(map['name'], 'Case name'),
    profile: _string(map['profile'], 'Case profile'),
    steps: parsed.$1,
    excluded: parsed.$2,
    setup: List<String>.from(map['setup'] as List? ?? []),
    data: _map(map['data'] ?? {}, 'Case data'),
    selectorOverrides: _readOverrides(
      map['selector_overrides'],
      'case ${map['id']}.selector_overrides',
    ),
  );
}

void _validateData(
  RecordedJourney journey,
  Map<String, Object?> data,
  String context,
) {
  for (final entry in data.entries) {
    final input = journey.inputs[entry.key];
    if (input == null || input.secret || !input.accepts(entry.value)) {
      throw FormatException(
        '$context.${entry.key}: unknown input, secret literal, or wrong typed value.',
      );
    }
  }
}

void _validateJourney(RecordedJourney journey) {
  if (journey.cases.length > 50 ||
      journey.assets.length > 50 ||
      journey.inputs.length > 100 ||
      journey.groups.length > 50 ||
      journey.setup.length > 50 ||
      journey.profiles.length > 50) {
    throw const FormatException(
      'Journey definition exceeds cases/assets/inputs/groups/setup/profile limits.',
    );
  }
  if (journey.cases.isNotEmpty &&
      (journey.steps.isNotEmpty ||
          journey.selectorOverrides.isNotEmpty ||
          journey.screenshots.isNotEmpty)) {
    throw const FormatException(
      'Use either flat steps/screenshots/overrides or cases, not both.',
    );
  }
  if (journey.cases.map((item) => item.id).toSet().length !=
      journey.cases.length) {
    throw const FormatException('Duplicate case IDs.');
  }
  for (final definitions in [
    journey.assets,
    journey.inputs,
    journey.groups,
    journey.setup,
    journey.profiles,
  ]) {
    for (final id in definitions.keys) {
      requireIdentifier(id, 'Definition ID');
    }
  }
  for (final entry in journey.profiles.entries) {
    _validateData(journey, entry.value, 'profile ${entry.key}');
  }
  for (final definitions in [journey.groups, journey.setup]) {
    for (final entry in definitions.entries) {
      _expandCase(
        journey,
        JourneyCase(
          id: 'validation',
          name: 'Validation',
          profile: journey.profile,
          steps: entry.value,
        ),
      );
    }
  }
  for (final item in journey.effectiveCases) {
    if (journey.profiles.isNotEmpty &&
        !journey.profiles.containsKey(item.profile)) {
      throw FormatException(
        'Case ${item.id}: unknown profile ${item.profile}.',
      );
    }
    _validateData(journey, item.data, 'case ${item.id}');
    _expandCase(journey, item);
  }
}

RecordedStep _copyStep(RecordedStep step, String id, RecorderTarget? override) {
  if (step is AssetStep) return AssetStep(id: id, asset: step.asset);
  return RecordedStep.fromJson({
    ...step.toJson(),
    'id': id,
    if (override != null) 'target': override.toJson(),
  });
}

List<RecordedStep> _expandCase(RecordedJourney journey, JourneyCase item) {
  final result = <RecordedStep>[];
  final seen = <String>{};
  final knownOverrides = <String>{};
  var visited = 0;
  void visit(
    List<RecordedStep> steps,
    String prefix,
    Set<String> stack,
    Set<String> excluded,
  ) {
    for (final step in steps) {
      if (++visited > 500) {
        throw FormatException('Case ${item.id}: expanded steps exceed 500.');
      }
      final id = '$prefix${step.id}';
      requireIdentifier(id, 'Expanded step ID');
      if (!seen.add(id)) {
        throw FormatException(
          'Case ${item.id}: duplicate expanded step ID $id.',
        );
      }
      if (step is GroupStep) {
        final group = journey.groups[step.group];
        if (group == null || stack.contains(step.group)) {
          throw FormatException(
            'Case ${item.id}/$id: unknown or cyclic group ${step.group}.',
          );
        }
        visit(
          group,
          '${id}_',
          {...stack, step.group},
          excluded.contains(step.id)
              ? group.map((step) => step.id).toSet()
              : {},
        );
        continue;
      }
      if (step is AssetStep && !journey.assets.containsKey(step.asset)) {
        throw FormatException(
          'Case ${item.id}/$id: unknown asset ${step.asset}.',
        );
      }
      final override = item.selectorOverrides[id];
      if (override != null) {
        if (step is AssetStep || override.selector == null) {
          throw FormatException(
            '$id: only widget steps accept resolved overrides.',
          );
        }
        knownOverrides.add(id);
      }
      if (step.input != null && journey.inputs.isNotEmpty) {
        final input = journey.inputs[step.input];
        if (input == null || input.secret != step.secret) {
          throw FormatException(
            '$id: unknown input or conflicting secret flag.',
          );
        }
      }
      if (!excluded.contains(step.id)) {
        result.add(_copyStep(step, id, override));
      }
    }
  }

  for (final reference in item.setup) {
    final definition = journey.setup[reference];
    if (definition == null) {
      throw FormatException('Case ${item.id}: unknown setup $reference.');
    }
    visit(definition, 'setup_${reference}_', {}, {});
  }
  visit(item.steps, '', {}, item.excluded);
  if (item.selectorOverrides.keys.any((id) => !knownOverrides.contains(id))) {
    throw FormatException(
      'Case ${item.id}: selector override references an unknown step.',
    );
  }
  return result;
}
