/// The checks behind `expectRebuildBudgetIsTestOnly` and
/// `dart run rebuildcop:check`, on file contents only.
///
/// Nothing here touches the file system or Flutter, so the command-line
/// check can run on the plain Dart VM. The pubspec is read by a small reader
/// of top-level YAML keys rather than `package:yaml`, which is not in
/// `flutter_test`'s dependencies and would be a new runtime dependency.
library;

/// The name this package is listed under and imported as.
const String guardedPackage = 'rebuildcop';

/// One place where the app depends on or imports this package.
class GuardFinding {
  /// Creates a finding at [line] (1-based) of [file].
  const GuardFinding(this.file, this.line, this.message);

  /// The file, relative to the package root, with `/` separators.
  final String file;

  /// The 1-based line the finding is on.
  final int line;

  /// What was found and how to fix it.
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

/// The failure message for [findings] in the package at [root], one
/// `file:line` per finding.
String describeFindings(String root, List<GuardFinding> findings) => [
      '$guardedPackage must stay out of the app in $root: it depends on '
          'flutter_test, and every dependency and every import from lib/ is '
          'compiled into release builds.',
      for (final finding in findings) '  $finding',
    ].join('\n');

/// Finds this package under the top-level `dependencies` of [pubspec].
///
/// `dev_dependencies` and `dependency_overrides` are allowed: neither is
/// compiled into the app. A pubspec without `dependencies` (or without
/// `dev_dependencies`) is fine, and `resolution: workspace` changes nothing,
/// since a workspace member still lists its own dependencies.
List<GuardFinding> checkPubspec(String pubspec) {
  final line = topLevelKeys(pubspec, 'dependencies')[guardedPackage];
  if (line == null) return const [];
  return [
    GuardFinding(
      'pubspec.yaml',
      line,
      '$guardedPackage is under dependencies, so it is built into the app. '
          'Move it to dev_dependencies.',
    ),
  ];
}

/// Finds every `import` or `export` of `package:rebuildcop/` in
/// the Dart [source] of [file].
///
/// Comments and string literals outside directives are skipped, so a doc
/// comment that mentions the package is not a finding. The URIs of a
/// conditional import are all checked.
List<GuardFinding> checkLibSource(String source, String file) {
  final tokens = _DartScanner(source).scan();
  final findings = <GuardFinding>[];
  for (var i = 0; i < tokens.length; i++) {
    final keyword = tokens[i].text;
    if (tokens[i].isString || (keyword != 'import' && keyword != 'export')) {
      continue;
    }
    if (i + 1 >= tokens.length || !tokens[i + 1].isString) continue;
    for (var j = i + 1; j < tokens.length; j++) {
      final uri = tokens[j];
      if (!uri.isString && uri.text == ';') break;
      if (uri.isString && uri.text.startsWith('package:$guardedPackage/')) {
        findings.add(
          GuardFinding(
            file,
            uri.line,
            '${keyword}s ${uri.text}. Import it only from test/ or '
            'integration_test/.',
          ),
        );
      }
    }
  }
  return findings;
}

/// The keys directly under the top-level key [section] of the YAML
/// [source], each with its 1-based line.
///
/// Reads block mappings (`dependencies:` followed by indented keys) and a
/// one-line flow mapping (`dependencies: {a: ^1.0.0}`). Nested values such
/// as `path:` or `git:` are not keys of the section, so they are skipped.
Map<String, int> topLevelKeys(String source, String section) {
  final keys = <String, int>{};
  final lines = source.split('\n');
  var inSection = false;
  int? childIndent;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].replaceFirst(RegExp(r'\r$'), '');
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final indent = line.length - trimmed.length;
    final key = _yamlKey.firstMatch(trimmed);
    if (indent == 0) {
      inSection = false;
      childIndent = null;
      if (key == null || key[2] != section) continue;
      final value = key[3]!.trim();
      if (value.startsWith('{')) {
        for (final name in _flowKeys(value)) {
          keys.putIfAbsent(name, () => i + 1);
        }
      } else {
        inSection = true;
      }
      continue;
    }
    if (!inSection) continue;
    childIndent ??= indent;
    if (indent == childIndent && key != null) {
      keys.putIfAbsent(key[2]!, () => i + 1);
    }
  }
  return keys;
}

/// A mapping key at the start of a trimmed YAML line, optionally quoted,
/// and the rest of the line after its colon.
final RegExp _yamlKey =
    RegExp(r'''^(["']?)([^\s"':#{}\[\],]+)\1\s*:(?:\s|$)(.*)$''');

