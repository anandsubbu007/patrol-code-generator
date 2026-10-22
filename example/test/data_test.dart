import 'package:flutter_test/flutter_test.dart';

import '../patrol_test/recorded_journeys/login/login_data.dart';

void main() {
  test('generated data selects a named profile before test execution', () {
    const selected = String.fromEnvironment(
      'RECORDER_PROFILE',
      defaultValue: 'demo',
    );
    final data = loadProfile();
    expect(data.name, selected);
    expect(data.value('email'), profiles[selected]!['email']);
    expect(data.value('note'), isNotEmpty);
    expect(profiles.keys, containsAll(['demo', 'secondary']));
  });

  test('data can change independently and validates missing values', () {
    const data = JourneyData('edited', {'email': 'edited@example.invalid'});
    expect(data.value('email'), 'edited@example.invalid');
    expect(() => data.value('note'), throwsStateError);
    expect(
      () => const JourneyData('empty', {'email': ''}).value('email'),
      throwsStateError,
    );
  });

  test('missing secret error contains only the reference name', () {
    const data = JourneyData('demo', {});
    expect(
      () => data.secret('password'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Missing secret reference: password (use a private dart-define file)',
        ),
      ),
    );
  });
}
