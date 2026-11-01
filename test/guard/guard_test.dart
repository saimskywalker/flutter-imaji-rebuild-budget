import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/guard.dart';
import 'package:imaji_rebuild_budget/src/guard_io.dart';

import '../support/package_fixture.dart';

Matcher failsWith(Object message) => throwsA(
      isA<TestFailure>().having((e) => e.message, 'message', message),
    );

void main() {
  group('expectRebuildBudgetIsTestOnly', () {
    test('passes on an app that keeps the package in its tests', () {
      expectRebuildBudgetIsTestOnly(packageRoot: writePackage(cleanApp));
    });

    // As an app's suite uses it: the package is found from this test file.
    test('passes on this package', expectRebuildBudgetIsTestOnly);

    test('fails on the package under dependencies, naming file and line', () {
      final root = writePackage({
        ...cleanApp,
        'pubspec.yaml': '''
name: shop

dependencies:
  flutter:
    sdk: flutter
  imaji_rebuild_budget: ^0.1.0
''',
      });
      expect(
        () => expectRebuildBudgetIsTestOnly(packageRoot: root),
        failsWith(
          'imaji_rebuild_budget must stay out of the app in $root: it '
          'depends on flutter_test, and every dependency and every import '
          'from lib/ is compiled into release builds.\n'
          '  pubspec.yaml:6: imaji_rebuild_budget is under dependencies, so '
          'it is built into the app. Move it to dev_dependencies.',
        ),
      );
    });

    test('fails on imports from lib/, naming each file and line', () {
      final root = writePackage({
        ...cleanApp,
        'lib/src/debug_menu.dart': '''
import 'package:flutter/widgets.dart';

import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
''',
        'lib/shop.dart': '''
library;

export 'package:imaji_rebuild_budget/guard.dart';
''',
      });
      expect(
        () => expectRebuildBudgetIsTestOnly(packageRoot: root),
        failsWith(
          allOf(
            endsWith(
              '\n'
              '  lib/shop.dart:3: exports '
              'package:imaji_rebuild_budget/guard.dart. Import it only from '
              'test/ or integration_test/.\n'
              '  lib/src/debug_menu.dart:3: imports '
              'package:imaji_rebuild_budget/imaji_rebuild_budget.dart. Import '
              'it only from test/ or integration_test/.',
            ),
            isNot(contains('pubspec.yaml')),
            isNot(contains('lib/main.dart')),
          ),
        ),
      );
    });

    test('passes on a pubspec without dev_dependencies and no lib/', () {
      expectRebuildBudgetIsTestOnly(
        packageRoot: writePackage({'pubspec.yaml': 'name: tool\n'}),
      );
    });

    test('checks a workspace member on its own', () {
      final root = writePackage({
        'pubspec.yaml': 'name: _\nworkspace:\n  - app\n  - kiosk\n',
        'app/pubspec.yaml': '''
name: app
resolution: workspace
dev_dependencies:
  imaji_rebuild_budget: ^0.1.0
''',
        'app/test/widgets/cart_test.dart':
            "import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';\n",
        'kiosk/pubspec.yaml': '''
name: kiosk
resolution: workspace
dependencies:
  imaji_rebuild_budget: ^0.1.0
''',
      });
      expectRebuildBudgetIsTestOnly(packageRoot: '$root/app');
      expect(
        () => expectRebuildBudgetIsTestOnly(packageRoot: '$root/kiosk'),
        failsWith(contains('  pubspec.yaml:4: imaji_rebuild_budget is under')),
      );
      expect(findPackageRoot('$root/app/test/widgets'), endsWith('/app'));
    });

    test('throws on a directory that is not a package', () {
      final root = writePackage({'lib/a.dart': ''});
      expect(
        () => expectRebuildBudgetIsTestOnly(packageRoot: root),
        throwsStateError,
      );
    });
  });

  group('dart run imaji_rebuild_budget:check', () {
    test('exits 0 on a clean app', () {
      final out = StringBuffer();
      final err = StringBuffer();
      final root = writePackage(cleanApp);
      expect(runGuardCheck([root], out: out, err: err), 0);
      expect(
        '$out',
        '$root: imaji_rebuild_budget is a dev dependency only and is not '
            'imported from lib/.\n',
      );
      expect('$err', isEmpty);
    });

    test('exits 1 and lists the findings', () {
      final err = StringBuffer();
      final root = writePackage({
        ...cleanApp,
        'lib/debug.dart':
            "import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';\n",
      });
      expect(runGuardCheck([root], out: StringBuffer(), err: err), 1);
      expect('$err', contains('\n  lib/debug.dart:1: imports '));
    });

    test('prints usage for --help and exits 2 on bad arguments', () {
      final out = StringBuffer();
      expect(runGuardCheck(['--help'], out: out, err: StringBuffer()), 0);
      expect('$out', startsWith('Usage: dart run imaji_rebuild_budget:check'));
      final err = StringBuffer();
      expect(runGuardCheck(['--strict'], out: StringBuffer(), err: err), 2);
      expect('$err', startsWith('Usage: '));
      expect(runGuardCheck(['a', 'b'], out: StringBuffer(), err: err), 2);
    });

    test('exits 2 on a directory without a pubspec', () {
      final err = StringBuffer();
      final empty = Directory.systemTemp.createTempSync('rebuild_guard_');
      addTearDown(() => empty.deleteSync(recursive: true));
      expect(runGuardCheck([empty.path], out: StringBuffer(), err: err), 2);
      expect('$err', 'No pubspec.yaml in ${empty.path}.\n');
    });
  });
}
