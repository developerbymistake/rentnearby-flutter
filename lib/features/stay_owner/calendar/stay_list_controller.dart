import 'package:get/get.dart';

import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_page.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/sheets/owner_states.dart';

sealed class StayListItem {
  const StayListItem();
}

class StayListHeader extends StayListItem {
  const StayListHeader(this.month, this.count, {this.title});
  final DateTime month;
  final int count;
  final String? title;
}

class StayListEntry extends StayListItem {
  const StayListEntry(this.entry, {required this.first, required this.last});
  final CalendarEntry entry;
  final bool first;
  final bool last;
}

class StayListBlock extends StayListItem {
  const StayListBlock(this.block, {required this.first, required this.last});
  final CalendarBlock block;
  final bool first;
  final bool last;
}

typedef StayPageLoader = Future<OwnerResult<Map<String, dynamic>>> Function(String? cursor);

class StayListController extends GetxController {
  StayListController({
    required this.loader,
    this.cacheKey,
    this.userIdOf,
    this.newestFirst = false,
    this.blocksLoader,
    this.onFirstPage,
  });

  final StayPageLoader loader;
  final String? cacheKey;
  final String? Function()? userIdOf;
  final bool newestFirst;
  final Future<List<CalendarBlock>> Function()? blocksLoader;
  final void Function(Map<String, dynamic> raw)? onFirstPage;

  final load = Rx<OwnerLoad<List<StayListItem>>>(const OwnerLoadLoading());
  final loadingMore = false.obs;
  final items = <CalendarEntry>[];
  final blocks = <CalendarBlock>[];
  String? cursor;
  final LatestOnly _latest = LatestOnly();

  bool get hasMore => cursor != null;

  @override
  void onInit() {
    super.onInit();
    final saved = _readSaved();
    if (saved != null) {
      items.addAll(saved.items);
      cursor = saved.nextCursor;
      load.value = OwnerLoadData(group(), stale: true);
    }
  }

  OwnerPage<CalendarEntry>? _readSaved() {
    final key = cacheKey;
    if (key == null) return null;
    final raw = OwnerCache.read(userIdOf?.call(), key);
    if (raw == null) return null;
    onFirstPage?.call(raw);
    return OwnerPage.fromJson(raw, CalendarEntry.fromJson);
  }

  Future<void> fetch() async {
    final id = _latest.next();
    if (items.isEmpty) load.value = const OwnerLoadLoading();
    final r = await loader(null);
    final b = blocksLoader;
    final bl = b == null ? const <CalendarBlock>[] : await b();
    if (isClosed || !_latest.isLatest(id)) return;
    if (r is OwnerOk<Map<String, dynamic>>) {
      final page = OwnerPage.fromJson(r.value, CalendarEntry.fromJson);
      items
        ..clear()
        ..addAll(page.items.where((e) => e.valid));
      cursor = page.nextCursor;
      blocks
        ..clear()
        ..addAll(bl);
      onFirstPage?.call(r.value);
      final key = cacheKey;
      if (key != null) OwnerCache.write(userIdOf?.call(), key, r.value);
      load.value = OwnerLoadData(group());
      return;
    }
    final saved = items.isEmpty ? null : List<StayListItem>.of(group());
    load.value = OwnerLoads.from<List<StayListItem>>(_cast(r), saved: saved);
  }

  static OwnerResult<List<StayListItem>> _cast(OwnerResult<dynamic> r) => switch (r) {
        OwnerRefused() => r.cast<List<StayListItem>>(),
        OwnerOffline() => OwnerOffline<List<StayListItem>>(),
        OwnerFailed(:final message) => OwnerFailed<List<StayListItem>>(message: message),
        OwnerOk() => OwnerFailed<List<StayListItem>>(message: ''),
      };

  Future<void> more() async {
    final c = cursor;
    if (c == null || loadingMore.value) return;
    final id = _latest.next();
    loadingMore.value = true;
    final r = await loader(c);
    if (isClosed) return;
    loadingMore.value = false;
    if (!_latest.isLatest(id)) return;
    if (r is OwnerOk<Map<String, dynamic>>) {
      final page = OwnerPage.fromJson(r.value, CalendarEntry.fromJson);
      final merged = OwnerPage.appendNew(items, page.items.where((e) => e.valid).toList(), (e) => e.id);
      items
        ..clear()
        ..addAll(merged);
      cursor = page.nextCursor;
      load.value = OwnerLoadData(group());
    }
  }

  void replace(CalendarEntry e) {
    final i = items.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    items[i] = e;
    load.value = OwnerLoadData(group());
  }

  List<StayListItem> group() {
    final last = items.isEmpty ? null : items.last.dateFrom;
    final usable = blocks.where((b) {
      final f = b.dateFrom;
      if (f == null) return false;
      if (cursor == null || last == null) return true;
      return newestFirst ? !f.isBefore(last) : !f.isAfter(last);
    });
    final rows = <({DateTime date, CalendarEntry? e, CalendarBlock? b})>[
      for (final e in items) if (e.dateFrom != null) (date: e.dateFrom ?? DateTime(2000), e: e, b: null),
      for (final b in usable) (date: b.dateFrom ?? DateTime(2000), e: null, b: b),
    ];
    rows.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return newestFirst ? -c : c;
    });
    final counts = <String, int>{};
    for (final r in rows) {
      final k = OwnerDates.monthKey(r.date);
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final out = <StayListItem>[];
    String? current;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final k = OwnerDates.monthKey(r.date);
      final first = k != current;
      if (first) {
        current = k;
        out.add(StayListHeader(OwnerDates.firstOfMonth(r.date), counts[k] ?? 0));
      }
      final last = i == rows.length - 1 || OwnerDates.monthKey(rows[i + 1].date) != k;
      final e = r.e;
      final b = r.b;
      if (e != null) {
        out.add(StayListEntry(e, first: first, last: last));
      } else if (b != null) {
        out.add(StayListBlock(b, first: first, last: last));
      }
    }
    return out;
  }

  @override
  void onClose() {
    _latest.cancel();
    super.onClose();
  }
}
