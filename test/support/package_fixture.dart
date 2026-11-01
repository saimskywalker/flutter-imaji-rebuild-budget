import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Writes a package to a new temporary directory and returns its path.
///
/// [files] maps paths relative to the package root (with `/`) to their
/// contents. The directory is deleted when the test ends.
String writePackage(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('rebuild_guard_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final entry in files.entries) {
    File('${root.path}/${entry.key}')
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return root.path;
}

/// An app that keeps the package where it belongs: a dev dependency,
/// imported from `test/` and `integration_test/` only, and mentioned in
/// `lib/` only in comments and strings.
const Map<String, String> cleanApp = {
  'pubspec.yaml': '''
name: shop
description: >-
  A shop whose rebuilds are budgeted with rebuildcop.
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
  flutter:
    sdk: flutter
  # rebuildcop: ^0.1.0   (moved to dev_dependencies)
  shop_core:
    git:
      url: https://example.com/rebuildcop-fork.git
      path: rebuildcop

dev_dependencies:
  flutter_test:
    sdk: flutter
  rebuildcop: ^0.1.0

dependency_overrides:
  rebuildcop:
    path: ../rebuildcop
''',
  'lib/main.dart': r'''
/// Budgeted in test/ with rebuildcop:
///
/// ```dart
/// import 'package:rebuildcop/rebuildcop.dart';
/// ```
library;

// import 'package:rebuildcop/rebuildcop.dart';
/* export 'package:rebuildcop/guard.dart'; /* nested */ */
import 'package:shop/rebuildcop_notes.dart';
export 'package:rebuildcop_example/main.dart';

const hint = "import 'package:rebuildcop/rebuildcop.dart';";
const raw = r'export "package:rebuildcop/guard.dart";';
final multi = """
${notes.isEmpty ? 'import' : "export"} 'package:rebuildcop/guard.dart';
""";
''',
  'lib/rebuildcop_notes.dart': "const notes = 'none';\n",
  'test/widget_test.dart': "import 'package:rebuildcop/rebuildcop.dart';\n",
  'integration_test/app_test.dart':
      "import 'package:rebuildcop/rebuildcop.dart';\n",
  'tool/measure.dart': "import 'package:rebuildcop/rebuildcop.dart';\n",
};
