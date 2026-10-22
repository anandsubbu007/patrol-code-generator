part of 'recorder.dart';

const _widgetTypes = <String, Type>{
  'FilledButton': FilledButton,
  'ElevatedButton': ElevatedButton,
  'TextButton': TextButton,
  'OutlinedButton': OutlinedButton,
  'IconButton': IconButton,
  'FloatingActionButton': FloatingActionButton,
  'InkWell': InkWell,
  'GestureDetector': GestureDetector,
  'TextField': TextField,
  'EditableText': EditableText,
};

bool _within(Element element, Element ancestor) {
  if (identical(element, ancestor)) return true;
  var found = false;
  element.visitAncestorElements((parent) {
    found = identical(parent, ancestor);
    return !found;
  });
  return found;
}

bool _marked<T extends Widget>(Element element) {
  if (element.widget is T) return true;
  var found = false;
  element.visitAncestorElements((parent) {
    found = parent.widget is T;
    return !found;
  });
  return found;
}

class _TargetTree {
  _TargetTree(this.root) {
    void visit(Element element) {
      if (nodes.length >= 10000) {
        complete = false;
        return;
      }
      nodes.add(element);
      element.debugVisitOnstageChildren(visit);
    }

    visit(root);
  }

  final Element root;
  final nodes = <Element>[];
  bool complete = true;

  bool private(Element element) =>
      _marked<RecorderSensitive>(element) ||
      _marked<RecorderIgnore>(element) ||
      _marked<EditableText>(element);

  String? _key(Element element) {
    final key = element.widget.key;
    // Subclasses of ValueKey have different equality; never stringify them.
    return key.runtimeType == (ValueKey<String>)
        ? (key as ValueKey<String>).value
        : null;
  }

  String? _semantics(Element element, bool identifier) {
    if (element is! RenderObjectElement) return null;
    final node = element.renderObject.debugSemantics;
    return identifier ? node?.identifier : node?.label;
  }

  String? _text(Element element) {
    final widget = element.widget;
    // Do not inspect editable values or RichText spans which may contain user data.
    return widget is Text && widget.textSpan == null ? widget.data : null;
  }

  bool matches(
    Element element,
    RecorderSelector selector,
  ) => switch (selector.kind) {
    SelectorKind.key => _key(element) == selector.value,
    SelectorKind.semanticsIdentifier =>
      _semantics(element, true) == selector.value,
    SelectorKind.semanticsLabel =>
      !private(element) && _semantics(element, false) == selector.value,
    SelectorKind.fieldLabel =>
      !private(element) &&
          element.widget is TextField &&
          (element.widget as TextField).decoration?.labelText == selector.value,
    SelectorKind.text => !private(element) && _text(element) == selector.value,
    SelectorKind.widgetType =>
      element.widget.runtimeType == _widgetTypes[selector.value],
  };

  Iterable<RecorderSelector> candidates(
    Element element, {
    bool secret = false,
  }) sync* {
    final key = _key(element);
    if (key != null && key.isNotEmpty && key.length <= 256) {
      yield RecorderSelector(SelectorKind.key, key);
    }
    final id = _semantics(element, true);
    if (id != null && id.isNotEmpty && id.length <= 256) {
      yield RecorderSelector(SelectorKind.semanticsIdentifier, id);
    }
    if (!secret && !private(element)) {
      final label = _semantics(element, false);
      if (label != null && label.isNotEmpty && label.length <= 256) {
        yield RecorderSelector(SelectorKind.semanticsLabel, label);
      }
      final text = _text(element);
      if (text != null && text.isNotEmpty && text.length <= 256) {
        yield RecorderSelector(SelectorKind.text, text);
      }
      final widget = element.widget;
      if (widget is TextField) {
        final label = widget.decoration?.labelText;
        if (label != null && label.isNotEmpty && label.length <= 256) {
          yield RecorderSelector(SelectorKind.fieldLabel, label);
        }
      }
    }
    for (final entry in _widgetTypes.entries) {
      if (element.widget.runtimeType == entry.value) {
        yield RecorderSelector(SelectorKind.widgetType, entry.key);
      }
    }
  }

