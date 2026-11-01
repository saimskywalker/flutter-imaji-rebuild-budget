import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/rebuildcop.dart';
import 'package:rebuildcop/src/verdict/baseline/baseline_file.dart';

import 'support/fixtures.dart';
import 'support/tile_a.dart' as a;
import 'support/tile_b.dart' as b;

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rebuild_baseline_');
    path = '${dir.path}/budgets.json';
  });
  tearDown(() {
    dir.deleteSync(recursive: true);
    RebuildWindow.updateBaselines = false;
  });

  Future<RebuildWindow> bumpOnce(WidgetTester tester) async {
    final screen = await showScreen(tester);
    final window = RebuildWindow.open();
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

    RebuildWindow.updateBaselines = true;
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

    RebuildWindow.updateBaselines = true;
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

  testWidgets('fails for a tracked type that never appeared', (tester) async {
    final window = await bumpOnce(tester);
    Matcher tracking({bool allowAbsent = false}) => matchesRebuildBaseline(
          path,
          key: 'bump',
          types: [CountLabel, ListRow],
          named: ['_Gone'],
          allowAbsent: allowAbsent,
        );
    writeJson({
      'bump': {'CountLabel': 2, 'ListRow': 0, '_Gone': 0},
    });

    final message = mismatchOf(tracking(), window);
    expect(
      message,
      contains('- no ListRow element existed during the rebuild window, so '
          'this budget could never fail.'),
    );
    expect(
      message,
      contains('- no widget type named _Gone existed during the rebuild '
          'window'),
    );
    expect(window, tracking(allowAbsent: true));
  });

  testWidgets('update mode does not write a budget that could never fail',
      (tester) async {
    final window = await bumpOnce(tester);

    RebuildWindow.updateBaselines = true;
    final message = mismatchOf(
      matchesRebuildBaseline(path, key: 'bump', types: [ListRow]),
      window,
    );

    expect(message, contains('no ListRow element existed'));
    expect(message, contains('nothing was written to $path'));
    expect(File(path).existsSync(), isFalse);
  });

  testWidgets('tells two same-named types apart', (tester) async {
    final window = await tickTiles(tester, withA: true, withB: true);
    writeJson({
      'tick': {'Tile': 1},
    });

    // By type, only that type is counted.
    expect(
      window,
      matchesRebuildBaseline(path, key: 'tick', types: [a.Tile]),
    );
    // By name, the two would be added up.
    expect(
      mismatchOf(
        matchesRebuildBaseline(path, key: 'tick', named: ['Tile']),
        window,
      ),
      contains('- 2 different types named Tile rebuilt during window "tick"'),
    );
  });

  testWidgets('says when a tracked type was replaced by a same-named one',
      (tester) async {
    final window = await tickTiles(tester, withB: true);
    writeJson({
      'tick': {'Tile': 1},
    });

    expect(
      mismatchOf(
        matchesRebuildBaseline(path, key: 'tick', types: [a.Tile]),
        window,
      ),
      contains('A different type with the same name, Tile, was present'),
    );
  });

  test('rejects two tracked entries with the same name', () {
    expect(
      () => matchesRebuildBaseline('x.json', key: 'k', types: [a.Tile, b.Tile]),
      throwsArgumentError,
    );
    expect(
      () => matchesRebuildBaseline(
        'x.json',
        key: 'k',
        types: [a.Tile],
        named: ['Tile'],
      ),
      throwsArgumentError,
    );
    // The same type twice is just one entry.
    expect(
      () => matchesRebuildBaseline('x.json', key: 'k', types: [a.Tile, a.Tile]),
      returnsNormally,
    );
  });

  test('needs at least one tracked type', () {
    expect(
        () => matchesRebuildBaseline('x.json', key: 'k'), throwsArgumentError);
  });

  test('a relative path resolves next to the test file, like a golden', () {
    final resolved = locateBaselineFile('rebuild_budgets/home.json');
    final testDir = (goldenFileComparator as LocalFileComparator).basedir;
    expect(resolved, testDir.resolve('rebuild_budgets/home.json').toFilePath());
    expect(resolved, endsWith('test/rebuild_budgets/home.json'));
  });

  test('an absolute path is used as is', () {
    expect(locateBaselineFile(path), path);
  });

  test('update mode is off unless UPDATE_REBUILD_BUDGETS is defined', () {
    expect(
      RebuildWindow.updateBaselines,
      const bool.fromEnvironment('UPDATE_REBUILD_BUDGETS'),
    );
  });
}
