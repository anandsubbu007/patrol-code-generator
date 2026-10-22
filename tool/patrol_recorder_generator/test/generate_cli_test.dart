import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the development package exposes the generation CLI', () async {
    final result = await Process.run('dart', [
      'run',
      'patrol_recorder_generator:generate',
      '--help',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      result.stdout,
      contains('dart run patrol_recorder_generator:generate'),
    );
    expect(result.stdout, contains('--journey'));
    expect(result.stdout, contains('--recordings-directory'));
    expect(result.stdout, isNot(contains('dart run patrol_recorder:generate')));
  });

  test(
    'the generator CLI reports invalid arguments with a failing exit',
    () async {
      final result = await Process.run('dart', [
        'run',
        'patrol_recorder_generator:generate',
        '--unknown-option',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Generation failed:'));
      expect(result.stdout, isNot(contains('Generated:')));
    },
  );
}
