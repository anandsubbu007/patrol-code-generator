import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../model.dart';

part 'observation.dart';
part 'scroll_observation.dart';
part 'text_observation.dart';

class RecorderScreenshot {
  const RecorderScreenshot({
    required this.bytes,
    required this.width,
    required this.height,
    required this.stepId,
    required this.sessionId,
    required this.captureId,
    required this.redactedRegions,
    required this.suggestedName,
    required this.nameSource,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String? stepId;
  final String sessionId;
  final String captureId;
  final int redactedRegions;
  final String suggestedName;
  final String nameSource;

  Map<String, Object?> toJson() => {
    'kind': 'flutterContent',
    'png': base64Encode(bytes),
    'width': width,
    'height': height,
    'stepId': stepId,
    'sessionId': sessionId,
    'captureId': captureId,
    'redactedRegions': redactedRegions,
    'suggestedName': suggestedName,
    'nameSource': nameSource,
    'extent': 'visibleViewport',
  };
}

/// Owns automatic observations. Input values are never buffered or transported.
class RecorderController extends ChangeNotifier {
  RecorderController({RecorderAppConfig? config, this.maxSteps = 500})
    : config = config ?? RecorderAppConfig() {
    if (maxSteps <= 0) throw ArgumentError('maxSteps must be positive.');
  }

  final RecorderAppConfig config;
  final int maxSteps;
  final _boundaryKey = GlobalKey();
  final _steps = <RecordedStep>[];
  RecordingState _state = RecordingState.ready;
  String? _sessionId;
  String? _error;
  bool _capturing = false;
  _RecorderObserver? _observer;
  int _captures = 0;
  int _revision = 0;

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
    if (_state != RecordingState.ready || _sessionId == null) {
      _sessionId = 'session_${DateTime.now().microsecondsSinceEpoch}';
      _captures = 0;
    }
    _steps.clear();
    _revision = 0;
    _error = null;
    _state = RecordingState.recording;
    _observer?.start();
    _changed();
  }

  void stop() {
    if (_state != RecordingState.recording) {
      throw StateError('No recording is active.');
    }
    _observer?.flushScroll();
    _state = RecordingState.stopped;
    _observer?.stop();
    _changed();
  }

  void _problem(String message) {
    if (_steps.isNotEmpty && _steps.last.target.issue == message) return;
    _record(
      RecordedAction.unsupported,
      RecorderTarget(issue: message),
      source: ObservationSource.pointerGesture,
    );
  }

  void _record(
    RecordedAction action,
    RecorderTarget target, {
    String? input,
    bool secret = false,
    required ObservationSource source,
    String? text,
    RecorderTarget? scrollView,
    RecordedScrollDirection? scrollDirection,
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
        text: text,
        scrollView: scrollView,
        scrollDirection: scrollDirection,
      ),
    );
    _changed();
  }

  Map<String, Object?> snapshot() => {
    'protocolVersion': recorderProtocolVersion,
    'state': _state.name,
    'sessionId': _sessionId,
    'sequence': _revision,
    'steps': _steps.map((step) => step.toJson()).toList(),
    'config': config.toJson(),
    'error': _error,
    'screenshotSupported': kDebugMode,
    'capabilities': [
      'automaticTapCandidates',
      'focusedInputReferences',
      'keyFirstScopedSelectors',
      'noCoordinateFallback',
      'flutterContentScreenshot',
      'inlineTextTap',
      'targetBasedScroll',
      'longPressCandidates',
    ],
  };

  void _changed() {
    _revision++;
    notifyListeners();
    if (kDebugMode) developer.postEvent(recorderEventKind, snapshot());
  }

