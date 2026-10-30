import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:srashtacrmapp/utils/paged_list.dart';

Map<String, dynamic> page(int total, int offset, int limit) => {
      'status': true,
      'total': total,
      'data': [
        for (var i = offset; i < total && i < offset + limit; i++) {'id': i}
      ],
    };

void main() {
  test('loads page 1, then the rest with loadMore', () async {
    final calls = <List<int>>[];
    final l = PagedList((o, n) async {
      calls.add([o, n]);
      return page(70, o, n);
    });
    await l.refresh();
    expect(l.items.length, 30);
    expect(l.total, 70);
    expect(l.hasMore, true);
    await l.loadMore();
    await l.loadMore();
    expect(l.items.length, 70);
    expect(l.hasMore, false);
    await l.loadMore(); // nothing left: no extra request
    expect(calls, [
      [0, 30],
      [30, 30],
      [60, 30]
    ]);
    expect([for (final i in l.items) i['id']], List.generate(70, (i) => i));
  });

  test('a filter change drops the answer of the older request', () async {
    final slow = Completer<Map<String, dynamic>>();
    var n = 0;
    final l = PagedList((o, lim) {
      n++;
      return n == 1 ? slow.future : Future.value(page(5, o, lim));
    });
    final first = l.refresh(); // slow, belongs to the old filter
    await l.refresh(); // newer filter answers first
    slow.complete(page(99, 0, 30)); // stale answer arrives late
    await first;
    expect(l.total, 5);
    expect(l.items.length, 5);
  });

  test('silent refresh keeps rows and refetches as many as are loaded', () async {
    final calls = <List<int>>[];
    final l = PagedList((o, n) async {
      calls.add([o, n]);
      return page(100, o, n);
    });
    await l.refresh();
    await l.loadMore();
    expect(l.items.length, 60);
    final f = l.refresh(silent: true);
    expect(l.items.length, 60); // still on screen while reloading
    expect(l.loading, false);
    await f;
    expect(calls.last, [0, 60]);
    expect(l.items.length, 60);
  });

  test('errors: first page vs later page', () async {
    var fail = false;
    final l = PagedList((o, n) async {
      if (fail) throw Exception('offline');
      return page(60, o, n);
    });
    await l.refresh();
    fail = true;
    await l.loadMore();
    expect(l.moreError, isNotNull);
    expect(l.items.length, 30); // kept what was loaded
    expect(l.loadingMore, false);
    fail = false;
    await l.loadMore(); // retry works
    expect(l.items.length, 60);
    expect(l.moreError, isNull);

    fail = true;
    await l.refresh();
    expect(l.error, isNotNull);
    expect(l.items, isEmpty);
  });

  test('api message is shown when status is false', () async {
    final l = PagedList((o, n) async => {'status': false, 'message': 'No access'});
    await l.refresh();
    expect(l.error, 'No access');
  });
}
