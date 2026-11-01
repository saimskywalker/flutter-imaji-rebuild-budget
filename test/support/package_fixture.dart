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
  A shop whose rebuilds are budgeted with imaji_rebuild_budget.
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
  flutter:
    sdk: flutter
  # imaji_rebuild_budget: ^0.1.0   (moved to dev_dependencies)
  shop_core:
    git:
      url: https://example.com/imaji_rebuild_budget-fork.git
      path: imaji_rebuild_budget

dev_dependencies:
  flutter_test:
    sdk: flutter
  imaji_rebuild_budget: ^0.1.0

dependency_overrides:
  imaji_rebuild_budget:
    path: ../imaji_rebuild_budget
''',
  'lib/main.dart': r'''
/// Budgeted in test/ with imaji_rebuild_budget:
///
/// ```dart
/// import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
/// ```
library;

// import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
/* export 'package:imaji_rebuild_budget/guard.dart'; /* nested */ */
import 'package:shop/imaji_rebuild_budget_notes.dart';
export 'package:imaji_rebuild_budget_example/main.dart';

const hint = "import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';";
const raw = r'export "package:imaji_rebuild_budget/guard.dart";';
final multi = """
${notes.isEmpty ? 'import' : "export"} 'package:imaji_rebuild_budget/guard.dart';
""";
''',
  'lib/imaji_rebuild_budget_notes.dart': "const notes = 'none';\n",
  'test/widget_test.dart':
      "import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';\n",
  'integration_test/app_test.dart':
      "import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';\n",
  'tool/measure.dart':
      "import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';\n",
};