  List<ui.Rect> _privateRegions(RenderRepaintBoundary boundary) {
    final root = _boundaryKey.currentContext;
    if (root is! Element) throw StateError('No RecorderScope is attached.');
    final tree = _TargetTree(root);
    if (!tree.complete) {
      throw StateError('Capture privacy scan exceeded its limit.');
    }
    final regions = <ui.Rect>[];
    for (final element in tree.nodes) {
      final widget = element.widget;
      if (widget is! RecorderSensitive &&
          widget is! RecorderIgnore &&
          !(widget is EditableText && widget.obscureText)) {
        continue;
      }
      var target = element;
      if (widget is EditableText) {
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget is TextField) {
            target = ancestor;
            return false;
          }
          return ancestor != root;
        });
      }
      final render = target.findRenderObject();
      if (render is! RenderBox || !render.attached || !render.hasSize) {
        throw StateError(
          'Cannot safely locate a private region. Wait for layout and retry.',
        );
      }
      final rect = MatrixUtils.transformRect(
        render.getTransformTo(boundary),
        Offset.zero & render.size,
      ).inflate(2);
      if (!rect.isFinite) {
        throw StateError('Cannot safely mask private content.');
      }
      final clipped = rect.intersect(Offset.zero & boundary.size);
      if (!clipped.isEmpty) regions.add(clipped);
    }
    return regions;
  }

  (String, String) _pageName() {
    final root = _boundaryKey.currentContext;
    if (root is! Element) return ('screen', 'fallback');
    final tree = _TargetTree(root);
    final scopes = tree.nodes
        .where((e) {
          final widget = e.widget;
          if (widget is! Semantics || tree.private(e)) return false;
          final route = ModalRoute.of(e);
          return (route == null || route.isCurrent) &&
              (widget.properties.scopesRoute == true ||
                  widget.properties.namesRoute == true);
        })
        .toList()
        .reversed;
    for (final element in scopes) {
      final id = (element.widget as Semantics).properties.identifier;
      if (id != null && id.isNotEmpty) {
        return (screenshotName(id), 'page semantics identifier');
      }
    }
    for (final element in scopes) {
      final label = (element.widget as Semantics).properties.label;
      if (label != null && label.isNotEmpty) {
        return (screenshotName(label), 'page semantics label');
      }
    }
    final pages = tree.nodes
        .where(
          (e) =>
              e.widget is Scaffold ||
              e.widget is Dialog ||
              e.widget is AlertDialog ||
              e.widget is BottomSheet,
        )
        .toList()
        .reversed;
    for (final element in pages) {
      final route = ModalRoute.of(element);
      if (route != null && !route.isCurrent || tree.private(element)) continue;
      final routeName = route?.settings.name;
      if (routeName != null &&
          routeName != '/' &&
          !routeName.contains('?') &&
          !routeName.contains('#')) {
        return (screenshotName(routeName), 'route name');
      }
      String? type;
      element.visitAncestorElements((parent) {
        if (parent == root || ModalRoute.of(parent) != route) return false;
        final widget = parent.widget;
        if ((widget is StatelessWidget || widget is StatefulWidget) &&
            widget is! Builder &&
            widget is! Container &&
            widget is! SafeArea &&
            !widget.runtimeType.toString().startsWith('_')) {
          type = widget.runtimeType.toString();
          return false;
        }
        return true;
      });
      return (
        screenshotName(type ?? element.widget.runtimeType.toString()),
        'page widget type',
      );
    }
    return ('screen', 'fallback');
  }

  Future<RecorderScreenshot> capture() async {
    if (!kDebugMode) throw StateError('Capture requires a debug app.');
    if (_capturing) throw StateError('A screenshot is already in progress.');
    _sessionId ??= 'session_${DateTime.now().microsecondsSinceEpoch}';
    final sessionId = _sessionId!;
    final stepId = _steps.isEmpty ? null : _steps.last.id;
    final captureId = 'capture_${(++_captures).toString().padLeft(4, '0')}';
    _capturing = true;
    try {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 5),
      );
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
      final regions = _privateRegions(renderObject);
      final (suggestedName, nameSource) = _pageName();
      final image = await renderObject.toImage(pixelRatio: 1);
      try {
        regions.addAll(_privateRegions(renderObject));
        final pictureRecorder = ui.PictureRecorder();
        final canvas = ui.Canvas(pictureRecorder);
        canvas.drawImage(image, Offset.zero, ui.Paint());
        for (final rect in regions) {
          canvas.drawRect(rect, ui.Paint()..color = const Color(0xFF202020));
        }
        final picture = pictureRecorder.endRecording();
        final masked = await picture.toImage(image.width, image.height);
        picture.dispose();
        final ByteData? data;
        try {
          data = await masked.toByteData(format: ui.ImageByteFormat.png);
        } finally {
          masked.dispose();
        }
        if (data == null || data.lengthInBytes > 4 * 1024 * 1024) {
          throw StateError(
            'PNG capture failed or exceeded the 4 MiB transfer limit.',
          );
        }
        return RecorderScreenshot(
          bytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          width: image.width,
          height: image.height,
          stepId: stepId,
          sessionId: sessionId,
          captureId: captureId,
          redactedRegions: regions.toSet().length,
          suggestedName: suggestedName,
          nameSource: nameSource,
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
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            widget.controller._observer?.observeScroll(notification);
            return false;
          },
          child: widget.child,
        ),
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

/// Treats descendant input as secret and masks this region in screenshots.
class RecorderSensitive extends StatelessWidget {
  const RecorderSensitive({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Excludes subtree interactions and masks the region in screenshots.
class RecorderIgnore extends StatelessWidget {
  const RecorderIgnore({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
