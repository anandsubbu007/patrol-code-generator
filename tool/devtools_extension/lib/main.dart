import 'dart:async';
import 'dart:convert';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patrol_recorder/model.dart';

import 'src/exporter.dart';
import 'src/generator.dart';

void main() => runApp(const DevToolsExtension(child: RecorderPanel()));

class RecorderPanel extends StatefulWidget {
  const RecorderPanel({super.key});
  @override
  State<RecorderPanel> createState() => _RecorderPanelState();
}

class _RecorderPanelState extends State<RecorderPanel> {
  final _journey = TextEditingController(text: 'login');
  final _caseName = TextEditingController(
    text: 'Sign in with demonstration profile',
  );
  Timer? _timer;
  bool _busy = false;
  bool _refreshing = false;
  bool _connected = false;
  int _commandEpoch = 0;
  String? _connectionIssue;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _snapshot;
  List<Uri> _projects = [];
  Uri? _project;
  ExportConfig _defaults = ExportConfig();
  String _profile = 'demo';
  GeneratedJourney? _generated;
  Uint8List? _png;
  Map<String, dynamic>? _imageInfo;

  @override
  void initState() {
    super.initState();
    _journey.addListener(_regenerate);
    _caseName.addListener(_regenerate);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _journey.dispose();
    _caseName.dispose();
    super.dispose();
  }

  ExportConfig get _config => ExportConfig(
    outputDirectory: _defaults.outputDirectory,
    journeyId: _journey.text,
    caseId: _defaults.caseId,
    caseName: _caseName.text,
    profile: _profile,
  );

  Future<Map<String, dynamic>> _rpc(String command) async {
    if (serviceManager.service == null) {
      throw StateError('No app VM Service is connected.');
    }
    final response = await serviceManager
        .callServiceExtensionOnMainIsolate(
          recorderServiceMethod,
          args: {'command': command},
        )
        .timeout(const Duration(seconds: 15));
    final json = response.json;
    if (json == null || json['protocolVersion'] != recorderProtocolVersion) {
      throw const FormatException(
        'Recorder protocol is missing or incompatible.',
      );
    }
    return json;
  }

