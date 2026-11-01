import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a walk of the element tree found at one moment.
class TreeSurvey {
  TreeSurvey._(this.elements, this.types, this.scrollOffsets);

  /// Walks the tree under the binding's root element.
  factory TreeSurvey.now() {
    final elements = HashSet<Element>.identity();
    final types = <Type>{};
    final offsets = HashMap<ScrollableState, double>.identity();
    final root = WidgetsBinding.instance.rootElement;
    if (root != null) {
      final pending = <Element>[root];
      while (pending.isNotEmpty) {
        final element = pending.removeLast();
        elements.add(element);
        types.add(element.widget.runtimeType);
        if (element is StatefulElement) {
          final state = element.state;
          if (state is ScrollableState && state.position.hasPixels) {
            offsets[state] = state.position.pixels;
          }
        }
        element.visitChildren(pending.add);
      }
    }
    return TreeSurvey._(elements, types, offsets);
  }

  /// Every element in the tree.
  final Set<Element> elements;

  /// The runtime type of every element's widget.
  final Set<Type> types;

  /// The scroll offset of every scrollable in the tree.
  final Map<ScrollableState, double> scrollOffsets;
}

/// The scrollable a finder points at: the found widget itself, the first
/// scrollable inside it, or the one around it.
///
/// `found` is false when the finder finds nothing; `scrollable` is null
/// then, and also when there is no scrollable in or around the widget.
({bool found, ScrollableState? scrollable}) scrollableFor(Finder finder) {
  final hits = finder.evaluate();
  if (hits.isEmpty) {
    return (found: false, scrollable: null);
  }
  final start = hits.first;
  final pending = ListQueue<Element>()..add(start);
  while (pending.isNotEmpty) {
    final element = pending.removeFirst();
    if (element is StatefulElement && element.state is ScrollableState) {
      return (found: true, scrollable: element.state as ScrollableState);
    }
    element.visitChildren(pending.add);
  }
  return (
    found: true,
    scrollable: start.findAncestorStateOfType<ScrollableState>(),
  );
}
