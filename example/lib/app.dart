import 'package:flutter/material.dart';

import 'showcase.dart';
import 'async_lab.dart';
import 'fixture_lab.dart';

Widget createApp() => const DemoApp();

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Patrol Recorder Example',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const LoginPage(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenIdentity(
      name: 'login_page',
      label: 'Login',
      child: Scaffold(
        appBar: AppBar(title: const Text('Local demonstration login')),
        body: Center(
          child: SizedBox(
            width: 460,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'No server or real authentication. Never enter real credentials.',
                ),
                TextField(
                  key: const ValueKey<String>('email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  key: const ValueKey<String>('note'),
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                TextField(
                  key: const ValueKey<String>('password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Optional demonstration secret',
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'demo.login',
                  child: FilledButton(
                    key: const ValueKey<String>('login'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(name: '/account'),
                          builder: (_) => const AccountPage(),
                        ),
                      );
                    },
                    child: const Text('Open demo account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => ScreenIdentity(
    name: 'account_overview',
    label: 'Account overview',
    child: Scaffold(
      appBar: AppBar(title: const Text('Account overview')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Demo account is open',
                key: ValueKey<String>('account_open'),
              ),
              const Text('This page deliberately displays no input values.'),
              FilledButton(
                key: const ValueKey<String>('settings'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/settings'),
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
                child: const Text('Account settings'),
              ),
              const SizedBox(height: 16),
              const Text('Recorder UI laboratory'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    key: const ValueKey('open_animations'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: '/animations'),
                        builder: (_) => const AnimationLabPage(),
                      ),
                    ),
                    child: const Text('Animation lab'),
                  ),
                  FilledButton(
                    key: const ValueKey('open_repeated'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: '/repeated'),
                        builder: (_) => const RepeatedControlsPage(),
                      ),
                    ),
                    child: const Text('Repeated controls'),
                  ),
                  FilledButton(
                    key: const ValueKey('open_forms'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: '/forms'),
                        builder: (_) => const FormsLabPage(),
                      ),
                    ),
                    child: const Text('Forms and overlays'),
                  ),
                  FilledButton(
                    key: const ValueKey('open_async'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: '/async'),
                        builder: (_) => const AsyncLabPage(),
                      ),
                    ),
                    child: const Text('Async and lazy loading'),
                  ),
                  FilledButton(
                    key: const ValueKey('open_fixtures'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: '/fixtures'),
                        builder: (_) => const FixtureLabPage(),
                      ),
                    ),
                    child: const Text('Fixture and expectation lab'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
