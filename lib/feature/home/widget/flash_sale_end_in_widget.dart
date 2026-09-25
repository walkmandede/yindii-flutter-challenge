import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/shared_widget/count_down_label_widget.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/service/flash_sale_service.dart';

class FlashSaleEndInWidget extends StatelessWidget {
  final DealModel deal;

  const FlashSaleEndInWidget({
    super.key,
    required this.deal,
  });

  @override
  Widget build(BuildContext context) {
    if (deal.flashSaleEndsAt == null) return const SizedBox.shrink();
    final flashSale = Get.find<FlashSaleService>();
    if (deal.isFlashSale) flashSale.track(deal);

    return Obx(() {
      final expired = deal.isFlashSale && flashSale.isExpired(deal.id);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: expired ? Colors.grey.shade600 : Colors.red.shade600,
          borderRadius: BorderRadius.circular(6),
        ),
        child: expired
            ? const Text('EXPIRED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (deal.flashSaleEndsAt != null) const Text('End In ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (deal.flashSaleEndsAt != null)
                    CountdownLabelWidget(
                      endsAt: deal.flashSaleEndsAt!,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
      );
    });
  }
}
