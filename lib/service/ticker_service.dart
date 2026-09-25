import 'dart:async';
import 'package:get/get.dart';

class TickerService extends GetxService {
  final now = DateTime.now().obs;
  Timer? _timer;

  final int durationInMs;

  TickerService({
    this.durationInMs = 1000, //default 1 sec
  });

  @override
  void onInit() {
    super.onInit();
    _timer = Timer.periodic(Duration(milliseconds: durationInMs), (_) {
      now.value = DateTime.now();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
