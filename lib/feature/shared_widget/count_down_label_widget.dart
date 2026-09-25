import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../service/ticker_service.dart';

/// Plain "mm:ss" / "hh:mm:ss" countdown to [endsAt]. No expiry badge, no
/// tracking — just the ticking text, reading off the shared TickerService.
class CountdownLabelWidget extends StatelessWidget {
  final DateTime endsAt;
  final TextStyle? style;

  const CountdownLabelWidget({super.key, required this.endsAt, this.style});

  @override
  Widget build(BuildContext context) {
    final ticker = Get.find<TickerService>();
    return Obx(() {
      final remaining = endsAt.difference(ticker.now.value);
      if (remaining.isNegative) return const SizedBox.shrink();

      final h = remaining.inHours;
      final m = remaining.inMinutes.remainder(60);
      final s = remaining.inSeconds.remainder(60);
      final text = h > 0
          ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      return Text(text, style: style);
    });
  }
}
