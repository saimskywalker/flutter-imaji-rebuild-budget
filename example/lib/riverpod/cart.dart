import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A shopping cart: its items and an optional coupon code.
@immutable
class Cart {
  /// Creates a cart.
  const Cart({this.items = const [], this.coupon});

  /// What is in the cart.
  final List<String> items;

  /// The applied coupon, if any.
  final String? coupon;
}

/// Holds the [Cart].
class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() => const Cart(items: ['Lamp', 'Chair']);

  /// Adds [item].
  void add(String item) =>
      state = Cart(items: [...state.items, item], coupon: state.coupon);

  /// Applies [code]; the item count does not change.
  void applyCoupon(String code) =>
      state = Cart(items: state.items, coupon: code);
}

/// The cart.
final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

/// BEFORE: watches the whole cart to show one number, so applying a coupon
/// rebuilds the badge.
class CartBadgeSlow extends ConsumerWidget {
  /// Creates the badge.
  const CartBadgeSlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Text('${cart.items.length} items');
  }
}

/// AFTER: selects only the item count.
class CartBadgeFast extends ConsumerWidget {
  /// Creates the badge.
  const CartBadgeFast({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((cart) => cart.items.length));
    return Text('$count items');
  }
}

/// Shows the coupon; it is meant to rebuild when the coupon changes.
class CouponLabel extends ConsumerWidget {
  /// Creates the label.
  const CouponLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupon = ref.watch(cartProvider.select((cart) => cart.coupon));
    return Text(coupon ?? 'No coupon');
  }
}
