import 'package:flutter/material.dart';
import 'package:patrol_recorder/model.dart';
import 'package:patrol_recorder_generator/generator.dart';
import 'package:yaml/yaml.dart';

import 'backend.dart';
import 'recording_writer.dart';

class RecordingSetup extends StatefulWidget {
  const RecordingSetup({super.key, required this.backend, required this.app});
  final RecorderBackend backend;
  final RecorderAppConfig app;
  @override
  State<RecordingSetup> createState() => _RecordingSetupState();
}

class _RecordingSetupState extends State<RecordingSetup> {
  final _form = GlobalKey<FormState>();
  final _journey = TextEditingController(text: 'login');
  final _name = TextEditingController(text: 'Recorded journey');
  final _case = TextEditingController(text: 'sign_in');
  final _profile = TextEditingController(text: 'demo');
  final _recordings = TextEditingController(text: 'patrol_recorder');
  final _screenshots = TextEditingController(
    text: 'patrol_recorder/screenshots',
  );
  List<Uri> _roots = [];
  Uri? _root;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _journey,
      _name,
      _case,
      _profile,
      _recordings,
      _screenshots,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? get _package => widget.app.appImport == null
      ? null
      : Uri.parse(widget.app.appImport!).path.split('/').first;
  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _perform(() async {
    final roots = (await widget.backend.projects()).toSet().toList();
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _root = null;
    });
    if (roots.isEmpty) {
      throw StateError(
        'No authorized workspace. Launch with --print-dtd or use an IDE-managed DevTools session.',
      );
    }
    final matching = <Uri>[];
    for (final root in roots) {
      final source = await widget.backend.files.read(
        root.resolve('pubspec.yaml'),
      );
      if (source == null) continue;
      final yaml = loadYaml(source);
      if (yaml is YamlMap) {
        final dev = yaml['dev_dependencies'];
        final looksLikeApp =
            yaml.containsKey('flutter') &&
            dev is Map &&
            dev.containsKey('patrol_recorder');
        if (_package != null ? yaml['name'] == _package : looksLikeApp) {
          matching.add(root);
        }
      }
    }
    if (matching.length == 1) await _select(matching.single);
  });

  Future<void> _select(Uri root) async {
    setState(() => _root = null);
    final source = await widget.backend.files.read(
      root.resolve('pubspec.yaml'),
    );
    if (source == null) {
      throw StateError('No app pubspec.yaml at this destination.');
    }
    final defaults = ExportConfig.fromPubspec(
      source,
      expectedPackage: _package,
    );
    if (!mounted) return;
    setState(() {
      _root = root;
      _journey.text = defaults.journeyId;
      _name.text = defaults.caseName;
      _case.text = defaults.caseId;
      _profile.text = defaults.profile;
      _recordings.text = defaults.recordingsDirectory;
      _screenshots.text = defaults.screenshotsDirectory;
    });
  }

  String? _identifier(String? value) {
    try {
      requireIdentifier(value?.trim() ?? '', 'Name');
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  String? _path(String? value) {
    try {
      validateRelativePath(value?.trim() ?? '');
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  Future<void> _record() async {
    if (!_form.currentState!.validate()) return;
    await _perform(() async {
      if (_root == null) throw StateError('Choose the app project.');
      final writer = await RecordingWriter.open(
        root: _root!,
        config: ExportConfig(
          journeyId: _journey.text.trim(),
          caseName: _name.text.trim(),
          caseId: _case.text.trim(),
          profile: _profile.text.trim(),
          recordingsDirectory: _recordings.text.trim(),
          screenshotsDirectory: _screenshots.text.trim(),
        ),
        files: widget.backend.files,
        app: widget.app,
      );
      if (mounted) Navigator.pop(context, writer);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record a named YAML journey'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Record creates the YAML immediately and saves updates automatically. '
                'Using the same journey name replaces its previous recorder-owned YAML. '
                'Your Dart input implementation is never touched.',
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              DropdownButtonFormField<Uri>(
                key: ValueKey(_root),
                initialValue: _root,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'App project'),
                items: [
                  for (final root in _roots)
                    DropdownMenuItem(
                      value: root,
                      child: Text(
                        root.toFilePath(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (root) {
                        if (root != null) _perform(() => _select(root));
                      },
                validator: (value) =>
                    value == null ? 'Select the app project.' : null,
              ),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Refresh projects'),
              ),
              TextFormField(
                controller: _journey,
                enabled: !_busy,
                validator: _identifier,
                decoration: const InputDecoration(
                  labelText: 'Journey name (file name)',
                ),
              ),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Test description',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a description.'
                    : null,
              ),
              TextFormField(
                controller: _recordings,
                enabled: !_busy,
                validator: _path,
                decoration: const InputDecoration(
                  labelText: 'YAML directory (project-relative)',
                ),
              ),
              TextFormField(
                controller: _screenshots,
                enabled: !_busy,
                validator: _path,
                decoration: const InputDecoration(
                  labelText: 'Screenshot directory (project-relative)',
                ),
              ),
              TextFormField(
                controller: _case,
                enabled: !_busy,
                validator: _identifier,
                decoration: const InputDecoration(labelText: 'Case ID'),
              ),
              TextFormField(
                controller: _profile,
                enabled: !_busy,
                validator: _identifier,
                decoration: const InputDecoration(
                  labelText: 'Input profile name',
                ),
              ),
              const Text(
                'Optional defaults: pubspec.yaml > recorder_config. The copied generator command includes '
                'this YAML directory. No input values are requested or saved in YAML.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _record,
        child: const Text('Record and save YAML'),
      ),
    ],
  );
}
