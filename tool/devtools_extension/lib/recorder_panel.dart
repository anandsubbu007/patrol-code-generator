import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patrol_recorder/model.dart';

import 'src/backend.dart';
import 'src/expectation_dialog.dart';
import 'src/recording_setup.dart';
import 'src/recording_writer.dart';
import 'src/screenshot_name_dialog.dart';

class RecorderPanel extends StatefulWidget {
  const RecorderPanel({super.key, required this.backend});
  final RecorderBackend backend;
  @override
  State<RecorderPanel> createState() => _RecorderPanelState();
}

class _RecorderPanelState extends State<RecorderPanel> {
  Timer? _timer;
  Future<void>? _refreshTask;
  bool _busy = false;
  bool _connected = false;
  bool _dialogOpen = false;
  bool _saving = false;
  int _epoch = 0;
  String? _error, _connectionIssue, _saveError, _notice;
  Map<String, dynamic>? _snapshot;
  RecordingWriter? _writer;
  final _captures = <CapturedScreen>[];
  final _excluded = <String>{};
  bool _reviewedIncomplete = false;

  List<RecordedStep> get _steps => [
    for (final raw in _snapshot?['steps'] as List? ?? [])
      RecordedStep.fromJson(Map<String, dynamic>.from(raw as Map)),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (_busy || _refreshTask != null || !mounted) return;
    final epoch = _epoch;
    _refreshTask = _readSnapshot(epoch).whenComplete(() => _refreshTask = null);
  }

