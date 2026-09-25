import 'package:get/get.dart';
import '../model/deal_model.dart';
import 'cart_service.dart';
import 'ticker_service.dart';

class FlashSaleService extends GetxService {
  final TickerService ticker; //tikcer injected instead of Get.find, so we can change per second ticker to perminute tikcer later if we need
  final CartService cartService;

  FlashSaleService({required this.ticker, required this.cartService});

  final expiredDealIds = <int>{}.obs;
  final Map<int, DateTime> _tracked = {};

  //tied with Deal Widget
  void track(DealModel deal) {
    if (!deal.isFlashSale || _tracked.containsKey(deal.id)) return;
    _tracked[deal.id] = deal.flashSaleEndsAt!;
    ever(ticker.now, (_) => _checkExpiry(deal.id));
    _checkExpiry(deal.id); // in case it is already expired on first build
  }

  bool isExpired(int dealId) => expiredDealIds.contains(dealId);

  void _checkExpiry(int dealId) {
    final endsAt = _tracked[dealId];
    if (endsAt == null || expiredDealIds.contains(dealId)) return;
    if (!ticker.now.value.isBefore(endsAt)) {
      expiredDealIds.add(dealId);
      if (cartService.items.any((i) => i.deal.id == dealId)) {
        final name = cartService.items.firstWhere((i) => i.deal.id == dealId).deal.name;
        cartService.remove(dealId);
        Get.snackbar(
          'Deal expired',
          '$name was removed from your bag because its flash sale ended.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }
}