/// The keys of a one-line flow mapping such as `{a: 1, b: {path: x}}`.
Iterable<String> _flowKeys(String flow) sync* {
  var depth = 0;
  var start = 0;
  for (var i = 0; i < flow.length; i++) {
    final c = flow[i];
    if (c == '{' || c == '[') {
      if (depth == 0) start = i + 1;
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
    } else if (c == ',' && depth == 1) {
      start = i + 1;
    } else if (c == ':' && depth == 1 && start >= 0) {
      final name = flow.substring(start, i).trim();
      yield name.replaceAll(RegExp(r'''^["']|["']$'''), '');
      start = -1;
    }
  }
}

/// A token of Dart source: an identifier, a string literal's contents, or
/// one punctuation character.
class _Token {
  const _Token(this.text, this.line, {this.isString = false});

  final String text;
  final int line;
  final bool isString;
}

/// Just enough of a Dart scanner to find directives: it skips whitespace,
/// comments (nested block comments included) and the insides of string
/// interpolations, and keeps the contents of string literals.
class _DartScanner {
  _DartScanner(this._source);

  final String _source;
  int _pos = 0;
  int _line = 1;

  List<_Token> scan() {
    final tokens = <_Token>[];
    _code(tokens);
    return tokens;
  }

  /// Scans code until the end, or until the `}` that closes an
  /// interpolation when [tokens] is null.
  void _code(List<_Token>? tokens) {
    var braces = 0;
    while (_pos < _source.length) {
      final c = _source[_pos];
      if (c == '\n') {
        _line++;
        _pos++;
      } else if (c == ' ' || c == '\t' || c == '\r') {
        _pos++;
      } else if (_startsWith('//')) {
        while (_pos < _source.length && _source[_pos] != '\n') {
          _pos++;
        }
      } else if (_startsWith('/*')) {
        _blockComment();
      } else if (c == "'" || c == '"') {
        _string(tokens, raw: false);
      } else if (c == 'r' && _isQuote(_pos + 1)) {
        _pos++;
        _string(tokens, raw: true);
      } else if (_isIdentifierStart(c)) {
        final start = _pos;
        while (_pos < _source.length && _isIdentifierPart(_source[_pos])) {
          _pos++;
        }
        tokens?.add(_Token(_source.substring(start, _pos), _line));
      } else {
        _pos++;
        if (tokens == null) {
          if (c == '{') braces++;
          if (c == '}' && braces-- == 0) return;
        } else {
          tokens.add(_Token(c, _line));
        }
      }
    }
  }

  void _blockComment() {
    var depth = 0;
    while (_pos < _source.length) {
      if (_startsWith('/*')) {
        depth++;
        _pos += 2;
      } else if (_startsWith('*/')) {
        _pos += 2;
        if (--depth == 0) return;
      } else {
        if (_source[_pos] == '\n') _line++;
        _pos++;
      }
    }
  }

  void _string(List<_Token>? tokens, {required bool raw}) {
    final line = _line;
    final quote = _source[_pos];
    final triple = _startsWith(quote * 3);
    final end = triple ? quote * 3 : quote;
    _pos += end.length;
    final contents = StringBuffer();
    while (_pos < _source.length) {
      final c = _source[_pos];
      if (_startsWith(end)) {
        _pos += end.length;
        break;
      }
      if (!triple && c == '\n') break;
      if (c == '\n') _line++;
      if (!raw && c == r'\' && _pos + 1 < _source.length) {
        if (_source[_pos + 1] == '\n') _line++;
        contents.write(_source.substring(_pos, _pos + 2));
        _pos += 2;
      } else if (!raw && _startsWith(r'${')) {
        _pos += 2;
        _code(null);
      } else {
        contents.write(c);
        _pos++;
      }
    }
    tokens?.add(_Token(contents.toString(), line, isString: true));
  }

  bool _startsWith(String pattern) => _source.startsWith(pattern, _pos);

  bool _isQuote(int at) =>
      at < _source.length && (_source[at] == "'" || _source[at] == '"');

  static bool _isIdentifierStart(String c) =>
      c == '_' ||
      c == r'$' ||
      (c.compareTo('a') >= 0 && c.compareTo('z') <= 0) ||
      (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0);

  static bool _isIdentifierPart(String c) =>
      _isIdentifierStart(c) || (c.compareTo('0') >= 0 && c.compareTo('9') <= 0);
}
