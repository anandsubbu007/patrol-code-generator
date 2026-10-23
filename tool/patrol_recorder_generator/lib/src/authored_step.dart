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

  Object decode(String source) {
    if (utf8.encode(source).length > 1024 * 1024) {
      throw FormatException('Asset $path exceeds 1 MiB.');
    }
    try {
      return format == JourneyAssetFormat.json
          ? jsonDecode(source) as Object
          : source;
    } on Object catch (_) {
      throw FormatException('Asset $path must contain valid, non-null JSON.');
    }
  }
}

class AssetStep extends RecordedStep {
  AssetStep({required super.id, required this.asset})
    : super(
        action: RecordedAction.unsupported,
        target: RecorderTarget(issue: 'User-owned fixture adapter required'),
      ) {
    requireIdentifier(asset, 'Asset reference');
  }

  final String asset;
}
