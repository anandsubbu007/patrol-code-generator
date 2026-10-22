import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../model.dart';

part 'observation.dart';

class RecorderScreenshot {
  const RecorderScreenshot({
    required this.bytes,
    required this.width,
    required this.height,
    required this.stepId,
    required this.sessionId,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String stepId;
  final String sessionId;

  Map<String, Object> toJson() => {
    'kind': 'flutterContent',
    'png': base64Encode(bytes),
    'width': width,
    'height': height,
    'stepId': stepId,
    'sessionId': sessionId,
  };
}

/// Owns automatic observations. Input values are never buffered or transported.
class RecorderController extends ChangeNotifier {
  RecorderController({required this.config, this.maxSteps = 500}) {
    if (maxSteps <= 0) throw ArgumentError('maxSteps must be positive.');
  }

  final RecorderAppConfig config;
  final int maxSteps;
  final _boundaryKey = GlobalKey();
  final _steps = <RecordedStep>[];
  RecordingState _state = RecordingState.ready;
  String? _sessionId;
  String? _error;
  int _sensitiveRegions = 0;
  bool _capturing = false;
  _RecorderObserver? _observer;

  RecordingState get state => _state;
  List<RecordedStep> get steps => List.unmodifiable(_steps);
  String? get error => _error;

  void start() {
    if (!kDebugMode) {
      throw StateError('Recording is only supported in debug mode.');
    }
    if (_observer == null || _boundaryKey.currentContext == null) {
      throw StateError('Mount RecorderScope before starting a recording.');
    }
    if (_capturing || _state == RecordingState.recording) {
      throw StateError(
        'Stop the current operation before starting another recording.',
      );
    }
    _steps.clear();
    _sessionId = 'session_${DateTime.now().microsecondsSinceEpoch}';
    _error = null;
    _state = RecordingState.recording;
    _observer?.start();
    _changed();
  }

  void stop() {
    if (_state != RecordingState.recording) {
      throw StateError('No recording is active.');
    }
    _state = RecordingState.stopped;
    _observer?.stop();
    _changed();
  }

  void _problem(String message) {
    if (_error == message) return;
    _error = message;
    _changed();
  }

  void _record(
    RecordedAction action,
    RecorderTarget target, {
    String? input,
    bool secret = false,
    required ObservationSource source,
  }) {
    if (!kDebugMode || _state != RecordingState.recording) return;
    if (input != null) requireIdentifier(input, 'Input reference');
    if (_steps.isNotEmpty && action == RecordedAction.enterText) {
      final last = _steps.last;
      if (last.action == action &&
          last.target.identity == target.identity &&
          last.input == input &&
          last.secret == secret) {
        return; // Consecutive edits represent one final-value input reference.
      }
    }
    if (_steps.length >= maxSteps) {
      _error =
          'Recording stopped at the $maxSteps-step limit. Save before continuing.';
      _state = RecordingState.stopped;
      _observer?.stop();
      _changed();
      return;
    }
    _steps.add(
      RecordedStep(
        id: 'step_${(_steps.length + 1).toString().padLeft(4, '0')}',
        action: action,
        target: target,
        input: input,
        secret: secret,
        source: source,
      ),
    );
    _changed();
  }

  Map<String, Object?> snapshot() => {
    'protocolVersion': recorderProtocolVersion,
    'state': _state.name,
    'sessionId': _sessionId,
    'sequence': _steps.length,
    'steps': _steps.map((step) => step.toJson()).toList(),
    'config': config.toJson(),
    'error': _error,
    'screenshotSupported': kDebugMode && _sensitiveRegions == 0,
    'capabilities': [
      'automaticTapCandidates',
      'focusedInputReferences',
      'keyFirstScopedSelectors',
      'noCoordinateFallback',
      'flutterContentScreenshot',
    ],
  };

  void _changed() {
    notifyListeners();
    if (kDebugMode) developer.postEvent(recorderEventKind, snapshot());
  }

  void _checkCapturePrivacy() {
    if (_sensitiveRegions > 0) {
      throw StateError('Capture blocked: a sensitive region is mounted.');
    }
    final root = _boundaryKey.currentContext;
    if (root is! Element) throw StateError('No RecorderScope is attached.');
    final tree = _TargetTree(root);
    if (!tree.complete ||
        tree.nodes.any(
          (e) =>
              e.widget is RecorderIgnore ||
              e.widget is EditableText &&
                  (e.widget as EditableText).obscureText,
        )) {
      throw StateError(
        'Capture blocked: obscured/ignored content or discovery limit.',
      );
    }
  }

  Future<RecorderScreenshot> capture() async {
    if (!kDebugMode || _state != RecordingState.stopped || _steps.isEmpty) {
      throw StateError('Stop a nonempty debug recording before capturing.');
    }
    _checkCapturePrivacy();
    if (_capturing) throw StateError('A screenshot is already in progress.');
    _capturing = true;
    try {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 5),
      );
      _checkCapturePrivacy();
      final renderObject = _boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary ||
          renderObject.debugNeedsPaint) {
        throw StateError('Flutter content has not painted yet.');
      }
      if (renderObject.size.width * renderObject.size.height > 8000000) {
        throw StateError(
          'Flutter content exceeds the 8-megapixel capture limit.',
        );
      }
      final image = await renderObject.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null || data.lengthInBytes > 4 * 1024 * 1024) {
          throw StateError(
            'PNG capture failed or exceeded the 4 MiB transfer limit.',
          );
        }
        _checkCapturePrivacy();
        return RecorderScreenshot(
          bytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          width: image.width,
          height: image.height,
          stepId: _steps.last.id,
          sessionId: _sessionId!,
        );
      } finally {
        image.dispose();
      }
    } finally {
      _capturing = false;
    }
  }
}

