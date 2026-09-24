import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value ? deals.where((d) => d.pickupWindow.isToday).toList() : deals.toList();

  int _refreshId = 0; // increases on every refresh, marks old requests as stale
  bool _isRefreshing = false;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
    _debugTrace();
  }

  void _debugTrace() {
    Timer.periodic(const Duration(seconds: 2), (_) {
      final c = PaintingBinding.instance.imageCache;
      final mb = c.currentSizeBytes / 1048576;
      LogService.log('MEM deals=${deals.length} cache=${mb.toStringAsFixed(1)}MB '
          'images=${c.currentSize}');
    });
  }

  void _onScroll() {
    scrollOffset.value = scrollController.offset;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;

    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    final rid = ++_refreshId;
    _isRefreshing = true;
    _isFetchingMore = false;

    try {
      final res = await dealRepo.fetchDeals(page: 1);
      if (rid != _refreshId) return; // a newer refresh started, ignore this result
      _page = 1;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      refreshController.refreshCompleted();
    } finally {
      if (rid == _refreshId) _isRefreshing = false;
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || _isRefreshing) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }
    _isFetchingMore = true;
    final rid = _refreshId;
    final nextPage = _page + 1;
    try {
      final res = await dealRepo.fetchDeals(page: nextPage);
      if (rid != _refreshId) return; // a refresh happened, ignore this page
      _page = nextPage;
      _totalPages = res.totalPages;
      deals.addAll(res.items);
    } catch (e) {
      LogService.error('loadMore failed', e);
    } finally {
      if (rid == _refreshId) _isFetchingMore = false;
      refreshController.loadComplete();
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
