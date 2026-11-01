// No binding at all: a plain test() in a file that never calls testWidgets.
// It needs a file of its own because declaring any testWidgets initializes
// the test binding for the whole isolate.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuildcop/rebuildcop.dart';

void main() {
  test('there is no binding', () {
    expect(BindingBase.debugBindingType(), isNull);
  });

  test('open refuses to run and says where to open windows', () {
    expect(
      RebuildCounter.open,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            startsWith('rebuildcop only runs under flutter test.'),
            contains('inside testWidgets'),
          ),
        ),
      ),
    );
  });
}
