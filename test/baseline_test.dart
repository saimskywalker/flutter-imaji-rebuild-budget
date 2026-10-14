import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
import 'package:imaji_rebuild_budget/src/baseline_store.dart';

import 'support/fixtures.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rebuild_baseline_');
    path = '${dir.path}/budgets.json';
  });
  tearDown(() {
    dir.deleteSync(recursive: true);
    RebuildCounter.updateBaselines = false;
  });

  Future<RebuildCounter> bumpOnce(WidgetTester tester) async {
    final screen = await pumpScreen(tester);
    final window = RebuildCounter.open();
    screen.bump();
    await tester.pump();
    window.close();
    return window;
  }

  Matcher baseline({String key = 'bump'}) => matchesRebuildBaseline(
        path,
        key: key,
        types: [CountLabel, Footer],
        named: ['Ornament'],
      );

  void writeJson(Object json) => File(path).writeAsStringSync(jsonEncode(json));

  testWidgets('update mode writes the measured counts, sorted', (tester) async {
    final window = await bumpOnce(tester);
    writeJson({
      'zzz other test': {'Footer': 0},
    });

    RebuildCounter.updateBaselines = true;
    expect(window, baseline());

    expect(
      File(path).readAsStringSync(),
      '{\n'
      '  "bump": {\n'
      '    "CountLabel": 2,\n'
      '    "Footer": 0,\n'
      '    "Ornament": 1\n'
      '  },\n'
      '  "zzz other test": {\n'
      '    "Footer": 0\n'
      '  }\n'
      '}\n',
    );
  });

  testWidgets('update mode creates the file and its directory', (tester) async {
    final window = await bumpOnce(tester);
    path = '${dir.path}/nested/deeper/budgets.json';

    RebuildCounter.updateBaselines = true;
    expect(window, baseline());

    expect(File(path).existsSync(), isTrue);
  });

  testWidgets('passes within the stored budgets', (tester) async {
    final window = await bumpOnce(tester);
    writeJson({
      'bump': {'CountLabel': 2, 'Footer': 0, 'Ornament': 3},
    });

    expect(window, baseline());
  });

  testWidgets('fails over a stored budget, with the busiest table',
      (tester) async {
    final window = await bumpOnce(tester);
    writeJson({
      'bump': {'CountLabel': 1, 'Footer': 0, 'Ornament': 1},
    });

    final message = mismatchOf(baseline(), window);
    expect(message,
        contains('- CountLabel rebuilt 2 times, budget 1 (over by 1)'));
    expect(message, contains('2  CountLabel  budget 1, over by 1'));
    expect(message, contains('1  Ornament    budget 1'));
  });

  testWidgets('fails when the file, the key or a type is missing',
      (tester) async {
    final window = await bumpOnce(tester);

    expect(mismatchOf(baseline(), window), contains('does not exist'));

    writeJson({'other': <String, int>{}});
    expect(mismatchOf(baseline(), window), contains('has no entry "bump"'));

    writeJson({
      'bump': {'CountLabel': 2, 'Ornament': 1},
    });
    expect(
      mismatchOf(baseline(), window),
      contains('Footer is tracked but has no budget'),
    );
  });

  testWidgets('fails when the file stores a type the test no longer tracks',
      (tester) async {
    final window = await bumpOnce(tester);
    writeJson({
      'bump': {'CountLabel': 2, 'Footer': 0, 'Ornament': 1, 'Gone': 4},
    });

    expect(
      mismatchOf(baseline(), window),
      contains('stores a budget for Gone, which this test no longer tracks'),
    );
  });

  testWidgets('rejects a malformed file', (tester) async {
    final window = await bumpOnce(tester);

    File(path).writeAsStringSync('{not json');
    expect(() => baseline().matches(window, {}), throwsFormatException);

    writeJson({
      'bump': {'CountLabel': 'two'},
    });
    expect(() => baseline().matches(window, {}), throwsFormatException);

    writeJson({
      'bump': {'CountLabel': -1},
    });
    expect(() => baseline().matches(window, {}), throwsFormatException);
  });

  test('needs at least one tracked type', () {
    expect(
        () => matchesRebuildBaseline('x.json', key: 'k'), throwsArgumentError);
  });

  test('a relative path resolves next to the test file, like a golden', () {
    final resolved = resolveBaselinePath('rebuild_budgets/home.json');
    final testDir = (goldenFileComparator as LocalFileComparator).basedir;
    expect(resolved, testDir.resolve('rebuild_budgets/home.json').toFilePath());
    expect(resolved, endsWith('test/rebuild_budgets/home.json'));
  });

  test('an absolute path is used as is', () {
    expect(resolveBaselinePath(path), path);
  });

  test('update mode is off unless UPDATE_REBUILD_BUDGETS is defined', () {
    expect(
      RebuildCounter.updateBaselines,
      const bool.fromEnvironment('UPDATE_REBUILD_BUDGETS'),
    );
  });
}
