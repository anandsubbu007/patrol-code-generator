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
  'TextFormField': TextFormField,
  'EditableText': EditableText,
  'Switch': Switch,
  'Checkbox': Checkbox,
  'ListTile': ListTile,
  'SwitchListTile': SwitchListTile,
  'CheckboxListTile': CheckboxListTile,
  'InkResponse': InkResponse,
  'RichText': RichText,
  'Scrollable': Scrollable,
  'ListView': ListView,
  'GridView': GridView,
  'CustomScrollView': CustomScrollView,
  'SingleChildScrollView': SingleChildScrollView,
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
    SelectorKind.richText =>
      !private(element) &&
          element.widget is RichText &&
          (element.widget as RichText).text.toPlainText() == selector.value,
    SelectorKind.widgetType =>
      element.widget.runtimeType == _widgetTypes[selector.value] &&
          (selector.value != 'Scrollable' ||
              ModalRoute.of(element)?.isCurrent != false),
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
      if (widget is RichText && !_marked<Icon>(element)) {
        final richText = widget.text.toPlainText();
        if (richText.isNotEmpty &&
            richText.length <= 256 &&
            !richText.runes.any(
              (r) => r == 0xFFFC || r >= 0xE000 && r <= 0xF8FF,
            )) {
          yield RecorderSelector(SelectorKind.richText, richText);
        }
      }
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

  RecorderTarget resolve(
    Element control, {
    bool secret = false,
    bool rootOnly = false,
  }) {
    if (!complete) {
      return RecorderTarget(issue: 'Target discovery exceeded 10000 elements.');
    }
    final local = rootOnly
        ? <Element>[control]
        : nodes.where((e) => _within(e, control)).toList();
    // Transparent keyed wrappers identify the same render target, not a whole page.
    control.visitAncestorElements((e) {
      if (e.widget is Semantics ||
          identical(e.findRenderObject(), control.findRenderObject())) {
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
                      control.widget is! TextFormField &&
                      control.widget is! EditableText ||
                  // Text entry must locate an ancestor of EditableText, not its label/render leaf.
                  _within(control, e) ||
                  e == control ||
                  control.widget is TextFormField && e.widget is TextField)
                (e, s),
        ]..sort((a, b) {
          final order = a.$2.kind.index.compareTo(b.$2.kind.index);
          return order != 0
              ? order
              : local.indexOf(a.$1).compareTo(local.indexOf(b.$1));
        });
    for (final (element, selector) in choices) {
      final matchesAll = nodes.where((e) => matches(e, selector)).toList();
      if (matchesAll.length == 1 && matchesAll.single == element) {
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
          final selected = matchesAll.where(
            (e) => e != ancestor && _within(e, ancestor),
          );
          if (selected.length == 1 && selected.single == element) {
            scoped = RecorderTarget(selector: selector, scope: scope);
            return false;
          }
        }
        return true;
      });
      if (scoped != null) return scoped!;
    }
    return RecorderTarget(
      issue:
          'No unique selector for ${control.widget.runtimeType}. Add key: const ValueKey<String>("unique_action_id") '
          'to the widget, or give its parent a unique key for scoping, then re-record. Use a different stable name for each control. '
          'Coordinates and indexes are disabled.',
    );
  }
}

