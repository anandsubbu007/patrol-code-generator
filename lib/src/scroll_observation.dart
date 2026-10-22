part of 'recorder.dart';

class _ScrollTrace {
  _ScrollTrace(this.state, this.element, this.view, this.start, this.axis, this.source)
      : position = state.position;
  final ScrollableState state;
  final Element element;
  final RecorderTarget view;
  final double start;
  final AxisDirection axis;
  final ObservationSource source;
  final ScrollPosition position;
  late final VoidCallback onPixels;
  late final VoidCallback onActivity;
  double delta = 0;
  void dispose() {
    position.removeListener(onPixels);
    position.isScrollingNotifier.removeListener(onActivity);
  }
}

extension _ScrollObservation on _RecorderObserver {
  Element _scrollElement(ScrollableState state) {
    final element = state.context as Element;
    Element? view;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Scrollable || ancestor == root) return false;
      if (ancestor.widget is ScrollView ||
          ancestor.widget is SingleChildScrollView) {
        if (ancestor.widget.key.runtimeType == (ValueKey<String>)) {
          view = ancestor;
        }
        return false;
      }
      return true;
    });
    return view ?? element;
  }

  Map<ScrollableState, double> scrollAncestors(Element leaf) {
    final result = <ScrollableState, double>{};
    void add(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        result[state] = state.position.pixels;
      }
    }
    add(leaf);
    leaf.visitAncestorElements((e) { add(e); return e != root; });
    return result;
  }

  void _finishAfterFrame(_ScrollTrace trace) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active && identical(_scrolls[trace.state], trace) &&
          (!trace.state.mounted || !trace.position.isScrollingNotifier.value)) {
        _finishScroll(trace.state);
      }
    });
  }

  void _beginScroll(ScrollableState state, {
    double? start, ObservationSource source = ObservationSource.scrollNotification,
  }) {
    if (!_active || root == null || _scrolls.containsKey(state)) return;
    final element = _scrollElement(state);
    if (!_within(element, root!) ||
        _marked<RecorderIgnore>(element) ||
        _marked<EditableText>(element)) {
      return;
    }
    final view = _TargetTree(root!).resolve(element, rootOnly: true);
    final trace = _ScrollTrace(
      state,
      element,
      view,
      start ?? state.position.pixels,
      state.axisDirection,
      source,
    );
    trace.onPixels = () => trace.delta = trace.position.pixels - trace.start;
    trace.onActivity = () { if (!trace.position.isScrollingNotifier.value) _finishAfterFrame(trace); };
    _scrolls[state] = trace;
    trace.position.addListener(trace.onPixels);
    trace.position.isScrollingNotifier.addListener(trace.onActivity);
    trace.onPixels();
    for (final pointer in _pointers.values) {
      pointer.scrollHandled = true;
    }
  }

  void observePointerScroll(Offset position, int viewId) {
    if (root == null) return;
    final hit = HitTestResult();
    WidgetsBinding.instance.hitTestInView(hit, position, viewId);
    for (final entry in hit.path) {
      final render = entry.target;
      if (render is! RenderObject || render.debugCreator is! DebugCreator) continue;
      final element = (render.debugCreator as DebugCreator).element;
      if (!_within(element, root!)) continue;
      for (final state in scrollAncestors(element).keys) {
        _beginScroll(state, source: ObservationSource.pointerGesture);
        final trace = _scrolls[state];
        if (trace != null) _finishAfterFrame(trace);
      }
      break;
    }
  }

  void observeDragScroll(_PendingPointer pending) {
    for (final entry in pending.scrollStarts.entries) {
      if (entry.key.mounted && (entry.key.position.pixels != entry.value ||
          entry.key.position.userScrollDirection != ScrollDirection.idle)) {
        _beginScroll(entry.key, start: entry.value, source: ObservationSource.pointerGesture);
      }
    }
  }

  void observeScroll(ScrollNotification notification) {
    if (!_active || notification.context == null) return;
    final state = Scrollable.maybeOf(notification.context!);
    if (state == null || !state.mounted) return;
    if (notification is ScrollStartNotification &&
            notification.dragDetails != null ||
        notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle) {
      _beginScroll(state);
    }
    final trace = _scrolls[state];
    if (trace == null) return;
    trace.delta = notification.metrics.pixels - trace.start;
    if (notification is ScrollEndNotification) {
      _finishAfterFrame(trace);
    }
  }

  void beginSemanticsScroll(ui.SemanticsActionEvent event) {
    if (root == null) return;
    final tree = _TargetTree(root!);
    final cache = <int, bool>{};
    bool contains(SemanticsNode? node) {
      if (node == null) return false;
      if (node.id == event.nodeId) return true;
      if (cache.containsKey(node.id)) return cache[node.id]!;
      var found = false;
      node.visitChildren((child) {
        found = contains(child);
        return !found;
      });
      return cache[node.id] = found;
    }

    for (final element
        in tree.nodes.whereType<RenderObjectElement>().toList().reversed) {
      if (!contains(element.renderObject.debugSemantics) ||
          View.of(element).viewId != event.viewId) {
        continue;
      }
      final state = Scrollable.maybeOf(element);
      if (state != null) {
        _beginScroll(state);
        return;
      }
      final matches = tree.nodes
          .whereType<StatefulElement>()
          .where((e) => e.state is ScrollableState && _within(e, element))
          .toList();
      if (matches.length == 1) {
        _beginScroll(matches.single.state as ScrollableState);
        return;
      }
    }
    recorder._problem(
      'Cannot identify the scrolling view. Add key: const ValueKey<String>("unique_list_id") '
      'to the ListView/GridView/SingleChildScrollView, then re-record.',
    );
  }

  RecordedScrollDirection _direction(_ScrollTrace trace) {
    final axis = trace.delta >= 0 ? trace.axis : flipAxisDirection(trace.axis);
    return RecordedScrollDirection.values.singleWhere(
      (d) => d.name == axis.name,
    );
  }

  RecorderTarget _visibleAnchor(_ScrollTrace trace) {
    final tree = _TargetTree(root!);
    final viewport = trace.element.findRenderObject();
    if (!tree.complete || viewport is! RenderBox || !viewport.hasSize) {
      return RecorderTarget(
        issue: 'Scroll destination cannot be inspected yet. Wait for layout/data, then tap the desired keyed item.',
      );
    }
    final rect = Offset.zero & viewport.size;
    final horizontal = axisDirectionToAxis(trace.axis) == Axis.horizontal;
    final forward =
        _direction(trace) == RecordedScrollDirection.down ||
        _direction(trace) == RecordedScrollDirection.right;
    final candidates = <(Element, double, bool)>[];
    final loading = tree.nodes
        .where(
          (e) =>
              e.widget is CircularProgressIndicator ||
              e.widget is LinearProgressIndicator,
        )
        .toList();
    for (final element in tree.nodes) {
      if (element == trace.element || !_within(element, trace.element)) {
        continue;
      }
      final keyed = element.widget.key.runtimeType == (ValueKey<String>);
      if (tree.private(element) && !keyed) continue;
      if (!keyed && element.widget is! Text) continue;
      if (element.widget is CircularProgressIndicator ||
          element.widget is LinearProgressIndicator) {
        continue;
      }
      final render = element.findRenderObject();
      if (render is! RenderBox ||
          !render.attached ||
          !render.hasSize ||
          render == viewport) {
        continue;
      }
      final bounds = MatrixUtils.transformRect(
        render.getTransformTo(viewport),
        Offset.zero & render.size,
      );
      if (bounds.isEmpty || !rect.contains(bounds.center)) continue;
      if (loading.any((e) => _within(e, element))) continue;
      candidates.add((
        element,
        horizontal ? bounds.center.dx : bounds.center.dy,
        keyed,
      ));
    }
    candidates.sort((a, b) {
      if (a.$3 != b.$3) return a.$3 ? -1 : 1;
      return forward ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2);
    });
    for (final candidate in candidates.take(30)) {
      final target = tree.resolve(
        candidate.$1,
        rootOnly: true,
        secret: tree.private(candidate.$1),
      );
      if (target.issue == null) return target;
    }
    return RecorderTarget(
      issue:
          'No unique visible scroll destination. Tap the desired item after scrolling, '
          'or add a unique ValueKey to that item and re-record. Coordinate drags were not generated.',
    );
  }

  void _finishScroll(ScrollableState state) {
    final trace = _scrolls.remove(state);
    if (trace == null) return;
    trace.dispose();
    if (trace.delta.abs() < 1 || root == null) return;
    if (state.mounted && !identical(state.position, trace.position)) {
      recorder._problem('The ScrollPosition changed during the gesture. Keep the ScrollController and widget key stable, '
        'or wait for the view to finish rebuilding and re-record.');
      return;
    }
    if (trace.view.issue != null) {
      recorder._problem('Scrolling view needs a key. ${trace.view.issue}');
      return;
    }
    if (!trace.element.mounted) {
      recorder._problem(
        'Scrolling view was disposed before its target was identified. Wait for loading to finish and tap a stable item.',
      );
      return;
    }
    final target = _visibleAnchor(trace);
    final direction = _direction(trace);
    final last = recorder._steps.isEmpty ? null : recorder._steps.last;
    if (last?.action == RecordedAction.scrollUntilVisible &&
        last!.scrollView!.identity == trace.view.identity &&
        last.scrollDirection == direction) {
      recorder._steps[recorder._steps.length - 1] = RecordedStep(
        id: last.id,
        action: last.action,
        target: target,
        source: trace.source,
        scrollView: trace.view,
        scrollDirection: direction,
      );
      recorder._changed();
    } else {
      recorder._record(
        RecordedAction.scrollUntilVisible,
        target,
        source: trace.source,
        scrollView: trace.view,
        scrollDirection: direction,
      );
    }
    _lastScrollElement = trace.element;
  }

  void flushScroll() {
    if (!_active || _flushingScroll) return;
    _flushingScroll = true;
    try {
      for (final state in _scrolls.keys.toList()) {
        final trace = _scrolls[state]!;
        if (state.mounted) trace.delta = state.position.pixels - trace.start;
        _finishScroll(state);
      }
    } finally {
      _flushingScroll = false;
    }
  }

  void anchorRecentScroll(RecorderTarget target, Element? element) {
    final last = recorder._steps.isEmpty ? null : recorder._steps.last;
    final view = _lastScrollElement;
    if (last?.action != RecordedAction.scrollUntilVisible ||
        target.issue != null ||
        element == null ||
        !element.mounted ||
        view == null ||
        !view.mounted ||
        !_within(element, view)) {
      return;
    }
    recorder._steps[recorder._steps.length - 1] = RecordedStep(
      id: last!.id,
      action: last.action,
      target: target,
      source: last.source,
      scrollView: last.scrollView,
      scrollDirection: last.scrollDirection,
    );
    recorder._changed();
    _lastScrollElement = null;
  }
}
