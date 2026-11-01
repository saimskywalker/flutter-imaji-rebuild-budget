// The binding of a running app, as in a debug build that wires a window into
// a debug menu. A binding cannot be swapped once initialized, and flutter
// test runs every test file in its own isolate, so this check needs a file
// of its own with no testWidgets in it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/rebuildcop.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  test('the binding is an app binding, not a test binding', () {
    expect(WidgetsBinding.instance, isNot(isA<TestWidgetsFlutterBinding>()));
  });

  test('open refuses to run and leaves the hook alone', () {
    expect(
      RebuildWindow.open,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            startsWith(
              'rebuildcop only runs under flutter test. It must be '
              'a dev_dependency and must not be imported from lib/.',
            ),
            contains('WidgetsFlutterBinding'),
          ),
        ),
      ),
    );
    expect(debugOnRebuildDirtyWidget, isNull);
  });

  test('record refuses before the interaction runs', () async {
    var ran = false;
    await expectLater(
      RebuildWindow.record(() async => ran = true),
      throwsStateError,
    );
    expect(ran, isFalse);
    expect(debugOnRebuildDirtyWidget, isNull);
  });
}
