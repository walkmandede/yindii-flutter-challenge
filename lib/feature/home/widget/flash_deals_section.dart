import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rescu/service/flash_sale_service.dart';
import 'package:rescu/service/ticker_service.dart';
import 'package:rescu/util/log_service.dart';

import '../../../app_config.dart';
import '../../../model/deal_model.dart';
import '../../../routes/routes.dart';
import '../../shared_widget/the_network_image.dart';

/// Horizontal flash-sale rail.
///
/// NOTE: the countdown is currently a static "Ends soon" label — turning it
/// into a live per-deal countdown is one of the feature tasks in PROBLEM.md.
class FlashDealsSection extends StatefulWidget {
  final List<DealModel> deals;

  const FlashDealsSection({super.key, required this.deals});

  @override
  State<FlashDealsSection> createState() => _FlashDealsSectionState();
}

class _FlashDealsSectionState extends State<FlashDealsSection> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.red, size: 20),
              SizedBox(width: 4),
              Text('Flash sales', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.deals.length,
            itemBuilder: (context, index) {
              final deal = widget.deals[index];

              return SizedBox(
                width: 200,
                child: Card(
                  color: Colors.white,
                  elevation: 0.5,
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => Get.toNamed(
                      Routes.dealRoute(deal.id, source: 'flash_rail'),
                      arguments: deal,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TheNetworkImage(url: deal.imageUrl, height: 90, width: double.infinity),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(deal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(deal.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('฿${deal.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppConfig.primaryGreen)),
                                  const Spacer(),
                                  _endInWidget(deal),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _endInWidget(DealModel deal) {
    final ticker = Get.find<TickerService>();
    return Obx(() {
      final flashSale = Get.find<FlashSaleService>();
      if (deal.isFlashSale) flashSale.track(deal);
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
