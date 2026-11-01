import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where the baseline at [path] lives.
///
/// An absolute path is used as is. A relative one resolves next to the test
/// file, like a golden file.
String locateBaselineFile(String path) {
  if (File(path).isAbsolute) {
    return path;
  }
  final comparator = goldenFileComparator;
  final base = comparator is LocalFileComparator
      ? comparator.basedir
      : Directory.current.uri;
  return base.resolve(path).toFilePath();
}

/// The contents of the file at [path], or null when there is none.
String? readBaselineFile(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Writes [contents] to [path], creating its directory if needed.
void writeBaselineFile(String path, String contents) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(contents);
}
