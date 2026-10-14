Never _unsupported() => throw UnsupportedError(
      'Rebuild baselines need a file system (dart:io). Run these tests on '
      'the Dart VM, which is what plain `flutter test` does.',
    );

/// Resolves [path] against the directory of the running test file.
String resolveBaselinePath(String path) => _unsupported();

/// Reads the baseline at [resolvedPath], or `null` if it does not exist.
Map<String, Map<String, int>>? readBaseline(String resolvedPath) =>
    _unsupported();

/// Writes [baseline] to [resolvedPath].
void writeBaseline(
  String resolvedPath,
  Map<String, Map<String, int>> baseline,
) =>
    _unsupported();
