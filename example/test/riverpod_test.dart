import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/imaji_rebuild_budget.dart';
import 'package:imaji_rebuild_budget_example/riverpod/cart.dart';

Future<RebuildCounter> applyCoupon(WidgetTester tester, Widget badge) async {
  await tester.pumpWidget(
    ProviderScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [badge, const CouponLabel()]),
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byWidget(badge)),
  );

  final window = RebuildCounter.open(label: 'apply a coupon');
  container.read(cartProvider.notifier).applyCoupon('SPRING');
  await tester.pump();
  window.close();
  return window;
}

void main() {
  testWidgets('BEFORE: ref.watch(cartProvider) rebuilds the item badge for a '
      'coupon', (tester) async {
    final window = await applyCoupon(tester, const CartBadgeSlow());

    expect(window, interactionHappened(rebuilt: CouponLabel));
    expect(window, isNot(rebuiltAtMost(0, of: CartBadgeSlow)));
  });

  testWidgets('AFTER: ref.watch(cartProvider.select(...)) leaves it alone', (
    tester,
  ) async {
    final window = await applyCoupon(tester, const CartBadgeFast());

    expect(window, interactionHappened(rebuilt: CouponLabel));
    expect(window, rebuiltAtMost(0, of: CartBadgeFast));
  });

  testWidgets('the fixed badge still rebuilds when the item count changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: CartBadgeFast(),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CartBadgeFast)),
    );

    final window = RebuildCounter.open();
    container.read(cartProvider.notifier).add('Desk');
    await tester.pump();
    window.close();

    expect(window.countOf(CartBadgeFast), 1);
    expect(find.text('3 items'), findsOneWidget);
  });
}
