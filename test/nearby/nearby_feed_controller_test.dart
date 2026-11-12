import 'dart:async';
import 'package:bakhli/features/nearby/controllers/nearby_feed_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _C extends NearbyFeedController<String> {
  final version = 0.obs;
  final calls = <String?>[];
  Future<NearbyPage<String>> Function(String? token) handler;
  DateTime clock = DateTime(2026, 1, 1);
  _C(this.handler);

  @override
  RxInt get centreVersion => version;
  @override
  RxInt? get tabRx => null;
  @override
  DateTime now() => clock;
  @override
  String idOf(String i) => i;
  @override
  Future<NearbyPage<String>> fetchPage(String? token) {
    calls.add(token);
    return handler(token);
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => Get.testMode = true);

  test('loads first page, dedupes items against featured', () async {
    final c = _C((t) async => const NearbyPage(featured: ['a'], items: ['a', 'b', 'c'], hasMore: false));
    c.onInit();
    await _flush();
    expect(c.featured, ['a']);
    expect(c.items, ['b', 'c']);
    expect(c.isLoading.value, false);
    expect(c.isThin, false);
  });

  test('empty and thin states', () async {
    final e = _C((t) async => const NearbyPage());
    e.onInit();
    await _flush();
    expect(e.isEmpty, true);
    final th = _C((t) async => const NearbyPage(items: ['a', 'b']));
    th.onInit();
    await _flush();
    expect(th.isThin, true);
    expect(th.isEmpty, false);
  });

  test('pagination appends and dedupes', () async {
    final c = _C((t) async => t == null
        ? const NearbyPage(items: ['a', 'b'], hasMore: true, nextToken: 't1')
        : const NearbyPage(items: ['b', 'c'], hasMore: false));
    c.onInit();
    await _flush();
    expect(c.hasMore.value, true);
    await c.loadNextPage();
    expect(c.items, ['a', 'b', 'c']);
    expect(c.hasMore.value, false);
    expect(c.calls, [null, 't1']);
    await c.loadNextPage();
    expect(c.calls.length, 2);
  });

  test('load more failure sets flag and retry works', () async {
    var fail = true;
    final c = _C((t) async {
      if (t == null) return const NearbyPage(items: ['a'], hasMore: true, nextToken: 't1');
      if (fail) throw StateError('x');
      return const NearbyPage(items: ['z']);
    });
    c.onInit();
    await _flush();
    await c.loadNextPage();
    expect(c.loadMoreFailed.value, true);
    fail = false;
    await c.loadNextPage();
    expect(c.items, ['a', 'z']);
    expect(c.loadMoreFailed.value, false);
  });

  test('first load failure then retry', () async {
    var fail = true;
    final c = _C((t) async {
      if (fail) throw StateError('x');
      return const NearbyPage(items: ['a', 'b', 'c']);
    });
    c.onInit();
    await _flush();
    expect(c.loadFailed.value, true);
    expect(c.isEmpty, false);
    fail = false;
    await c.retry();
    expect(c.loadFailed.value, false);
    expect(c.items.length, 3);
  });

  test('stale response is dropped', () async {
    final first = Completer<NearbyPage<String>>();
    var n = 0;
    final c = _C((t) {
      n++;
      return n == 1 ? first.future : Future.value(const NearbyPage(items: ['new']));
    });
    c.onInit();
    await _flush();
    final second = c.reload();
    await second;
    first.complete(const NearbyPage(items: ['old']));
    await _flush();
    expect(c.items, ['new']);
  });

  test('reloads once when centre changes, coalesced', () async {
    final c = _C((t) async => const NearbyPage(items: ['a']));
    c.onInit();
    await _flush();
    expect(c.calls.length, 1);
    c.version.value++;
    c.version.value++;
    await _flush();
    await _flush();
    expect(c.calls.length, 2);
  });

  test('refreshIfNeeded skips fresh data and reloads when stale', () async {
    final c = _C((t) async => const NearbyPage(items: ['a']));
    c.onInit();
    await _flush();
    await c.refreshIfNeeded();
    expect(c.calls.length, 1);
    c.clock = c.clock.add(const Duration(minutes: 3));
    await c.refreshIfNeeded();
    expect(c.calls.length, 2);
  });

  test('scroll past 70 percent loads next page', () async {
    final c = _C((t) async => t == null
        ? const NearbyPage(items: ['a'], hasMore: true, nextToken: 't1')
        : const NearbyPage(items: ['b']));
    c.onInit();
    await _flush();
    c.onScrollMetrics(FixedScrollMetrics(
        minScrollExtent: 0, maxScrollExtent: 1000, pixels: 500, viewportDimension: 600, axisDirection: AxisDirection.down, devicePixelRatio: 1));
    await _flush();
    expect(c.calls.length, 1);
    c.onScrollMetrics(FixedScrollMetrics(
        minScrollExtent: 0, maxScrollExtent: 1000, pixels: 750, viewportDimension: 600, axisDirection: AxisDirection.down, devicePixelRatio: 1));
    await _flush();
    expect(c.calls.length, 2);
    expect(c.items, ['a', 'b']);
  });
}
