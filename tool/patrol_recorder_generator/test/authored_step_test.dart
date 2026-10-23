import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/src/authored_step.dart';

void main() {
  test('expectations enforce typed values, resolved selectors and bounds', () {
    for (final form in JourneyExpectation.values) {
      final step = ExpectStep(
        id: 'ready',
        target: RecorderTarget(key: 'status'),
        expectation: form,
        value: switch (form) {
          JourneyExpectation.text => 'Ready',
          JourneyExpectation.count => 2,
          _ => null,
        },
      );
      expect(step.expectation!.kind, form);
    }
    for (final value in [null, true, -1, '2']) {
      expect(
        () => ExpectStep(
          id: 'ready',
          target: RecorderTarget(key: 'status'),
          expectation: JourneyExpectation.count,
          value: value,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => ExpectStep(
        id: 'ready',
        target: RecorderTarget(issue: 'unknown'),
        expectation: JourneyExpectation.exists,
      ),
      throwsFormatException,
    );
    for (final timeout in [0, 99, 120001]) {
      expect(
        () => ExpectStep(
          id: 'ready',
          target: RecorderTarget(key: 'status'),
          expectation: JourneyExpectation.exists,
          timeoutMs: timeout,
        ),
        throwsFormatException,
      );
    }
  });

  test('assets are bounded text or JSON fixtures, never arbitrary files', () {
    for (final path in [
      '../secret',
      '/tmp/file',
      'assets/../secret',
      'file.json',
      r'assets\file',
    ]) {
      expect(
        () => JourneyAsset(path: path, format: JourneyAssetFormat.json),
        throwsFormatException,
      );
    }
    final asset = JourneyAsset(
      path: 'assets/user.json',
      format: JourneyAssetFormat.json,
    );
    expect(asset.decode('{"name":"fixture"}'), {'name': 'fixture'});
    for (final source in ['{', 'null', 'x' * (1024 * 1024 + 1)]) {
      expect(() => asset.decode(source), throwsFormatException);
    }
  });
}
