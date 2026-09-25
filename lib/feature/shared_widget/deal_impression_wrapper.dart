import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rescu/service/deal_impression_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

class DealImpressionWrapper extends StatefulWidget {
  final DealImpressionMeta meta;
  final Widget child;
  final double visibaleFractionThreashold;
  final int visibleDurationThreasholdInMs;

  const DealImpressionWrapper({
    super.key,
    required this.meta,
    required this.child,
    this.visibaleFractionThreashold = 0.5,
    this.visibleDurationThreasholdInMs = 1000,
  });

  @override
  State<DealImpressionWrapper> createState() => _DealImpressionWrapperState();
}

class _DealImpressionWrapperState extends State<DealImpressionWrapper> {
  Timer? _visibleTimer;

  DealImpressionMeta get meta => widget.meta;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('impression-${meta.source}-${meta.dealId}-${meta.position}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= widget.visibaleFractionThreashold) {
          _visibleTimer ??= Timer(Duration(milliseconds: widget.visibleDurationThreasholdInMs), () {
            Get.find<DealImpressionService>().trackImpression(meta: meta);
          });
        } else {
          _visibleTimer?.cancel();
          _visibleTimer = null;
        }
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _visibleTimer?.cancel();
    super.dispose();
  }
}
