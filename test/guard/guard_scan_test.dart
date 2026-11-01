import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/src/guard_scan.dart';

List<String> pubspecFindings(String pubspec) =>
    [for (final finding in checkPubspec(pubspec)) '$finding'];

List<String> libFindings(String source) =>
    [for (final finding in checkLibSource(source, 'lib/a.dart')) '$finding'];

void main() {
  group('checkPubspec', () {
    test('finds the package under dependencies, with its line', () {
      expect(
        pubspecFindings('''
name: app

dependencies:
  flutter:
    sdk: flutter
  imaji_rebuild_budget: ^0.1.0
'''),
        [
          'pubspec.yaml:6: imaji_rebuild_budget is under dependencies, so it '
              'is built into the app. Move it to dev_dependencies.',
        ],
      );
    });

    test('finds it under dependencies even when it is also a dev dependency',
        () {
      expect(
        checkPubspec('''
dev_dependencies:
  imaji_rebuild_budget: ^0.1.0
dependencies:
  imaji_rebuild_budget:
    path: ../
''').map((f) => f.line),
        [4],
      );
    });

    test('finds a quoted key, a flow mapping and CRLF line endings', () {
      expect(
        checkPubspec('dependencies:\r\n  "imaji_rebuild_budget": any\r\n')
            .map((f) => f.line),
        [2],
      );
      expect(
        checkPubspec(
          'name: app\n'
          'dependencies: {flutter: {sdk: flutter}, imaji_rebuild_budget: any}\n',
        ).map((f) => f.line),
        [2],
      );
    });

    test('allows dev_dependencies from pub.dev, a path or git', () {
      for (final source in ['^0.1.0', '\n    path: ../', '\n    git: x']) {
        expect(
          pubspecFindings('''
dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  imaji_rebuild_budget: $source
'''),
          isEmpty,
        );
      }
    });

    test('allows dependency_overrides', () {
      expect(
        pubspecFindings('''
dependencies:
  flutter:
    sdk: flutter
dependency_overrides:
  imaji_rebuild_budget:
    path: ../imaji_rebuild_budget
'''),
        isEmpty,
      );
    });

    test('handles a pubspec without dev_dependencies or dependencies', () {
      expect(pubspecFindings('name: app\n'), isEmpty);
      expect(
        pubspecFindings('name: app\ndependencies:\n  flutter:\n'),
        isEmpty,
      );
      expect(pubspecFindings(''), isEmpty);
    });

    test('handles a workspace member and a workspace root', () {
      expect(
        pubspecFindings('''
name: app
resolution: workspace
environment:
  sdk: ^3.6.0
dev_dependencies:
  imaji_rebuild_budget: ^0.1.0
'''),
        isEmpty,
      );
      expect(
        pubspecFindings('''
name: _
publish_to: none
workspace:
  - packages/app
  - packages/imaji_rebuild_budget
'''),
        isEmpty,
      );
      expect(
        checkPubspec('''
name: app
resolution: workspace
dependencies:
  imaji_rebuild_budget: ^0.1.0
''').map((f) => f.line),
        [4],
      );
    });

    test('ignores comments, nested values and similar names', () {
      expect(
        pubspecFindings('''
# dependencies:
#   imaji_rebuild_budget: ^0.1.0
description: >-
  dependencies:
    imaji_rebuild_budget: any
dependencies:
  # imaji_rebuild_budget: ^0.1.0
  imaji_rebuild_budget_extras: ^1.0.0
  fork:
    git:
      url: https://example.com/imaji_rebuild_budget.git
      path: imaji_rebuild_budget
    imaji_rebuild_budget: nested
flutter:
  dependencies:
    imaji_rebuild_budget: any
'''),
        isEmpty,
      );
    });
  });

  group('checkLibSource', () {
    test('finds imports and exports, with their lines', () {
      expect(
        libFindings('''
import 'package:flutter/widgets.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';

export "package:imaji_rebuild_budget/guard.dart" show expectRebuildBudgetIsTestOnly;
'''),
        [
          'lib/a.dart:2: imports '
              'package:imaji_rebuild_budget/imaji_rebuild_budget.dart. Import '
              'it only from test/ or integration_test/.',
          'lib/a.dart:4: exports package:imaji_rebuild_budget/guard.dart. '
              'Import it only from test/ or integration_test/.',
        ],
      );
    });

    test('finds prefixed, deferred, annotated and conditional imports', () {
      expect(
        checkLibSource('''
@Deprecated('debug only')
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart' as budget;
import 'package:imaji_rebuild_budget/guard.dart' deferred as guard;
import 'src/stub.dart'
    if (dart.library.io)
        'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
''', 'lib/a.dart').map((f) => f.line),
        [2, 3, 6],
      );
    });

    test('ignores the package in comments and strings', () {
      expect(
        libFindings(r'''
/// Rebuilds are budgeted with
/// `import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';`.
library;

// import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
/* /* nested */ import 'package:imaji_rebuild_budget/guard.dart'; */
import 'package:flutter/widgets.dart';

const a = "import 'package:imaji_rebuild_budget/guard.dart';";
const b = r'export "package:imaji_rebuild_budget/guard.dart";';
final c = """
${a.isEmpty ? 'import' : "export"} 'package:imaji_rebuild_budget/guard.dart';
import 'package:imaji_rebuild_budget/guard.dart';
""";
final d = '${'}'} import \'package:imaji_rebuild_budget/guard.dart\';';
'''),
        isEmpty,
      );
    });

    test('ignores packages whose name only starts with this one', () {
      expect(
        libFindings('''
import 'package:imaji_rebuild_budget_example/main.dart';
export 'package:shop/imaji_rebuild_budget.dart';
'''),
        isEmpty,
      );
    });

    test('counts lines across multi-line strings and comments', () {
      expect(
        checkLibSource(r'''
/*
 * Two lines.
 */
const s = """
one
two ${'x'}
""";
import 'package:imaji_rebuild_budget/guard.dart';
''', 'lib/a.dart').map((f) => f.line),
        [8],
      );
    });
  });

  test('describeFindings lists one file:line per finding', () {
    expect(
      describeFindings('/work/shop', const [
        GuardFinding('pubspec.yaml', 14, 'one'),
        GuardFinding('lib/a.dart', 3, 'two'),
      ]),
      'imaji_rebuild_budget must stay out of the app in /work/shop: it '
      'depends on flutter_test, and every dependency and every import from '
      'lib/ is compiled into release builds.\n'
      '  pubspec.yaml:14: one\n'
      '  lib/a.dart:3: two',
    );
  });
}
