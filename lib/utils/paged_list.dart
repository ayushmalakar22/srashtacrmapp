import 'package:flutter/foundation.dart';

/// A list loaded a page at a time. [fetch] must return the API's
/// `{status, data: [...], total}` map for the given offset and limit.
///
/// Listen to it (it is a [ChangeNotifier]) and rebuild from [items],
/// [loading], [loadingMore], [error] and [hasMore].
class PagedList extends ChangeNotifier {
  final Future<Map<String, dynamic>> Function(int offset, int limit) fetch;
  final int pageSize;

  PagedList(this.fetch, {this.pageSize = 30});

  List items = [];
  int total = 0;
  bool loading = true; // first page (or a filter change) is loading
  bool loadingMore = false;
  String? error; // first page failed
  String? moreError; // a later page failed
  int _generation = 0; // drops answers that belong to an older filter

  bool get hasMore => items.length < total;

  /// Starts again from the first page. With [silent] the current rows stay on
  /// screen meanwhile and as many rows as are loaded now are fetched again,
  /// so coming back from an edit does not throw the scroll position away.
  Future<void> refresh({bool silent = false}) async {
    final gen = ++_generation;
    loadingMore = false;
    moreError = null;
    if (!silent) {
      loading = true;
      error = null;
      items = [];
      total = 0;
    }
    notifyListeners();

    final limit = silent ? items.length.clamp(pageSize, 500).toInt() : pageSize;
    try {
      final res = await fetch(0, limit);
      if (gen != _generation) return;
      if (res['status'] == true) {
        items = List.from(res['data'] ?? []);
        total = (res['total'] as num?)?.toInt() ?? items.length;
        error = null;
      } else {
        error = res['message']?.toString() ?? 'Failed to load';
      }
    } catch (_) {
      if (gen != _generation) return;
      error = 'Cannot reach the server. Check Wi-Fi and pull down to retry.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final gen = _generation;
    loadingMore = true;
    moreError = null;
    notifyListeners();
    try {
      final res = await fetch(items.length, pageSize);
      if (gen != _generation) return;
      if (res['status'] == true) {
        items = [...items, ...(res['data'] as List? ?? [])];
        total = (res['total'] as num?)?.toInt() ?? items.length;
      } else {
        moreError = res['message']?.toString() ?? 'Failed to load more';
      }
    } catch (_) {
      if (gen != _generation) return;
      moreError = 'Could not load more';
    }
    loadingMore = false;
    notifyListeners();
  }
}
