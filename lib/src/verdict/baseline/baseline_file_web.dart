Never _unsupported() => throw UnsupportedError(
      'matchesRebuildBaseline needs a file system, which flutter test '
      '--platform chrome does not have.',
    );

/// Where [path] points: unsupported without a file system.
String locateBaselineFile(String path) => _unsupported();

/// The contents of [path]: unsupported without a file system.
String? readBaselineFile(String path) => _unsupported();

/// Writes [path]: unsupported without a file system.
void writeBaselineFile(String path, String contents) => _unsupported();