  Future<void> _refresh() async {
    if (_busy || _refreshing || !mounted) return;
    _refreshing = true;
    final epoch = _commandEpoch;
    try {
      final snapshot = await _rpc('snapshot');
      if (!mounted || _busy || epoch != _commandEpoch) return;
      final changed =
          _snapshot?['sessionId'] != snapshot['sessionId'] ||
          _snapshot?['sequence'] != snapshot['sequence'] ||
          _snapshot?['error'] != snapshot['error'] ||
          _snapshot?['state'] != snapshot['state'];
      setState(() {
        _connected = true;
        _connectionIssue = null;
        _snapshot = snapshot;
      });
      if (changed) _regenerate();
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionIssue = error.toString();
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionIssue = error.message;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _commandEpoch++;
      _error = null;
      _notice = null;
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

  Future<void> _loadProjects() async {
    final connection = dtdManager.connection.value;
    if (connection == null) {
      throw StateError('DTD is unavailable; workspace export is disabled.');
    }
    final roots = await connection.getProjectRoots();
    final projects = (roots.uris ?? [])
        .map(
          (uri) =>
              uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/'),
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      if (!projects.contains(_project)) {
        _project = projects.length == 1 ? projects.single : null;
      }
    });
  }

  Future<void> _loadConfig() async {
    final root = _project;
    final connection = dtdManager.connection.value;
    if (root == null || connection == null) {
      throw StateError('Select an authorized project first.');
    }
    final content = await DtdWorkspaceFiles(connection)
        .read(root.resolve('recorder_config.yaml'));
    if (content == null) {
      setState(
        () => _notice =
            'No recorder_config.yaml found; documented defaults are active.',
      );
      return;
    }
    final config = ExportConfig.fromYaml(content);
    _defaults = config;
    _profile = config.profile;
    _journey.text = config.journeyId;
    _caseName.text = config.caseName;
    _regenerate();
  }

  void _regenerate() {
    if (!mounted) return;
    try {
      final snapshot = _snapshot;
      if (snapshot?['error'] != null) {
        throw FormatException(snapshot!['error'] as String);
      }
      if (snapshot == null || (snapshot['steps'] as List).isEmpty) {
        setState(() => _generated = null);
        return;
      }
      final steps = (snapshot['steps'] as List)
          .map(
            (step) =>
                RecordedStep.fromJson(Map<String, dynamic>.from(step as Map)),
          )
          .toList();
      final generated = generateJourney(
        steps: steps,
        app: RecorderAppConfig.fromJson(
          Map<String, dynamic>.from(snapshot['config'] as Map),
        ),
        config: _config,
      );
      setState(() {
        _generated = generated;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _generated = null;
        _error = error.message;
      });
    }
  }

  Future<void> _start() async {
    final snapshot = await _rpc('start');
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _png = null;
      _imageInfo = null;
    });
    _regenerate();
  }

  Future<void> _stop() async {
    final snapshot = await _rpc('stop');
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    _regenerate();
  }

  Future<void> _capture() async {
    final snapshot = await _rpc('capture');
    final image = Map<String, dynamic>.from(snapshot['screenshot'] as Map);
    if (image['kind'] != 'flutterContent') {
      throw const FormatException('Unexpected screenshot kind.');
    }
    final bytes = base64Decode(image['png'] as String);
    if (bytes.length < 8 ||
        base64Encode(bytes.sublist(0, 8)) != 'iVBORw0KGgo=') {
      throw const FormatException('The recorder did not return a PNG.');
    }
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _png = bytes;
      _imageInfo = {...image}..remove('png');
    });
  }

  Future<void> _export() async {
    final generated = _generated;
    final root = _project;
    final connection = dtdManager.connection.value;
    if (generated == null || root == null || connection == null) {
      throw StateError(
        'A valid recording and authorized DTD project are required.',
      );
    }
    if (_snapshot?['state'] != 'stopped' ||
        _png == null ||
        _imageInfo?['sessionId'] != _snapshot?['sessionId'] ||
        _imageInfo?['stepId'] != (_snapshot?['steps'] as List?)?.last['id']) {
      throw StateError(
        'Stop and capture a screenshot from this recording first.',
      );
    }
    final screenshotPath =
        '${generated.config.directory}/screenshots/'
        '${_snapshot!['sessionId']}_${_imageInfo!['stepId']}_flutter.png';
    final files = {
      ...generated.files(),
      screenshotPath: _png!,
      '${generated.config.directory}/recording.json': Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert(
            {
              ..._snapshot!,
              'screenshot': {..._imageInfo!, 'path': screenshotPath},
            }..remove('screenshotSupported'),
          ),
        ),
      ),
    };
    final written = await exportNewFiles(
      workspace: DtdWorkspaceFiles(connection),
      projectRoot: root,
      files: files,
    );
    if (mounted) {
      setState(
        () => _notice =
            'Saved ${written.length} files in $root. Text readback verified; PNG write acknowledged and file existence verified. '
            'This DTD host cannot verify PNG bytes by readback. '
            '${written.contains('recorder_config.yaml') ? 'Created recorder_config.yaml.' : 'Existing recorder_config.yaml was preserved.'} '
            'Run the copied command in that project; results are shown in the terminal.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _snapshot?['state'] ?? 'unavailable';
    final steps = (_snapshot?['steps'] as List?) ?? [];
    final app = _snapshot?['config'] as Map?;
    final profiles =
        (app?['safeProfiles'] as Map?)?.keys.cast<String>().toList() ??
        ['demo'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrol Recorder - Automatic observation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              _connected ? 'Connected - $state' : 'Disconnected or recorder unavailable. Last draft retained.',
            ),
            if (_connectionIssue != null) SelectableText(_connectionIssue!),
            const Text(
              'Automatic tap candidates and focused-field activity; not callback-success verification. '
              'Key-first selectors, no coordinate/index fallback. Ambiguous/unsupported actions block export. '
              'Focused controller activity can include selection or programmatic changes; review input references.',
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_snapshot?['error'] != null)
              Text(_snapshot!['error'] as String),
            if (_notice != null) Text(_notice!),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: !_busy && _connected && state != 'recording'
                      ? () => _perform(_start)
                      : null,
                  child: const Text('Start'),
                ),
                FilledButton(
                  onPressed: !_busy && _connected && state == 'recording'
                      ? () => _perform(_stop)
                      : null,
                  child: const Text('Stop'),
                ),
                OutlinedButton(
                  onPressed: !_busy && _connected && state == 'stopped'
                      ? () => _perform(_capture)
                      : null,
                  child: const Text('Capture Flutter content'),
                ),
                OutlinedButton(
                  onPressed: !_busy ? () => _perform(_loadProjects) : null,
                  child: const Text('Refresh export projects'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _journey,
              decoration: const InputDecoration(
                labelText: 'Journey ID (new directory)',
              ),
            ),
            TextField(
              controller: _caseName,
              decoration: const InputDecoration(labelText: 'Case name'),
            ),
            DropdownButton<String>(
              value: profiles.contains(_profile) ? _profile : null,
              hint: const Text('Select a data profile'),
              items: [
                for (final name in profiles)
                  DropdownMenuItem(value: name, child: Text('Profile: $name')),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      _profile = value!;
                      _regenerate();
                    },
            ),
            DropdownButton<Uri>(
              isExpanded: true,
              value: _projects.contains(_project) ? _project : null,
              hint: const Text(
                'Select an authorized DTD project before export.',
              ),
              items: [
                for (final root in _projects)
                  DropdownMenuItem(
                    value: root,
                    child: Text(
                      root.toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (root) => setState(() => _project = root),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: !_busy && _project != null
                      ? () => _perform(_loadConfig)
                      : null,
                  child: const Text('Load recorder_config.yaml'),
                ),
                FilledButton(
                  onPressed:
                      !_busy &&
                          _project != null &&
                          _png != null &&
                          _generated != null
                      ? () => _perform(_export)
                      : null,
                  child: const Text('Save new journey'),
                ),
                OutlinedButton(
                  onPressed: _generated == null
                      ? null
                      : () => _perform(() async {
                          await Clipboard.setData(
                            ClipboardData(text: _generated!.config.command()),
                          );
                          if (mounted) {
                            setState(
                              () => _notice = 'Copied Chrome/headless Patrol command. Run it in the selected project terminal.',
                            );
                          }
                        }),
                  child: const Text('Copy Run Command'),
                ),
              ],
            ),
            if (_generated != null)
              SelectableText(_generated!.config.command()),
            const Divider(),
            LayoutBuilder(
              builder: (context, constraints) {
                final timeline = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Observed actions (${steps.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final raw in steps)
                      ListTile(
                        title: Text('${raw['id']}: ${raw['action']}'),
                        subtitle: Text(
                          'Source: ${raw['source']}\nSelector: ${raw['target']}\n'
                          '${raw['input'] == null ? 'No input' : 'Input reference: ${raw['input']} (value not captured)'}',
                        ),
                      ),
                  ],
                );
                final code = SelectableText(
                  _generated?.test ??
                      'Record a supported action to preview Patrol Dart.',
                );
                return constraints.maxWidth >= 800
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: timeline),
                          const SizedBox(width: 16),
                          Expanded(child: code),
                        ],
                      )
                    : Column(children: [timeline, code]);
              },
            ),
            if (_generated != null)
              ExpansionTile(
                title: const Text('Separate editable data file'),
                children: [SelectableText(_generated!.data)],
              ),
            if (_png != null) ...[
              const Text('Flutter-content screenshot only (not full-device).'),
              SizedBox(height: 300, child: Image.memory(_png!)),
            ],
          ],
        ),
      ),
    );
  }
}
