import 'dart:async';

import 'package:get/get.dart';
import 'package:rescu/repository/order_repo.dart';
import 'package:rescu/service/ticker_service.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final OrderRepo orderRepo;
  final TickerService ticker;

  CartService({required this.orderRepo, required this.ticker});

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  Future<void> _reserveLine(
    CartItemModel item, {
    required int previousQuantityOnFailure,
    ReservationStatus statusOnRollback = ReservationStatus.active,
  }) async {
    final oldReservationId = item.reservation?.id;
    try {
      final newReservation = await orderRepo.reserve(item.deal.id, quantity: item.quantity);

      if (!items.contains(item)) {
        unawaited(orderRepo.releaseReservation(newReservation.id));
        return;
      }

      item.reservation = newReservation;
      item.reservationStatus = ReservationStatus.active;
      item.isLoading = false;
      items.refresh();

      if (oldReservationId != null) {
        unawaited(orderRepo.releaseReservation(oldReservationId));
      }
    } catch (e) {
      LogService.error('reserve failed for deal ${item.deal.id}', e);
      if (previousQuantityOnFailure <= 0) {
        items.remove(item);
      } else {
        item.quantity = previousQuantityOnFailure;
        item.reservationStatus = statusOnRollback;
        item.isLoading = false;
        items.refresh();
      }
      _recount();
      Get.snackbar(
        'Could not reserve',
        "Sorry, we couldn't hold ${item.deal.name} — someone may have just taken the last one.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> add(DealModel deal) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);

    if (existing != null) {
      if (existing.isLoading) return;
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      final previousQuantity = existing.quantity;
      existing.quantity++;
      existing.isLoading = true;
      items.refresh();
      _recount();
      await _reserveLine(existing, previousQuantityOnFailure: previousQuantity);
      return;
    }

    final item = CartItemModel(deal: deal, quantity: 1);
    items.add(item);
    _recount();
    await _reserveLine(item, previousQuantityOnFailure: 0);
  }

  Future<void> decrement(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null || existing.isLoading) return;

    if (existing.quantity <= 1) {
      await remove(dealId);
      return;
    }

    final previousQuantity = existing.quantity;
    existing.quantity--;
    existing.isLoading = true;
    items.refresh();
    await _reserveLine(existing, previousQuantityOnFailure: previousQuantity);
  }

  //it also release the reserveation
  Future<void> remove(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();

    final reservationId = existing?.reservation?.id;
    if (reservationId != null) {
      try {
        await orderRepo.releaseReservation(reservationId);
      } catch (e) {
        LogService.error('release failed for reservation $reservationId', e);
      }
    }
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
