import 'deal_model.dart';
import 'reservation_model.dart';

enum ReservationStatus {
  pending, // optimistic add, server call still in flight
  active, // success from the server, (failure will remove the cartItem from the bag)
  expired, // the n-minute hold ran out while still in the bag
}

class CartItemModel {
  final DealModel deal;
  int quantity;

  /// Stock hold for this line item. The starter app does not reserve stock —
  /// see the "Reservations" feature task.
  ReservationModel? reservation;
  ReservationStatus reservationStatus;
  bool isLoading; //pending reserve or release calls

  CartItemModel({
    required this.deal,
    this.quantity = 1,
    this.reservation,
    this.reservationStatus = ReservationStatus.pending,
    this.isLoading = false,
  });

  num get lineTotal => deal.price * quantity;
}
