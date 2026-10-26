import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patrol_recorder/patrol_recorder.dart';

import 'src/backend.dart';
import 'src/expectation_dialog.dart';

class RecorderPanel extends StatefulWidget {
  const RecorderPanel({super.key, required this.backend});
  final RecorderBackend backend;

  @override
  State<RecorderPanel> createState() => _RecorderPanelState();
}

class _RecorderPanelState extends State<RecorderPanel> {
  Timer? _timer;
  Future<void>? _refreshTask;
  Map<String, dynamic>? _snapshot;
  String? _error;
  String? _connectionError;
  bool _connected = false;
  bool _busy = false;
  bool _dialogOpen = false;
  bool _reviewedIncomplete = false;
  bool _textSelection = false;
  final _excluded = <String>{};
  Uint8List? _capture;

  List<RecordedStep> get _steps => [
    for (final raw in _snapshot?['steps'] as List? ?? [])
      RecordedStep.fromJson(Map<String, dynamic>.from(raw as Map)),
  ];

  void _accept(Map<String, dynamic> snapshot) {
    if (_snapshot?['sessionId'] != snapshot['sessionId']) {
      _excluded.clear();
      _reviewedIncomplete = false;
      _capture = null;
    }
    if (_snapshot?['error'] != snapshot['error']) {
      _reviewedIncomplete = false;
    }
    _snapshot = snapshot;
    _connected = true;
  }

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
    if (_busy || _refreshTask != null) return;
    _refreshTask = _readSnapshot().whenComplete(() => _refreshTask = null);
  }

  Future<void> _readSnapshot() async {
    try {
      final snapshot = await widget.backend.command('snapshot');
      if (!mounted) return;
      setState(() {
        _accept(snapshot);
        _connectionError = null;
      });
      if (!_dialogOpen &&
          snapshot['selecting'] == true &&
          (snapshot['selection'] as Map?)?['selector'] != null) {
        unawaited(_perform(_configureExpectation));
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionError = '$error';
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionError = error.message;
        });
      }
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _refreshTask;
      if (mounted) await action();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _command(
    String command, {
    Map<String, String> parameters = const {},
  }) async {
    final snapshot = await widget.backend.command(
      command,
      parameters: parameters,
    );
    if (mounted) setState(() => _accept(snapshot));
  }

  Future<void> _start() async {
    final addKey = await widget.backend.addKeyEnabled();
    await _command('configure', parameters: {'addkey': '$addKey'});
    await _command('start');
    if (mounted) {
      setState(() {
        _excluded.clear();
        _reviewedIncomplete = false;
        _capture = null;
      });
    }
  }

  Future<void> _configureExpectation() async {
    _dialogOpen = true;
    try {
      final expectation = await showDialog<ExpectationSpec>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ExpectationDialog(
          target: RecorderTarget.fromJson(
            Map<String, dynamic>.from(_snapshot!['selection'] as Map),
          ),
          suggestedText: _snapshot?['selectionText'] as String?,
        ),
      );
      if (!mounted) return;
      if (expectation == null) {
        await _command('cancelSelection');
      } else {
        await _command(
          'confirmExpectation',
          parameters: {'expectation': jsonEncode(expectation.toJson())},
        );
      }
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _captureScreen() async {
    final snapshot = await widget.backend.command('capture');
    final info = snapshot['screenshot'] as Map?;
    if (info?['kind'] != 'flutterContent' || info?['png'] is! String) {
      throw const FormatException('The app did not return a viewport PNG.');
    }
    final bytes = base64Decode(info!['png'] as String);
    if (bytes.length < 8 ||
        base64Encode(bytes.sublist(0, 8)) != 'iVBORw0KGgo=') {
      throw const FormatException('The app returned an invalid PNG.');
    }
    if (mounted) setState(() => _capture = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    String? code;
    String? codeIssue;
    try {
      code = patrolCode(steps.where((step) => !_excluded.contains(step.id)));
    } on FormatException catch (error) {
      codeIssue = error.message;
    }
    final recording = _snapshot?['state'] == 'recording';
    final incomplete = _snapshot?['error'] as String?;
    final canCopy =
        !_busy &&
        code != null &&
        code.isNotEmpty &&
        (incomplete == null || _reviewedIncomplete);
    return Scaffold(
      appBar: AppBar(title: const Text('Patrol Recorder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _connected ? 'Connected - ${_snapshot?['state']}' : 'Disconnected - last code retained; new actions are not captured',
          ),
          const Text(
            'Record, review, then copy Patrol Dart into your test. No recording files or generator commands.',
          ),
          const Text(
            'Supply input variables yourself. Typed values are never included.',
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_connectionError != null)
            Text(_connectionError!, style: const TextStyle(color: Colors.red)),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: !_busy && _connected && !recording
                    ? () => _perform(_start)
                    : null,
                child: const Text('Record'),
              ),
              OutlinedButton(
                onPressed: !_busy && _connected && recording
                    ? () => _perform(() => _command('stop'))
                    : null,
                child: const Text('Stop recording'),
              ),
              OutlinedButton(
                onPressed: canCopy
                    ? () => _perform(() async {
                        await Clipboard.setData(ClipboardData(text: code!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Patrol code copied')),
                          );
                        }
                      })
                    : null,
                child: const Text('Copy Patrol code'),
              ),
              OutlinedButton(
                onPressed: !_busy && _connected
                    ? () => _perform(_captureScreen)
                    : null,
                child: const Text('Capture visible screen'),
              ),
            ],
          ),
          if (_busy && !_dialogOpen) const LinearProgressIndicator(),
          SwitchListTile(
            title: const Text('Validate text instead of component'),
            value: _textSelection,
            onChanged: _busy
                ? null
                : (value) => setState(() => _textSelection = value),
          ),
          Wrap(
            children: [
              TextButton(
                onPressed:
                    !_busy &&
                        _connected &&
                        recording &&
                        _snapshot?['selecting'] != true
                    ? () => _perform(
                        () => _command(
                          'selectTarget',
                          parameters: {
                            'kind': _textSelection ? 'text' : 'component',
                          },
                        ),
                      )
                    : null,
                child: const Text('Add expectation'),
              ),
              if (_snapshot?['selecting'] == true)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(() => _command('cancelSelection')),
                  child: const Text('Cancel selection'),
                ),
            ],
          ),
          if (_snapshot?['selecting'] == true)
            const Text('Select a widget in the app.'),
          if ((_snapshot?['selection'] as Map?)?['issue'] != null)
            Text(
              '${(_snapshot!['selection'] as Map)['issue']}',
              style: const TextStyle(color: Colors.red),
            ),
          if (incomplete != null)
            CheckboxListTile(
              title: Text('Incomplete recording: $incomplete'),
              subtitle: const Text(
                'I reviewed the incomplete recording and accept the included actions.',
              ),
              value: _reviewedIncomplete,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _reviewedIncomplete = value!),
            ),
          if (codeIssue != null)
            Text(
              'Review required: $codeIssue',
              style: const TextStyle(color: Colors.red),
            ),
          const Text('Patrol Dart'),
          SelectableText(
            code ?? 'Resolve or explicitly exclude the flagged actions to preview runnable code.',
            key: const ValueKey('patrol_code'),
          ),
          const Text(
            'Recorded actions - uncheck only actions you intentionally want to omit.',
          ),
          for (final step in steps)
            CheckboxListTile(
              key: ValueKey(step.id),
              value: !_excluded.contains(step.id),
              onChanged: _busy || recording
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        _excluded.remove(step.id);
                      } else {
                        _excluded.add(step.id);
                      }
                    }),
              title: Text('${step.id}: ${step.action.name}'),
              subtitle: Text(step.target.issue ?? '${step.target.toJson()}'),
            ),
          for (final raw in _snapshot?['keySuggestions'] as List? ?? [])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  'Suggested key for ${raw['widget']}: key: const ValueKey("${raw['key']}")\n'
                  '${raw['tree']}\nReview the source location and add the key yourself, then rebuild and re-record. No source edits have been applied.',
                ),
              ),
            ),
          if (_capture != null) ...[
            const Text(
              'Visible screen preview (masked private regions, not saved to disk)',
            ),
            Image.memory(_capture!),
          ],
        ],
      ),
    );
  }
}
