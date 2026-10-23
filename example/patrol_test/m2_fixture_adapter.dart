import 'package:patrol_recorder_example/fixture_lab.dart';

mixin DemoFixtureAdapter {
  String get inputEmail;
  int get inputQuantity;
  bool get inputEnabled;
  double get inputCredit;
  Object get inputOptions;

  Future<void> applyAsset(String name, Object value) async {
    switch (name) {
      case 'customer':
        final options = inputOptions;
        if (value is! Map ||
            options is! Map ||
            options['source'] != 'local_fixture') {
          throw const FormatException(
            'Expected a local customer fixture and typed options.',
          );
        }
        demoFixtures.clear();
        demoFixtures.seed(
          {...value, 'email': inputEmail},
          quantity: inputQuantity,
          enabled: inputEnabled,
          credit: inputCredit,
        );
      case 'note':
        if (value is! String || value.trim().isEmpty) {
          throw const FormatException('Expected a nonempty text fixture.');
        }
        demoFixtures.setNote(value.trim());
      default:
        throw StateError('Unsupported demo asset: $name');
    }
  }
}
