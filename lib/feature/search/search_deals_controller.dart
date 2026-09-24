import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  Timer? _debounceTimer;
  final int _debouneDurationInSecond = 300;
  int _latestRequestId = 0;

  void onQueryChanged(String query) {
    LogService.log('New Query Received: $query');

    _debounceTimer?.cancel();

    // Prioritize the latest request input
    final currentId = ++_latestRequestId;

    // need to check for empty queries first so debounce doesn't work for them
    if (query.trim().isEmpty) {
      results.clear();
      hasSearched.value = false;
      isLoading.value = false;
      return;
    }

    _debounceTimer = Timer(
      Duration(milliseconds: _debouneDurationInSecond),
      () => _search(query, currentId),
    );
  }

  Future<void> _search(String query, int currentId) async {
    isLoading.value = true;
    hasSearched.value = true;
    try {
      final found = await dealRepo.search(query);
      if (currentId != _latestRequestId) return; // a newer query exists, ignore this result
      results.assignAll(found);
    } catch (e) {
      LogService.error('search failed', e);
    }
    if (currentId == _latestRequestId) isLoading.value = false;
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}