  RecorderTarget resolve(Element control, {bool secret = false}) {
    if (!complete) {
      return RecorderTarget(issue: 'Target discovery exceeded 10000 elements.');
    }
    final local = nodes.where((e) => _within(e, control)).toList();
    // Include immediately surrounding semantics, never a page-wide keyed ancestor.
    control.visitAncestorElements((e) {
      if (e.widget is Semantics) {
        local.add(e);
        return true;
      }
      return false;
    });
    final choices =
        <(Element, RecorderSelector)>[
          for (final e in local)
            for (final s in candidates(e, secret: secret))
              if (control.widget is! TextField &&
                      control.widget is! EditableText ||
                  // Text entry must locate an ancestor of EditableText, not its label/render leaf.
                  _within(control, e) ||
                  e == control)
                (e, s),
        ]..sort((a, b) {
          final order = a.$2.kind.index.compareTo(b.$2.kind.index);
          return order != 0
              ? order
              : local.indexOf(a.$1).compareTo(local.indexOf(b.$1));
        });
    for (final (element, selector) in choices) {
      final matchesAll = nodes.where((e) => matches(e, selector)).toList();
      final contentSelector =
          selector.kind == SelectorKind.text ||
          selector.kind == SelectorKind.semanticsLabel ||
          selector.kind == SelectorKind.fieldLabel;
      bool privacySafe(Iterable<Element> region) =>
          !contentSelector ||
          !region.any(
            (e) => e.widget is RecorderSensitive || e.widget is RecorderIgnore,
          );
      if (matchesAll.length == 1 &&
          matchesAll.single == element &&
          privacySafe(nodes)) {
        return RecorderTarget(selector: selector);
      }
      RecorderTarget? scoped;
      element.visitAncestorElements((ancestor) {
        if (!_within(ancestor, root)) return false;
        for (final scope in candidates(ancestor, secret: true).where(
          (s) =>
              s.kind == SelectorKind.key ||
              s.kind == SelectorKind.semanticsIdentifier,
        )) {
          if (nodes.where((e) => matches(e, scope)).length != 1) continue;
          final region = nodes.where(
            (e) => e != ancestor && _within(e, ancestor),
          );
          final selected = matchesAll.where(
            (e) => e != ancestor && _within(e, ancestor),
          );
          if (selected.length == 1 &&
              selected.single == element &&
              privacySafe(region)) {
            scoped = RecorderTarget(selector: selector, scope: scope);
            return false;
          }
        }
        return true;
      });
      if (scoped != null) return scoped!;
    }
    return RecorderTarget(
      issue: 'No unique selector. Add a stable key/identifier or uniquely keyed parent and re-record. Coordinates and indexes are disabled.',
    );
  }
}

class _PendingPointer {
  _PendingPointer(this.event, this.target);
  final PointerDownEvent event;
  final RecorderTarget? target;
  bool moved = false;
}

class _RecorderObserver {
  _RecorderObserver(this.recorder);
  final RecorderController recorder;
  final _pointers = <int, _PendingPointer>{};
  final _inputs = <String, String>{};
  final _usedNames = <String>{};
  SemanticsHandle? _semantics;
  Element? _editorElement;
  TextEditingController? _controller;
  RecorderTarget? _inputTarget;
  bool _secret = false;
  bool _active = false;
  int _epoch = 0;

  Element? get root {
    final context = recorder._boundaryKey.currentContext;
    return context is Element ? context : null;
  }

  void start() {
    stop();
    _active = true;
    _inputs.clear();
    _usedNames.clear();
    _semantics = WidgetsBinding.instance.ensureSemantics();
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(_pointer);
    WidgetsBinding.instance.addSemanticsActionListener(_semanticsAction);
    FocusManager.instance.addListener(_focus);
    _focus();
    _watchFrames(_epoch);
  }

