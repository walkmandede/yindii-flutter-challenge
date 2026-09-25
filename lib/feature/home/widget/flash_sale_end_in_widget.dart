import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/service/flash_sale_service.dart';
import 'package:rescu/service/ticker_service.dart';

class FlashSaleEndInWidget extends StatelessWidget {
  final DealModel deal;

  const FlashSaleEndInWidget({
    super.key,
    required this.deal,
  });

  @override
  Widget build(BuildContext context) {
    final ticker = Get.find<TickerService>();
    final flashSale = Get.find<FlashSaleService>();
    if (deal.isFlashSale) flashSale.track(deal);

    return Obx(() {
      final expired = deal.isFlashSale && flashSale.isExpired(deal.id);
      final remaining = deal.flashSaleEndsAt?.difference(ticker.now.value) ?? Duration(seconds: -1);

      final h = remaining.inHours;
      final m = remaining.inMinutes.remainder(60);
      final s = remaining.inSeconds.remainder(60);
      final text = h > 0
          ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: expired ? Colors.grey.shade600 : Colors.red.shade600,
          borderRadius: BorderRadius.circular(6),
        ),
        child: expired
            ? const Text('EXPIRED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
            : Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
      );
    });
  }
}
