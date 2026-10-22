import 'package:flutter/material.dart';

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
    return Scaffold(
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
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account overview')),
    body: Center(
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
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Account settings')),
                  ),
                ),
              );
            },
            child: const Text('Account settings'),
          ),
        ],
      ),
    ),
  );
}