  void stop() {
    _epoch++;
    if (_active) {
      WidgetsBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
      WidgetsBinding.instance.removeSemanticsActionListener(_semanticsAction);
      FocusManager.instance.removeListener(_focus);
    }
    _active = false;
    _pointers.clear();
    _detachEditor();
    _semantics?.dispose();
    _semantics = null;
  }

  void dispose() => stop();

  void _watchFrames(int epoch) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_active || epoch != _epoch) return;
      _focus();
      _watchFrames(epoch);
    });
  }

  Element? _control(Element leaf) {
    Element? fallback;
    Element? result;
    void inspect(Element element) {
      final widget = element.widget;
      if (widget is TextField ||
          widget is ButtonStyleButton &&
              _widgetTypes.containsValue(widget.runtimeType) ||
          widget is IconButton ||
          widget is FloatingActionButton) {
        result ??= element;
      } else if (widget is EditableText ||
          widget is InkWell ||
          widget is GestureDetector && widget.onTap != null) {
        fallback ??= element;
      }
    }

    inspect(leaf);
    leaf.visitAncestorElements((e) {
      inspect(e);
      return result == null && e != root;
    });
    return result ?? fallback;
  }

  bool _enabled(Element element) => switch (element.widget) {
    ButtonStyleButton w => w.onPressed != null,
    IconButton w => w.onPressed != null,
    FloatingActionButton w => w.onPressed != null,
    InkWell w => w.onTap != null,
    GestureDetector w => w.onTap != null,
    TextField w => w.enabled != false && !w.readOnly,
    EditableText w => !w.readOnly,
    _ => false,
  };

  void _pointer(PointerEvent event) {
    if (!_active || root == null) return;
    if (event is PointerDownEvent) {
      if (event.buttons != kPrimaryButton || _pointers.isNotEmpty) {
        _pointers.clear();
        recorder._problem(
          'Multi-pointer/non-primary gestures are unsupported. Re-record without them.',
        );
        return;
      }
      final hit = HitTestResult();
      WidgetsBinding.instance.hitTestInView(hit, event.position, event.viewId);
      Element? leaf;
      for (final entry in hit.path) {
        final target = entry.target;
        if (target is RenderObject && target.debugCreator is DebugCreator) {
          final element = (target.debugCreator as DebugCreator).element;
          if (_within(element, root!)) {
            leaf = element;
            break;
          }
        }
      }
      if (leaf == null || _marked<RecorderIgnore>(leaf)) return;
      final control = _control(leaf);
      if (control != null &&
          (!_enabled(control) ||
              control.widget is TextField ||
              control.widget is EditableText)) {
        _pointers[event.pointer] = _PendingPointer(event, null);
        return;
      }
      var tapHandlers = 0;
      leaf.visitAncestorElements((e) {
        if (e == control) return false;
        if (e.widget is GestureDetector &&
            (e.widget as GestureDetector).onTap != null) {
          tapHandlers++;
        }
        return true;
      });
      final target = tapHandlers > 1
          ? RecorderTarget(
              issue: 'Nested tap handlers require a stable independently identifiable control. Re-record after resolving the nesting.',
            )
          : control == null
          ? RecorderTarget(
              issue: 'Unsupported tap target. Add an accessible standard control or ignore this subtree.',
            )
          : _TargetTree(root!)
                .resolve(control, secret: _marked<RecorderSensitive>(control));
      _pointers[event.pointer] = _PendingPointer(event, target);
    } else if (event is PointerMoveEvent) {
      final pending = _pointers[event.pointer];
      if (pending != null &&
          (event.position - pending.event.position).distance > kTouchSlop) {
        pending.moved = true;
      }
    } else if (event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    } else if (event is PointerUpEvent) {
      final pending = _pointers.remove(event.pointer);
      if (pending == null) return;
      if (pending.moved ||
          event.timeStamp - pending.event.timeStamp >= kLongPressTimeout) {
        recorder._problem(
          'Drag/long press recording is not supported yet. Re-record without this gesture.',
        );
        return;
      }
      if (pending.target == null) return;
      recorder._record(
        RecordedAction.tap,
        pending.target!,
        source: ObservationSource.pointerGesture,
      );
    } else if (event is PointerScrollEvent ||
        event is PointerPanZoomStartEvent) {
      recorder._problem(
        'Scroll/pan recording is not supported yet. Re-record without this gesture.',
      );
    }
  }

  void _semanticsAction(ui.SemanticsActionEvent event) {
    if (!_active || root == null) return;
    if (event.type != ui.SemanticsAction.tap) {
      if (event.type == ui.SemanticsAction.longPress ||
          event.type == ui.SemanticsAction.scrollUp ||
          event.type == ui.SemanticsAction.scrollDown ||
          event.type == ui.SemanticsAction.scrollLeft ||
          event.type == ui.SemanticsAction.scrollRight) {
        recorder._problem(
          'This accessibility gesture is not supported. Re-record without it.',
        );
      }
      return;
    }
    final tree = _TargetTree(root!);
    final elements = tree.nodes.whereType<RenderObjectElement>().where(
      (e) =>
          View.of(e).viewId == event.viewId &&
          e.renderObject.debugSemantics?.id == event.nodeId,
    );
    if (elements.isEmpty) {
      recorder._problem(
        'Accessibility target could not be resolved. Re-record with a supported control.',
      );
      return;
    }
    final element = elements.first;
    if (_marked<RecorderIgnore>(element)) return;
    final control = _control(element);
    if (control == null) {
      recorder._problem('Unsupported accessibility control.');
    } else if (_enabled(control) &&
        control.widget is! TextField &&
        control.widget is! EditableText) {
      recorder._record(
        RecordedAction.tap,
        tree.resolve(control, secret: _marked<RecorderSensitive>(control)),
        source: ObservationSource.semanticsAction,
      );
    }
  }

  void _detachEditor() {
    _controller?.removeListener(_edit);
    _controller = null;
    _editorElement = null;
    _inputTarget = null;
  }

  void _focus() {
    if (!_active) return;
    Element? editor;
    final focus = FocusManager.instance.primaryFocus;
    focus?.context?.visitAncestorElements((e) {
      if (e.widget is EditableText &&
          identical((e.widget as EditableText).focusNode, focus)) {
        editor = e;
        return false;
      }
      return true;
    });
    if (editor == null ||
        root == null ||
        !_within(editor!, root!) ||
        _marked<RecorderIgnore>(editor!) ||
        (editor!.widget as EditableText).readOnly) {
      _detachEditor();
      return;
    }
    final widget = editor!.widget as EditableText;
    final secret = widget.obscureText || _marked<RecorderSensitive>(editor!);
    if (identical(editor, _editorElement) &&
        identical(widget.controller, _controller) &&
        secret == _secret) {
      return;
    }
    _detachEditor();
    _editorElement = editor;
    _controller = widget.controller;
    _secret = secret;
    _inputTarget = _TargetTree(root!)
        .resolve(_control(editor!) ?? editor!, secret: _secret);
    _controller!.addListener(_edit);
  }

  void _edit() {
    final element = _editorElement;
    if (!_active || element == null || !element.mounted) return;
    final widget = element.widget as EditableText;
    if (!widget.focusNode.hasFocus ||
        widget.readOnly ||
        _marked<RecorderIgnore>(element)) {
      return;
    }
    if ((widget.obscureText || _marked<RecorderSensitive>(element)) !=
        _secret) {
      _focus();
    }
    // Notifications include selection/programmatic changes. Never read or retain text.
    final target = _inputTarget!;
    final name = _inputs.putIfAbsent(target.identity, () {
      var proposed = target.key;
      if (proposed == null ||
          !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(proposed) ||
          _usedNames.contains(proposed)) {
        var index = _inputs.length + 1;
        do {
          proposed = 'input_${(index++).toString().padLeft(4, '0')}';
        } while (_usedNames.contains(proposed));
      }
      _usedNames.add(proposed);
      return proposed;
    });
    recorder._record(
      RecordedAction.enterText,
      target,
      input: name,
      secret: _secret,
      source: ObservationSource.focusedController,
    );
  }
}
