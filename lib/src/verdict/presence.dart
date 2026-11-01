import '../tally/build_record.dart';
import '../tally/rebuild_window.dart';

const String _sameNameNote = 'the test and the app probably import it from '
    'different libraries (for example package:flutter/material.dart and '
    'package:material_ui/material_ui.dart).';

const String _renamedNote = 'If it was renamed or replaced, budget the new '
    'type. To assert that it never appears, use findsNothing; to keep this '
    'budget anyway, pass allowAbsent: true.';

bool _otherTypeNamedLike(RebuildWindow window, Type type) {
  final name = typeLabel(type);
  return window.presentTypes.any((t) => t != type && typeLabel(t) == name);
}

String _noElement(RebuildWindow window, Type type) =>
    'no ${typeLabel(type)} element existed during ${windowPhrase(window)}';

String _sameNameSentence(Type type) =>
    'A different type with the same name, ${typeLabel(type)}, was present: '
    '$_sameNameNote';

/// Why a budget for [type] could never fail in [window], or null when an
/// element of [type] was there.
String? absentTypeForBudget(RebuildWindow window, Type type) {
  if (window.presentTypes.contains(type)) {
    return null;
  }
  final tail = _otherTypeNamedLike(window, type)
      ? _sameNameSentence(type)
      : _renamedNote;
  return '${_noElement(window, type)}, so this budget could never fail. '
      '$tail';
}

/// Why `interactionHappened(rebuilt: type)` cannot hold because [type] was
/// never there, or null when it was.
String? absentTypeForProof(RebuildWindow window, Type type) {
  if (window.presentTypes.contains(type)) {
    return null;
  }
  final tail = _otherTypeNamedLike(window, type)
      ? _sameNameSentence(type)
      : 'Was it renamed or replaced?';
  return '${_noElement(window, type)}. $tail';
}

/// Why a budget for the type name [name] could never fail in [window], or
/// null when a type with that name was there.
String? absentNameForBudget(RebuildWindow window, String name) {
  if (window.presentTypes.any((t) => typeLabel(t) == name)) {
    return null;
  }
  return 'no widget type named $name existed during ${windowPhrase(window)}, '
      'so this budget could never fail. $_renamedNote';
}

/// Why a budget by [name] would add up unrelated types, or null when at
/// most one type of that name rebuilt.
String? ambiguousName(RebuildWindow window, String name) {
  final types = {
    for (final record in window.rebuilds)
      if (record.typeName == name) record.widgetType,
  };
  if (types.length < 2) {
    return null;
  }
  return '${types.length} different types named $name rebuilt during '
      '${windowPhrase(window)}, so a budget by name would add them up. '
      'Budget each by type, or narrow the budget to one subtree.';
}