class _PendingPointer {
  _PendingPointer(
    this.event,
    this.target, {
    this.element,
    this.text,
    this.longPress = false,
    this.ignoreDrag = false,
    this.scrollStarts = const {},
  }) {
    _holdTimer = Timer(kLongPressTimeout, () => held = true);
  }
  final PointerDownEvent event;
  final RecorderTarget? target;
  bool moved = false;
  bool scrollHandled = false;
  bool held = false;
  late final Timer _holdTimer;
  void dispose() => _holdTimer.cancel();
  final Element? element;
  final String? text;
  final bool longPress;
  final bool ignoreDrag;
  final Map<ScrollableState, double> scrollStarts;
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
  final _scrolls = <ScrollableState, _ScrollTrace>{};
  Element? _lastScrollElement;
  bool _flushingScroll = false;

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
    for (final pointer in _pointers.values) {
      pointer.dispose();
    }
    _pointers.clear();
    for (final trace in _scrolls.values) { trace.dispose(); }
    _scrolls.clear();
    _lastScrollElement = null;
    _detachEditor();
    _semantics?.dispose();
    _semantics = null;
  }

  void dispose() => stop();

  void _watchFrames(int epoch) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_active || epoch != _epoch) return;
      _focus();
      for (final trace in _scrolls.values.toList()) {
        if (!trace.state.mounted || !identical(trace.state.position, trace.position)) {
          _finishScroll(trace.state);
        }
      }
      _watchFrames(epoch);
    });
  }

  Element? _control(Element leaf) {
    Element? fallback;
    final chain = <Element>[leaf];
    leaf.visitAncestorElements((e) {
      chain.add(e);
      return e != root;
    });
    for (final element in chain) {
      final widget = element.widget;
      if (widget is TextField ||
          widget is ButtonStyleButton &&
              _widgetTypes.containsValue(widget.runtimeType) ||
          widget is IconButton ||
          widget is FloatingActionButton ||
          widget is Switch ||
          widget is Checkbox ||
          widget is ListTile ||
          widget is SwitchListTile ||
          widget is CheckboxListTile ||
          widget is DropdownButton ||
          widget is PopupMenuButton) {
        return element;
      }
      if (widget is GestureDetector &&
          (widget.onTap != null ||
              widget.onTapUp != null ||
              widget.onTapDown != null ||
              widget.onLongPress != null)) {
        // The innermost independent detector owns this hit; do not select its parent.
        if (fallback != null) return fallback;
        fallback = element;
      } else if (widget is InkResponse) {
        if (fallback?.widget is InkResponse) return fallback;
        fallback = element;
      } else if (widget is EditableText) {
        fallback ??= element;
      }
    }
    return fallback;
  }

  bool _enabled(Element element) => switch (element.widget) {
    ButtonStyleButton w => w.onPressed != null || w.onLongPress != null,
    IconButton w => w.onPressed != null,
    FloatingActionButton w => w.onPressed != null,
    Switch w => w.onChanged != null,
    Checkbox w => w.onChanged != null,
    ListTile w => w.enabled && w.onTap != null,
    SwitchListTile w => w.onChanged != null,
    CheckboxListTile w => w.onChanged != null,
    DropdownButton() =>
      element.findRenderObject()?.debugSemantics?.getSemanticsData().hasAction(
            ui.SemanticsAction.tap,
          ) ==
          true,
    PopupMenuButton w => w.enabled,
    InkResponse w => w.onTap != null || w.onLongPress != null,
    GestureDetector w =>
      w.onTap != null ||
          w.onTapUp != null ||
          w.onTapDown != null ||
          w.onLongPress != null,
    TextField w => w.enabled != false && !w.readOnly,
    EditableText w => !w.readOnly,
    _ => false,
  };

  bool _canLongPress(Element element) => switch (element.widget) {
    ButtonStyleButton w => w.onLongPress != null,
    InkResponse w => w.onLongPress != null,
    GestureDetector w => w.onLongPress != null,
    _ => false,
  };

  void _action(
    RecordedAction action,
    RecorderTarget target,
    Element? element, {
    String? text,
    required ObservationSource source,
  }) {
    flushScroll();
    anchorRecentScroll(target, element);
    recorder._record(action, target, source: source, text: text);
  }

  void _pointer(PointerEvent event) {
    if (!_active || root == null) return;
    if (event is PointerDownEvent) {
      flushScroll();
      if (event.buttons != kPrimaryButton || _pointers.isNotEmpty) {
        for (final pointer in _pointers.values) {
          pointer.dispose();
        }
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
      final scrollStarts = scrollAncestors(leaf);
      final link = linkAt(leaf, event.position);
      if (link != null) {
        _pointers[event.pointer] = _PendingPointer(
          event,
          link.target,
          element: leaf,
          text: link.text,
          scrollStarts: scrollStarts,
        );
        return;
      }
      final control = _control(leaf);
      if (control != null &&
          (!_enabled(control) ||
              control.widget is TextField ||
              control.widget is EditableText)) {
        _pointers[event.pointer] = _PendingPointer(
          event,
          null,
          ignoreDrag: true,
          scrollStarts: scrollStarts,
        );
        return;
      }
      // Background/focus-dismissal taps are not application actions.
      final target = control == null
          ? null
          : _TargetTree(root!)
                .resolve(control, secret: _marked<RecorderSensitive>(control));
      _pointers[event.pointer] = _PendingPointer(
        event,
        target,
        element: control,
        longPress: control != null && _canLongPress(control),
        scrollStarts: scrollStarts,
      );
    } else if (event is PointerMoveEvent) {
      final pending = _pointers[event.pointer];
      if (pending != null &&
          (event.position - pending.event.position).distance > kTouchSlop) {
        pending.moved = true;
        observeDragScroll(pending);
      }
    } else if (event is PointerScrollEvent || event is PointerPanZoomUpdateEvent) {
      observePointerScroll(event.position, event.viewId);
    } else if (event is PointerCancelEvent) {
      _pointers.remove(event.pointer)?.dispose();
    } else if (event is PointerUpEvent) {
      final pending = _pointers.remove(event.pointer);
      if (pending == null) return;
      pending.dispose();
      if (pending.moved) {
        if (pending.scrollHandled || pending.ignoreDrag) return;
        recorder._problem(
          'Drag needs review: no observable Flutter scroll was identified. Give the ScrollView a unique ValueKey and '
          'do not consume its ScrollNotifications. Custom canvas/slider drags need a specific adapter; no coordinate tap was generated.',
        );
        return;
      }
      if (pending.target == null) return;
      if (pending.held ||
          event.timeStamp - pending.event.timeStamp >= kLongPressTimeout) {
        if (pending.longPress) {
          _action(
            RecordedAction.longPress,
            pending.target!,
            pending.element,
            source: ObservationSource.pointerGesture,
          );
        } else {
          recorder._problem(
            'Long press could not be identified. Add a key to a widget with a public onLongPress action and re-record.',
          );
        }
        return;
      }
      _action(
        pending.text == null ? RecordedAction.tap : RecordedAction.tapText,
        pending.target!,
        pending.element,
        text: pending.text,
        source: ObservationSource.pointerGesture,
      );
    }
  }

  void _semanticsAction(ui.SemanticsActionEvent event) {
    if (!_active || root == null) return;
    if (event.type != ui.SemanticsAction.tap &&
        event.type != ui.SemanticsAction.longPress) {
      if (event.type == ui.SemanticsAction.scrollUp ||
          event.type == ui.SemanticsAction.scrollDown ||
          event.type == ui.SemanticsAction.scrollLeft ||
          event.type == ui.SemanticsAction.scrollRight ||
          event.type == ui.SemanticsAction.scrollToOffset) {
        beginSemanticsScroll(event);
      }
      return;
    }
    final tree = _TargetTree(root!);
    if (event.type == ui.SemanticsAction.tap) {
      final link = linkForSemantics(event, tree);
      if (link != null) {
        _action(
          link.text == null
              ? RecordedAction.unsupported
              : RecordedAction.tapText,
          link.target,
          link.element,
          text: link.text,
          source: ObservationSource.semanticsAction,
        );
        return;
      }
    }
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
      final node = element.renderObject.debugSemantics;
      if (node?.getSemanticsData().hasAction(ui.SemanticsAction.tap) == true) {
        _action(
          RecordedAction.tap,
          tree.resolve(element, secret: _marked<RecorderSensitive>(element)),
          element,
          source: ObservationSource.semanticsAction,
        );
      }
    } else if (_enabled(control) &&
        control.widget is! TextField &&
        control.widget is! EditableText) {
      _action(
        event.type == ui.SemanticsAction.longPress
            ? RecordedAction.longPress
            : RecordedAction.tap,
        tree.resolve(control, secret: _marked<RecorderSensitive>(control)),
        control,
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
    Element? formField;
    editor!.visitAncestorElements((element) {
      if (element.widget is TextFormField) {
        formField = element;
        return false;
      }
      return element != root;
    });
    _inputTarget = _TargetTree(root!)
        .resolve(formField ?? _control(editor!) ?? editor!, secret: _secret);
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
    flushScroll();
    anchorRecentScroll(target, element);
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
