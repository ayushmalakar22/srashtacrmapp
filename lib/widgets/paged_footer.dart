import 'package:flutter/material.dart';
import '../utils/paged_list.dart';

/// Last row of a [PagedList]: "Showing 30 of 245" + a Load more button, a
/// spinner while loading, or a retry when a page failed. Scrolling to the
/// bottom loads the next page by itself; the button covers short screens.
class PagedFooter extends StatelessWidget {
  final PagedList list;
  const PagedFooter({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    if (!list.hasMore && list.moreError == null) {
      return list.items.length > 30
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('All ${list.total} loaded',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12.5))),
            )
          : const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          if (list.loadingMore)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else if (list.moreError != null)
            OutlinedButton.icon(
              onPressed: list.loadMore,
              icon: const Icon(Icons.refresh),
              label: Text('${list.moreError} - tap to retry'),
            )
          else
            OutlinedButton(
              onPressed: list.loadMore,
              child: Text('Load more (${list.total - list.items.length} left)'),
            ),
          const SizedBox(height: 6),
          Text('Showing ${list.items.length} of ${list.total}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
        ],
      ),
    );
  }
}