  Future<void> _readSnapshot(int epoch) async {
    final Map<String, dynamic> snapshot;
    try {
      snapshot = await widget.backend.command('snapshot');
    } on Exception catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _connected = false;
          _connectionIssue = error.toString();
        });
      }
      return;
    } on StateError catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _connected = false;
          _connectionIssue = error.message;
        });
      }
      return;
    }
    if (!mounted || _busy || epoch != _epoch) return;
    setState(() {
      _snapshot = snapshot;
      _connected = true;
      _connectionIssue = null;
    });
    try {
      await _persist();
    } on Exception catch (error) {
      if (mounted) setState(() => _saveError = error.toString());
    } on StateError catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    }
    if (mounted &&
        epoch == _epoch &&
        !_dialogOpen &&
        snapshot['selecting'] == true &&
        snapshot['selection'] is Map &&
        (snapshot['selection'] as Map)['selector'] != null) {
      unawaited(_perform(_configureExpectation));
    }
  }

  Future<void> _selectExpectation() async {
    final snapshot = await widget.backend.command('selectTarget');
    if (mounted) setState(() => _snapshot = snapshot);
  }

  Future<void> _cancelSelection() async {
    final snapshot = await widget.backend.command('cancelSelection');
    if (mounted) setState(() => _snapshot = snapshot);
  }

  Future<void> _configureExpectation() async {
    final target = RecorderTarget.fromJson(
      Map<String, dynamic>.from(_snapshot!['selection'] as Map),
    );
    setState(() => _dialogOpen = true);
    final ExpectationSpec? expectation;
    try {
      expectation = await showDialog<ExpectationSpec>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ExpectationDialog(
          target: target,
          suggestedText: _snapshot?['selectionText'] as String?,
        ),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (!mounted) return;
    if (expectation == null) {
      await _cancelSelection();
      return;
    }
    final snapshot = await widget.backend.command(
      'confirmExpectation',
      parameters: {'expectation': jsonEncode(expectation.toJson())},
    );
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    await _persist();
  }

  Future<void> _persist() async {
    if (_writer == null || _snapshot == null) return;
    if (mounted) setState(() => _saving = true);
    try {
      await _writer!.persist(
        _snapshot!,
        captures: _captures,
        excluded: _excluded,
        acknowledgedIncomplete: _reviewedIncomplete,
      );
      if (mounted) setState(() => _saveError = null);
    } on Exception catch (error) {
      if (mounted) setState(() => _saveError = error.toString());
      rethrow;
    } on StateError catch (error) {
      if (mounted) setState(() => _saveError = error.message);
      rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _epoch++;
      _error = null;
      _notice = null;
    });
    try {
      // Let an in-flight autosave finish before changing the destination/session.
      await _refreshTask;
      if (mounted) await action();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    if (_snapshot == null) throw StateError('Connect the recording app first.');
    setState(() => _dialogOpen = true);
    final RecordingWriter? writer;
    try {
      writer = await showDialog<RecordingWriter>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RecordingSetup(
          backend: widget.backend,
          app: RecorderAppConfig.fromJson(
            Map<String, dynamic>.from(_snapshot!['config'] as Map),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (writer == null || !mounted) return;
    final RecordingWriter destination = writer;
    if (_snapshot!['state'] == 'recording') {
      await widget.backend.command('stop');
    }
    final snapshot = await widget.backend.command('start');
    setState(() {
      _writer = destination;
      _snapshot = snapshot;
      _captures.clear();
      _excluded.clear();
      _reviewedIncomplete = false;
      _saveError = null;
    });
    await _persist();
    if (mounted) {
      setState(
        () => _notice =
            'Recording to ${destination.yamlUri.toFilePath()}. '
            'Actions are autosaved about once per second. Stop recording before running the generator.',
      );
    }
  }

  Future<void> _stop() async {
    final snapshot = await widget.backend.command('stop');
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    await _persist();
    if (mounted) {
      setState(
        () => _notice = _writer == null
            ? 'App recording stopped. Choose Record to create a named YAML journey.'
            : 'Recording stopped and YAML saved. Review any highlighted steps, then run the generator command below.',
      );
    }
  }

  Future<void> _capture() async {
    if (_writer == null) await _start();
    if (_writer == null || !mounted) return;
    if ((_writer!.saved?.screenshots.length ?? _captures.length) >= 10) {
      throw StateError(
        'Keep at most 10 screenshots per recording. Remove a capture before retrying.',
      );
    }
    final snapshot = await widget.backend.command('capture');
    final info = Map<String, dynamic>.from(snapshot['screenshot'] as Map);
    final bytes = base64Decode(info.remove('png') as String);
    if (info['kind'] != 'flutterContent' ||
        info['captureId'] is! String ||
        bytes.length < 8 ||
        base64Encode(bytes.sublist(0, 8)) != 'iVBORw0KGgo=') {
      throw const FormatException('The app did not return a viewport PNG.');
    }
    if (_captures.fold<int>(bytes.length, (n, c) => n + c.bytes.length) >
        20 * 1024 * 1024) {
      throw StateError(
        'Screenshot memory limit reached. Stop and start a new recording.',
      );
    }
    if (!mounted) return;
    final used = _captures.map((c) => c.name).toSet();
    final base = screenshotName(info['suggestedName'] as String? ?? 'screen');
    var suggested = base;
    var suffix = 2;
    while (used.contains(suggested)) {
      suggested = '${base}_${suffix++}';
    }
    setState(() => _dialogOpen = true);
    final String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (_) => ScreenshotNameDialog(
          bytes: bytes,
          suggested: suggested,
          source: info['nameSource'] as String? ?? 'page metadata',
          usedNames: used,
        ),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (name == null || !mounted) return;
    final captureName = name;
    setState(() {
      _snapshot = snapshot;
      _captures.add(CapturedScreen(bytes, info, name: captureName));
    });
    await _persist();
    if (mounted) {
      setState(
        () => _notice =
            'Visible screen saved under ${_writer!.config.screenshotsDirectory}; '
            '${info['redactedRegions']} private regions masked. Its path is recorded in YAML.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _snapshot?['state'] ?? 'unavailable';
    final steps = _steps;
    final writer = _writer;
    final saved = writer?.saved;
    return Scaffold(
      appBar: AppBar(title: const Text('Patrol Recorder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _connected
                ? 'Connected - $state'
                : 'Disconnected - saved YAML is retained',
          ),
          const Text(
            '1. Record a named journey  2. Stop (YAML is saved automatically)  3. Run the Dart generator',
          ),
          const Text(
            'Dynamic inputs are saved as {{input_name}} references, never typed values. No x/y selectors.',
          ),
          if (_connectionIssue != null) Text(_connectionIssue!),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_saveError != null)
            Text(
              'YAML NOT UP TO DATE: $_saveError',
              style: const TextStyle(color: Colors.red),
            ),
          if (_notice != null) Text(_notice!),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed:
                      !_busy &&
                          _connected &&
                          (state != 'recording' || writer == null)
                      ? () => _perform(_start)
                      : null,
                  child: const Text('Record'),
                ),
                OutlinedButton(
                  onPressed: !_busy && _connected && state == 'recording'
                      ? () => _perform(_stop)
                      : null,
                  child: const Text('Stop recording'),
                ),
                OutlinedButton(
                  onPressed:
                      !_busy && _connected && _snapshot?['selecting'] != true
                      ? () => _perform(_capture)
                      : null,
                  child: const Text('Capture visible screen'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      !_busy &&
                          _connected &&
                          writer != null &&
                          state == 'recording' &&
                          _snapshot?['selecting'] != true &&
                          (_snapshot?['capabilities'] as List? ?? []).contains(
                            'expectationPicker',
                          )
                      ? () => _perform(_selectExpectation)
                      : null,
                  icon: const Icon(Icons.ads_click),
                  label: const Text('Add expectation'),
                ),
                if (_snapshot?['selecting'] == true)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _perform(_cancelSelection),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel selection'),
                  ),
                if (_saveError != null)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _perform(_persist),
                    child: const Text('Retry YAML save'),
                  ),
              ],
            ),
          ),
          if ((_snapshot?['selection'] as Map?)?['issue'] != null)
            Text(
              (_snapshot!['selection'] as Map)['issue'] as String,
              style: const TextStyle(color: Colors.red),
            ),
          if (_snapshot?['selecting'] == true)
            const Text('Select a widget in the app.'),
          if ((_busy && !_dialogOpen) || _saving)
            const LinearProgressIndicator(),
          if (writer != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _saveError == null && saved != null
                          ? 'Journey YAML saved'
                          : 'Journey YAML awaiting save',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SelectableText(writer.yamlUri.toFilePath()),
                    if (saved != null)
                      Text(
                        'Last saved: ${saved.state}, ${saved.steps.length} actions, ${saved.screenshots.length} screenshots.',
                      ),
                    const Text(
                      'Re-recording this name replaces this YAML, not your input implementation. '
                      'Do not manually edit YAML while recording. Interrupted recordings remain marked recording and are not generated. '
                      'Record always starts a fresh flow; no runtime session identifiers are saved.',
                    ),
                    const Text(
                      'After stopping, run in the app project terminal:',
                    ),
                    SelectableText(writer.root.toFilePath()),
                    SelectableText(writer.generateCommand),
                    TextButton(
                      onPressed: () => _perform(() async {
                        await Clipboard.setData(
                          ClipboardData(text: writer.generateCommand),
                        );
                        if (mounted) {
                          setState(
                            () => _notice =
                                'Generator command copied. Run it in ${writer.root.toFilePath()}.',
                          );
                        }
                      }),
                      child: const Text('Copy generator command'),
                    ),
                    const Text(
                      'The CLI generates Patrol steps, an abstract input contract, and a one-time input provider scaffold. '
                      'Implement the getters in *_inputs.dart, then flutter analyze and run Patrol. No input values are needed during recording.',
                    ),
                    if (saved != null)
                      ExpansionTile(
                        title: const Text('YAML source preview'),
                        children: [SelectableText(saved.toYaml())],
                      ),
                  ],
                ),
              ),
            ),
          if (_snapshot?['error'] != null)
            CheckboxListTile(
              title: Text('Incomplete recording: ${_snapshot!['error']}'),
              subtitle: const Text(
                'I reviewed the incomplete recording and accept the included actions.',
              ),
              value: _reviewedIncomplete,
              onChanged: _busy || writer == null
                  ? null
                  : (value) => _perform(() async {
                      setState(() => _reviewedIncomplete = value!);
                      await _persist();
                    }),
            ),
          Text(
            'Recorded actions (${steps.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Review required actions before generating. Unchecked actions stay documented in YAML but will not be replayed.',
          ),
          for (final step in steps)
            CheckboxListTile(
              key: ValueKey(step.id),
              contentPadding: EdgeInsets.zero,
              value: !_excluded.contains(step.id),
              onChanged: _busy || writer == null || state == 'recording'
                  ? null
                  : (value) => _perform(() async {
                      setState(() {
                        if (value == true) {
                          _excluded.remove(step.id);
                        } else {
                          _excluded.add(step.id);
                        }
                      });
                      await _persist();
                    }),
              title: Text(
                '${step.id}: ${step.action.name}${step.target.issue == null ? '' : ' - needs review'}',
              ),
              subtitle: Text(
                step.target.issue ??
                    '${step.target.toJson()}'
                        '${step.text == null ? '' : '\nInline link: ${step.text}'}'
                        '${step.scrollDirection == null ? '' : '\nScroll ${step.scrollDirection!.name} in ${step.scrollView?.toJson() ?? 'the Scrollable containing the target'}'}'
                        '${step.expectation == null ? '' : '\nExpect: ${step.expectation!.toJson()}'}'
                        '${step.input == null ? '' : '\nInput: {{${step.input}}}${step.secret ? ' (secret)' : ''}'}',
              ),
            ),
          Text(
            'Screenshots (${saved?.screenshots.length ?? _captures.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Visible Flutter viewport only; sensitive/obscured regions are masked. '
            'Images save immediately to the configured screenshot directory. Removing a reference does not delete a saved PNG.',
          ),
          if (saved != null)
            for (final capture in saved.screenshots)
              ListTile(
                title: Text(
                  '${capture.name}: ${capture.afterStep ?? 'before first action'}',
                ),
                subtitle: SelectableText(
                  writer!.root.resolve(capture.path).toFilePath(),
                ),
                trailing: IconButton(
                  tooltip: 'Remove screenshot reference',
                  icon: const Icon(Icons.close),
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                          setState(() {
                            _captures.removeWhere(
                              (c) => c.name == capture.name,
                            );
                          });
                          await _persist();
                        }),
                ),
              ),
          for (final capture in _captures)
            SizedBox(height: 180, child: Image.memory(capture.bytes)),
        ],
      ),
    );
  }
}
