part of 'recorder.dart';

class _TextTarget {
  const _TextTarget(this.element, this.target, this.text);
  final Element element;
  final RecorderTarget target;
  final String? text;
}

extension _TextObservation on _RecorderObserver {
  _TextTarget _linkTarget(
    Element element,
    RenderParagraph paragraph,
    TextSpan span,
    _TargetTree tree,
  ) {
    if (tree.private(element)) {
      return _TextTarget(
        element,
        RecorderTarget(
          issue: 'A sensitive inline link cannot use its text as a selector. Use a keyed TextButton/WidgetSpan outside the private content.',
        ),
        null,
      );
    }
    final text = span.text;
    final rendered = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final finderText = paragraph.text.toPlainText();
    if (text == null ||
        text.trim().isEmpty ||
        text.length > 256 ||
        text.allMatches(rendered).length != 1 ||
        !finderText.contains(text)) {
      return _TextTarget(
        element,
        RecorderTarget(
          issue:
              'Inline link text is ambiguous or its semantics label differs from rendered text. '
              'Use a separate keyed TextButton/WidgetSpan, or unique link text inside a keyed Text.rich paragraph.',
        ),
        null,
      );
    }
    return _TextTarget(element, tree.resolve(element), text);
  }

  _TextTarget? linkAt(Element leaf, Offset globalPosition) {
    final render = leaf.findRenderObject();
    if (render is! RenderParagraph ||
        !render.attached ||
        !render.hasSize ||
        root == null) {
      return null;
    }
    final position = render.getPositionForOffset(
      render.globalToLocal(globalPosition),
    );
    final span = render.text.getSpanForPosition(position);
    if (span is! TextSpan || span.recognizer is! TapGestureRecognizer) {
      return null;
    }
    if ((span.recognizer! as TapGestureRecognizer).onTap == null) return null;
    return _linkTarget(leaf, render, span, _TargetTree(root!));
  }

  _TextTarget? linkForSemantics(
    ui.SemanticsActionEvent event,
    _TargetTree tree,
  ) {
    for (final element in tree.nodes.whereType<RenderObjectElement>()) {
      final paragraph = element.renderObject;
      if (paragraph is! RenderParagraph ||
          View.of(element).viewId != event.viewId) {
        continue;
      }
      final rootNode = paragraph.debugSemantics;
      if (rootNode == null) continue;
      SemanticsNode? selected;
      void visit(SemanticsNode node) {
        if (node.id == event.nodeId) {
          selected = node;
          return;
        }
        node.visitChildren((child) {
          if (selected == null) visit(child);
          return selected == null;
        });
      }

      visit(rootNode);
      if (selected == null) continue;
      final candidates = <TextSpan>[];
      paragraph.text.visitChildren((span) {
        if (span is TextSpan &&
            span.recognizer is TapGestureRecognizer &&
            (span.recognizer! as TapGestureRecognizer).onTap != null &&
            (span.semanticsLabel ?? span.text)?.trim() ==
                selected!.label.trim()) {
          candidates.add(span);
        }
        return true;
      });
      if (candidates.length == 1) {
        return _linkTarget(element, paragraph, candidates.single, tree);
      }
    }
    return null;
  }
}
