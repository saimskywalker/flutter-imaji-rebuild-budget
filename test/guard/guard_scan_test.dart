import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/src/guard_scan.dart';

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
  rebuildcop: ^0.1.0
'''),
        [
          'pubspec.yaml:6: rebuildcop is under dependencies, so it '
              'is built into the app. Move it to dev_dependencies.',
        ],
      );
    });

    test('finds it under dependencies even when it is also a dev dependency',
        () {
      expect(
        checkPubspec('''
dev_dependencies:
  rebuildcop: ^0.1.0
dependencies:
  rebuildcop:
    path: ../
''').map((f) => f.line),
        [4],
      );
    });

    test('finds a quoted key, a flow mapping and CRLF line endings', () {
      expect(
        checkPubspec('dependencies:\r\n  "rebuildcop": any\r\n')
            .map((f) => f.line),
        [2],
      );
      expect(
        checkPubspec(
          'name: app\n'
          'dependencies: {flutter: {sdk: flutter}, rebuildcop: any}\n',
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
  rebuildcop: $source
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
  rebuildcop:
    path: ../rebuildcop
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
  rebuildcop: ^0.1.0
'''),
        isEmpty,
      );
      expect(
        pubspecFindings('''
name: _
publish_to: none
workspace:
  - packages/app
  - packages/rebuildcop
'''),
        isEmpty,
      );
      expect(
        checkPubspec('''
name: app
resolution: workspace
dependencies:
  rebuildcop: ^0.1.0
''').map((f) => f.line),
        [4],
      );
    });

    test('ignores comments, nested values and similar names', () {
      expect(
        pubspecFindings('''
# dependencies:
#   rebuildcop: ^0.1.0
description: >-
  dependencies:
    rebuildcop: any
dependencies:
  # rebuildcop: ^0.1.0
  rebuildcop_extras: ^1.0.0
  fork:
    git:
      url: https://example.com/rebuildcop.git
      path: rebuildcop
    rebuildcop: nested
flutter:
  dependencies:
    rebuildcop: any
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
import 'package:rebuildcop/rebuildcop.dart';

export "package:rebuildcop/guard.dart" show expectRebuildBudgetIsTestOnly;
'''),
        [
          'lib/a.dart:2: imports '
              'package:rebuildcop/rebuildcop.dart. Import '
              'it only from test/ or integration_test/.',
          'lib/a.dart:4: exports package:rebuildcop/guard.dart. '
              'Import it only from test/ or integration_test/.',
        ],
      );
    });

    test('finds prefixed, deferred, annotated and conditional imports', () {
      expect(
        checkLibSource('''
@Deprecated('debug only')
import 'package:rebuildcop/rebuildcop.dart' as budget;
import 'package:rebuildcop/guard.dart' deferred as guard;
import 'src/stub.dart'
    if (dart.library.io)
        'package:rebuildcop/rebuildcop.dart';
''', 'lib/a.dart').map((f) => f.line),
        [2, 3, 6],
      );
    });

    test('ignores the package in comments and strings', () {
      expect(
        libFindings(r'''
/// Rebuilds are budgeted with
/// `import 'package:rebuildcop/rebuildcop.dart';`.
library;

// import 'package:rebuildcop/rebuildcop.dart';
/* /* nested */ import 'package:rebuildcop/guard.dart'; */
import 'package:flutter/widgets.dart';

const a = "import 'package:rebuildcop/guard.dart';";
const b = r'export "package:rebuildcop/guard.dart";';
final c = """
${a.isEmpty ? 'import' : "export"} 'package:rebuildcop/guard.dart';
import 'package:rebuildcop/guard.dart';
""";
final d = '${'}'} import \'package:rebuildcop/guard.dart\';';
'''),
        isEmpty,
      );
    });

    test('ignores packages whose name only starts with this one', () {
      expect(
        libFindings('''
import 'package:rebuildcop_example/main.dart';
export 'package:shop/rebuildcop.dart';
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
import 'package:rebuildcop/guard.dart';
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
      'rebuildcop must stay out of the app in /work/shop: it '
      'depends on flutter_test, and every dependency and every import from '
      'lib/ is compiled into release builds.\n'
      '  pubspec.yaml:14: one\n'
      '  lib/a.dart:3: two',
    );
  });
}
