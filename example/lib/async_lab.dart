import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'showcase.dart';

class AsyncLabPage extends StatefulWidget {
  const AsyncLabPage({super.key});
  @override
  State<AsyncLabPage> createState() => _AsyncLabPageState();
}

class _AsyncLabPageState extends State<AsyncLabPage>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  late final _terms = TapGestureRecognizer()..onTap = _loadTerms;
  bool _looping = true;
  bool _loading = false;
  bool _ready = false;
  String? _selection;
  String _result = 'Waiting for terms';
  String _hold = 'Hold for details';

  Future<void> _loadTerms() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _result = 'Loading terms';
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _loading = false;
        _ready = true;
        _result = 'Terms ready';
      });
    }
  }

  Future<void> _pick() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: '/async_options'),
      builder: (_) => const AsyncOptionPicker(),
    );
    if (selection != null && mounted) setState(() => _selection = selection);
  }

  @override
  void dispose() {
    _animation.dispose();
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LabScaffold(
    name: 'async_interactions',
    title: 'Async and lazy loading',
    child: ListView(
      key: const ValueKey('async_page'),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Local Future simulations only; no external API or real credentials.',
        ),
        SizedBox(
          height: 42,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (_, child) => Transform.rotate(
              angle: _animation.value * 2 * math.pi,
              child: child,
            ),
            child: const Icon(Icons.sync, size: 32),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('loop_animation'),
          title: const Text('Continuous animation'),
          value: _looping,
          onChanged: (value) {
            setState(() => _looping = value);
            if (value) {
              _animation.repeat();
            } else {
              _animation.stop();
            }
          },
        ),
        Text.rich(
          key: const ValueKey('legal_paragraph'),
          TextSpan(
            children: [
              const TextSpan(text: 'Read the '),
              TextSpan(
                text: 'Terms',
                recognizer: _terms,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              const TextSpan(text: ' before continuing.'),
            ],
          ),
        ),
        Text(_result, key: const ValueKey('async_status')),
        FilledButton(
          key: const ValueKey('after_api'),
          onPressed: !_ready
              ? null
              : () => setState(
                  () => _result = 'Future-dependent action completed',
                ),
          child: const Text('Continue after API'),
        ),
        OutlinedButton(
          key: const ValueKey('open_lazy_picker'),
          onPressed: _pick,
          child: const Text('Choose from lazy dropdown'),
        ),
        Text(
          _selection == null ? 'No option selected' : 'Selected: $_selection',
        ),
        FilledButton(
          key: const ValueKey('confirm_option'),
          onPressed: _selection == null
              ? null
              : () => setState(
                  () => _result = 'Selection confirmed: $_selection',
                ),
          child: const Text('Confirm selection'),
        ),
        GestureDetector(
          key: const ValueKey('long_press_card'),
          onLongPress: () => setState(() => _hold = 'Long press received'),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_hold),
            ),
          ),
        ),
        const Text(
          'The rotating icon deliberately never settles while enabled. Tests wait for their target, not for the entire app to stop animating.',
        ),
      ],
    ),
  );
}

class AsyncOptionPicker extends StatefulWidget {
  const AsyncOptionPicker({super.key});
  @override
  State<AsyncOptionPicker> createState() => _AsyncOptionPickerState();
}

class _AsyncOptionPickerState extends State<AsyncOptionPicker> {
  final _scroll = ScrollController();
  int _count = 10;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadNearEnd);
  }

  void _loadNearEnd() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 100 &&
        !_loading &&
        _count < 60) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) {
      setState(() {
        _count += 10;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenIdentity(
    name: 'async_option_picker',
    label: 'Lazy option picker',
    child: SizedBox(
      height: 360,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Lazy options: 10 items per local Future, up to 60 demo items',
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('async_options'),
              controller: _scroll,
              itemExtent: 52,
              itemCount: _count + 1,
              itemBuilder: (context, index) => index == _count
                  ? Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Text(
                              _count < 60
                                  ? 'Scroll for more options'
                                  : 'All options loaded',
                            ),
                    )
                  : ListTile(
                      key: ValueKey('option_$index'),
                      title: Text('Option $index'),
                      onTap: () => Navigator.pop(context, 'Option $index'),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