RecorderController? _activeRecorder;
bool _registered = false;

void _registerService() {
  if (!kDebugMode || _registered) return;
  _registered = true;
  developer.registerExtension(recorderServiceMethod, (_, parameters) async {
    try {
      final recorder = _activeRecorder;
      if (recorder == null) throw StateError('No RecorderScope is attached.');
      switch (parameters['command']) {
        case 'snapshot':
          break;
        case 'start':
          recorder.start();
        case 'stop':
          recorder.stop();
        case 'capture':
          final screenshot = await recorder.capture();
          return developer.ServiceExtensionResponse.result(
            jsonEncode({
              ...recorder.snapshot(),
              'screenshot': screenshot.toJson(),
            }),
          );
        default:
          throw const FormatException('Unsupported recorder command.');
      }
      return developer.ServiceExtensionResponse.result(
        jsonEncode(recorder.snapshot()),
      );
    } on StateError catch (error) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        error.message,
      );
    } on FormatException catch (error) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        error.message,
      );
    }
  });
}

/// Installs the debug recorder and the Flutter-content screenshot boundary.
class RecorderScope extends StatefulWidget {
  const RecorderScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final RecorderController controller;
  final Widget child;

  static RecorderController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_RecorderInherited>()
      ?.controller;

  @override
  State<RecorderScope> createState() => _RecorderScopeState();
}

class _RecorderScopeState extends State<RecorderScope> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      if (_activeRecorder != null) {
        throw StateError('Only one RecorderScope may be attached.');
      }
      _activeRecorder = widget.controller;
      widget.controller._observer = _RecorderObserver(widget.controller);
      _registerService();
    }
  }

  @override
  void didUpdateWidget(RecorderScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      throw StateError(
        'Keep RecorderScope.controller stable for the scope lifetime.',
      );
    }
  }

  @override
  void dispose() {
    widget.controller._observer?.dispose();
    widget.controller._observer = null;
    if (identical(_activeRecorder, widget.controller)) _activeRecorder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;
    return _RecorderInherited(
      controller: widget.controller,
      child: RepaintBoundary(
        key: widget.controller._boundaryKey,
        child: widget.child,
      ),
    );
  }
}

class _RecorderInherited extends InheritedWidget {
  const _RecorderInherited({required this.controller, required super.child});
  final RecorderController controller;
  @override
  bool updateShouldNotify(_RecorderInherited oldWidget) =>
      controller != oldWidget.controller;
}

/// Conservatively blocks screenshots while this subtree is mounted.
class RecorderSensitive extends StatefulWidget {
  const RecorderSensitive({super.key, required this.child});
  final Widget child;
  @override
  State<RecorderSensitive> createState() => _RecorderSensitiveState();
}

class _RecorderSensitiveState extends State<RecorderSensitive> {
  RecorderController? _controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = RecorderScope.maybeOf(context);
    if (identical(next, _controller)) return;
    _controller?._sensitiveRegions--;
    _controller = next;
    _controller?._sensitiveRegions++;
  }

  @override
  void dispose() {
    _controller?._sensitiveRegions--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Excludes subtree interactions and conservatively blocks screenshots.
class RecorderIgnore extends StatelessWidget {
  const RecorderIgnore({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
