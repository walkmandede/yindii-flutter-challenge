import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;

  Future<void> checkout() async {
    if (cartService.items.isEmpty || isCheckingOut.value) return;

    if (!cartService.canCheckout) {
      Get.snackbar(
        'Check your bag',
        'One or more items need a fresh hold before you can check out.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isCheckingOut.value = true;
    try {
      final order = await orderRepo.checkout(cartService.items.toList());
      cartService.clear();
      Get.snackbar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);
      if (e.statusCode == 410) {
        cartService.checkForExpiredHolds();
        Get.snackbar(
          'A hold just expired',
          "One of your items' reservations expired. Please review your bag and try again.",
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Checkout failed',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
    isCheckingOut.value = false;
  }
}
