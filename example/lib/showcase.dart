import 'package:flutter/material.dart';

class ScreenIdentity extends StatelessWidget {
  const ScreenIdentity({
    super.key,
    required this.name,
    required this.label,
    required this.child,
  });
  final String name;
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    identifier: name,
    label: label,
    scopesRoute: true,
    namesRoute: true,
    explicitChildNodes: true,
    child: child,
  );
}

class LabScaffold extends StatelessWidget {
  const LabScaffold({
    super.key,
    required this.name,
    required this.title,
    required this.child,
  });
  final String name;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => ScreenIdentity(
    name: name,
    label: title,
    child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          key: ValueKey('${name}_back'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: child,
        ),
      ),
    ),
  );
}

class AnimationLabPage extends StatefulWidget {
  const AnimationLabPage({super.key});
  @override
  State<AnimationLabPage> createState() => _AnimationLabPageState();
}

class _AnimationLabPageState extends State<AnimationLabPage>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _expanded = false;
  bool _loading = false;
  String _status = 'Ready';

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = 'Loading';
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _loading = false;
        _status = 'Loaded';
      });
    }
  }

  @override
  Widget build(BuildContext context) => LabScaffold(
    name: 'animation_lab',
    title: 'Animation lab',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Finite animations: slide, scale, cross-fade and a bounded loading state.',
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('animate_card'),
              onPressed: () {
                if (_animation.value == 0) {
                  _animation.forward();
                } else {
                  _animation.reverse();
                }
              },
              child: const Text('Animate card'),
            ),
            OutlinedButton(
              key: const ValueKey('expand_card'),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Collapse card' : 'Expand card'),
            ),
            OutlinedButton(
              key: const ValueKey('simulate_loading'),
              onPressed: _loading ? null : _load,
              child: const Text('Simulate loading'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(0.08, 0))
              .animate(
                CurvedAnimation(parent: _animation, curve: Curves.easeInOut),
              ),
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 0.9).animate(_animation),
            child: AnimatedContainer(
              key: const ValueKey('animated_card'),
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(24),
              height: _expanded ? 210 : 120,
              decoration: BoxDecoration(
                color: _expanded
                    ? Colors.indigo.shade100
                    : Colors.teal.shade100,
                borderRadius: BorderRadius.circular(_expanded ? 28 : 8),
              ),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const Text('Compact summary'),
                secondChild: const Text(
                  'Expanded summary with additional information.\nAll motion stops; no indefinite settling is required.',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _loading
              ? const SizedBox(
                  key: ValueKey('loading_indicator'),
                  height: 32,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Text(_status, key: ValueKey(_status)),
        ),
        const SizedBox(height: 20),
        const ExpansionTile(
          key: ValueKey('animation_notes'),
          title: Text('Recorder notes'),
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Take named captures before and after animation. Continuous animations and arbitrary drag gestures are separate limitations.',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class RepeatedControlsPage extends StatefulWidget {
  const RepeatedControlsPage({super.key});
  @override
  State<RepeatedControlsPage> createState() => _RepeatedControlsPageState();
}

class _RepeatedControlsPageState extends State<RepeatedControlsPage> {
  String _selected = 'None selected';
  final _counts = {'personal': 0, 'business': 0};
  @override
  Widget build(BuildContext context) => LabScaffold(
    name: 'repeated_controls',
    title: 'Repeated controls',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'These controls intentionally share text and widget types. Their cards supply stable ancestor keys.',
        ),
        for (final section in ['personal', 'business'])
          Container(
            key: ValueKey('${section}_card'),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section == 'personal'
                          ? 'Personal account'
                          : 'Business account',
                    ),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () =>
                              setState(() => _selected = '$section selected'),
                          child: const Text('Continue'),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _counts[section] = _counts[section]! + 1,
                          ),
                          icon: const Icon(Icons.add),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            '$section count: ${_counts[section]}',
                            key: ValueKey(_counts[section]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(_selected, key: const ValueKey('selected_account')),
      ],
    ),
  );
}

class FormsLabPage extends StatefulWidget {
  const FormsLabPage({super.key});
  @override
  State<FormsLabPage> createState() => _FormsLabPageState();
}

class _FormsLabPageState extends State<FormsLabPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _role = 'Reader';
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _preview() {
    if (!_form.currentState!.validate()) return;
    showModalBottomSheet<void>(
      context: context,
      routeSettings: const RouteSettings(name: '/profile_preview'),
      builder: (context) => ScreenIdentity(
        name: 'profile_preview_sheet',
        label: 'Profile preview',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Profile preview'),
              Text('Display name: ${_name.text}'),
              Text('Role: $_role'),
              FilledButton(
                key: const ValueKey('close_preview'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close preview'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LabScaffold(
    name: 'forms_lab',
    title: 'Forms and overlays',
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Use fictional data. The preview deliberately displays the non-secret display name.',
          ),
          TextFormField(
            key: const ValueKey('display_name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a display name'
                : null,
          ),
          DropdownButton<String>(
            key: const ValueKey('profile_role'),
            value: _role,
            items: [
              for (final role in ['Reader', 'Editor', 'Owner'])
                DropdownMenuItem(value: role, child: Text(role)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _role = value);
            },
          ),
          FilledButton(
            key: const ValueKey('preview_profile'),
            onPressed: _preview,
            child: const Text('Preview profile'),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            key: const ValueKey('open_info_dialog'),
            onPressed: () => showDialog<void>(
              context: context,
              routeSettings: const RouteSettings(name: '/information'),
              builder: (context) => ScreenIdentity(
                name: 'information_dialog',
                label: 'Information',
                child: AlertDialog(
                  title: const Text('Information'),
                  content: const Text(
                    'Dialogs are separate visible pages for screenshot naming.',
                  ),
                  actions: [
                    TextButton(
                      key: const ValueKey('dismiss_info'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('Open information dialog'),
          ),
        ],
      ),
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _newsletter = false;

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: '/settings/reset'),
      builder: (context) => ScreenIdentity(
        name: 'reset_preferences_dialog',
        label: 'Reset preferences',
        child: AlertDialog(
          title: const Text('Reset preferences?'),
          content: const Text(
            'This only changes local demonstration settings.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancel_reset'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm_reset'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _notifications = true;
        _newsletter = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences reset'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LabScaffold(
    name: 'account_settings',
    title: 'Account settings',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          key: const ValueKey('notifications'),
          title: const Text('Notifications'),
          value: _notifications,
          onChanged: (v) => setState(() => _notifications = v),
        ),
        CheckboxListTile(
          key: const ValueKey('newsletter'),
          title: const Text('Newsletter'),
          value: _newsletter,
          onChanged: (v) => setState(() => _newsletter = v!),
        ),
        FilledButton(
          key: const ValueKey('reset_preferences'),
          onPressed: _reset,
          child: const Text('Reset preferences'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Long content below exercises a scrollable viewport. Scroll recording is still review-required.',
        ),
        for (var i = 1; i <= 12; i++)
          ListTile(
            key: ValueKey('setting_row_$i'),
            title: Text('Additional setting $i'),
            subtitle: const Text('Informational row, not a tap action.'),
          ),
      ],
    ),
  );
}
