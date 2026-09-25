import 'dart:async';
import 'package:get/get.dart';
import 'analytics_service.dart';
import 'fake_api_service.dart';
import '../util/log_service.dart';

enum DealImpressionSource {
  homeFeed,
  flashRail,
  search,
}

class DealImpressionMeta {
  final int dealId;
  final DealImpressionSource source;
  final int position;

  DealImpressionMeta({
    required this.dealId,
    required this.position,
    required this.source,
  });

  Map<String, dynamic> toEventMap() {
    return {
      'deal_id': dealId,
      'source': source.name,
      'position': position,
    };
  }
}

class DealImpressionService extends GetxService {
  final AnalyticsService analytics;
  final FakeApiService api;

  DealImpressionService({required this.analytics, required this.api});

  // Deal ids already logged this session — at most once per deal.
  final Set<int> _loggedDealIds = {};

  // Events collected but not sent yet.
  final List<Map<String, dynamic>> _pendingEvents = [];

  // Starts counting from the first unsent event; cancelled on flush.
  Timer? _flushTimer;

  void trackImpression({
    required DealImpressionMeta meta,
  }) {
    if (_loggedDealIds.contains(meta.dealId)) return;
    _loggedDealIds.add(meta.dealId);

    final event = meta.toEventMap();

    analytics.logEvent('deal_impression', event); // shows on debug screen right away
    _pendingEvents.add(event);

    //Logic for: either 10 events have accumulated or 15 seconds have passed since the first unsent event — whichever comes first.
    //if no flush timer, assing new one, unless, skip
    _flushTimer ??= Timer(const Duration(seconds: 15), _sendPendingEvents);
    if (_pendingEvents.length >= 10) _sendPendingEvents();
  }

  Future<void> _sendPendingEvents() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingEvents.isEmpty) return;

    // Send a copy so new impressions during the request start a fresh batch. and can retry after failure to send batch
    final eventsToSend = List<Map<String, dynamic>>.from(_pendingEvents);
    _pendingEvents.clear();

    try {
      await api.sendAnalyticsBatch(eventsToSend);
    } catch (e) {
      LogService.error('Failed to send analytics batch, will retry', e);
      _pendingEvents.insertAll(0, eventsToSend); // don't lose events on failure
      _flushTimer = Timer(const Duration(seconds: 15), _sendPendingEvents);
    }
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    super.onClose();
  }
}
