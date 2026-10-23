import 'package:flutter/material.dart';

final demoFixtures = DemoFixtureStore();

class DemoFixtureStore extends ChangeNotifier {
  String? customerName;
  String? email;
  int quantity = 0;
  bool enabled = false;
  double credit = 0;
  String note = '';

  void setNote(String value) {
    note = value;
    notifyListeners();
  }

  void seed(
    Object value, {
    required int quantity,
    required bool enabled,
    required double credit,
  }) {
    if (value is! Map ||
        value['name'] is! String ||
        (value['name'] as String).trim().isEmpty ||
        value['email'] is! String ||
        !(value['email'] as String).endsWith('.invalid') ||
        quantity < 0 ||
        quantity > 10 ||
        !credit.isFinite ||
        credit < 0) {
      throw const FormatException(
        'Use a fictional customer fixture, 0-10 items, and nonnegative credit.',
      );
    }
    customerName = value['name'] as String;
    email = value['email'] as String;
    this.quantity = quantity;
    this.enabled = enabled;
    this.credit = credit;
    notifyListeners();
  }

  void clear() {
    customerName = null;
    email = null;
    quantity = 0;
    enabled = false;
    credit = 0;
    note = '';
    notifyListeners();
  }
}

class FixtureLabPage extends StatelessWidget {
  const FixtureLabPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fixture and expectation lab')),
    body: ListenableBuilder(
      listenable: demoFixtures,
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                demoFixtures.customerName ?? 'No fixture loaded',
                key: const ValueKey('fixture_name'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                demoFixtures.email ?? 'No customer',
                key: const ValueKey('fixture_email'),
              ),
              const SizedBox(height: 16),
              Text(
                demoFixtures.enabled ? 'Enabled' : 'Disabled',
                key: const ValueKey('fixture_status'),
              ),
              Text(
                'Credit: ${demoFixtures.credit.toStringAsFixed(2)}',
                key: const ValueKey('fixture_credit'),
              ),
              Text(
                'Quantity: ${demoFixtures.quantity}',
                key: const ValueKey('fixture_quantity'),
              ),
              if (demoFixtures.note.isNotEmpty)
                Text(demoFixtures.note, key: const ValueKey('fixture_note')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('seed_fixture'),
                    onPressed: () => demoFixtures.seed(
                      {'name': 'Ada Fixture', 'email': 'ada@example.invalid'},
                      quantity: 2,
                      enabled: true,
                      credit: 24.5,
                    ),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Load sample fixture'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('clear_fixture'),
                    onPressed: demoFixtures.clear,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Clear fixture'),
                  ),
                ],
              ),
              const Divider(height: 32),
              for (var index = 0; index < demoFixtures.quantity; index++)
                ListTile(
                  key: ValueKey('fixture_item_$index'),
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Fixture item'),
                  subtitle: Text('Item ${index + 1}'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
