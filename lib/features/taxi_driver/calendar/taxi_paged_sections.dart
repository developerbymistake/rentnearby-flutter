import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_page.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import 'models/taxi_calendar_models.dart';
import 'taxi_calendar_widgets.dart';

typedef TaxiPageLoader = Future<OwnerResult<OwnerPage<CalendarEntry>>> Function(String? cursor);

class TaxiPagedSections extends StatefulWidget {
  const TaxiPagedSections({
    super.key,
    required this.load,
    required this.row,
    required this.sectionLabel,
    this.footer,
    this.byLastDay = false,
  });

  final TaxiPageLoader load;
  final Widget Function(BuildContext context, CalendarEntry e) row;
  final String Function(DateTime month) sectionLabel;
  final List<Widget> Function(BuildContext context, bool hasMore)? footer;
  final bool byLastDay;

  @override
  State<TaxiPagedSections> createState() => TaxiPagedSectionsState();
}

sealed class _Item {
  const _Item();
}

class _Label extends _Item {
  const _Label(this.month, this.count);
  final DateTime month;
  final int count;
}

class _Row extends _Item {
  const _Row(this.entry, this.first, this.last);
  final CalendarEntry entry;
  final bool first;
  final bool last;
}

class TaxiPagedSectionsState extends State<TaxiPagedSections> {
  final List<CalendarEntry> _items = [];
  final LatestOnly _latest = LatestOnly();
  List<_Item> _flat = const [];
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  bool _failed = false;
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _latest.cancel();
    super.dispose();
  }

  void _rebuild() {
    final out = <_Item>[];
    for (final s in TaxiSections.byMonth(_items, byLastDay: widget.byLastDay)) {
      out.add(_Label(s.month, s.rows.length));
      for (var i = 0; i < s.rows.length; i++) {
        out.add(_Row(s.rows[i], i == 0, i == s.rows.length - 1));
      }
    }
    _flat = out;
  }

  Future<void> refresh() async {
    final id = _latest.next();
    setState(() {
      _failed = false;
      if (_items.isEmpty) _loading = true;
    });
    final r = await widget.load(null);
    if (!mounted || !_latest.isLatest(id)) return;
    setState(() {
      _loading = false;
      if (r is OwnerOk<OwnerPage<CalendarEntry>>) {
        _items
          ..clear()
          ..addAll(r.value.items);
        _cursor = r.value.nextCursor;
        _stale = false;
      } else {
        _failed = true;
        _stale = _items.isNotEmpty;
      }
      _rebuild();
    });
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _more) return;
    final id = _latest.next();
    setState(() => _more = true);
    final r = await widget.load(cursor);
    if (!mounted || !_latest.isLatest(id)) return;
    setState(() {
      _more = false;
      if (r is OwnerOk<OwnerPage<CalendarEntry>>) {
        final merged = OwnerPage.appendNew(_items, r.value.items, (e) => e.id);
        _items
          ..clear()
          ..addAll(merged);
        _cursor = r.value.nextCursor;
      } else {
        _stale = true;
      }
      _rebuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    final head = <Widget>[if (_stale) const OwnerStaleLine()];
    final tail = <Widget>[];
    if (_loading) {
      tail.add(const OwnerSkeletonList());
    } else if (_failed && _items.isEmpty) {
      tail.add(StateCard.error(title: OwnerSharedStrings.couldNotLoad, kit: TaxiCal.kit, actionLabel: OwnerSharedStrings.tryAgain, onAction: refresh));
    } else {
      if (_cursor != null) {
        tail.add(Padding(
          padding: DS.sym(v: 4),
          child: _more
              ? const Center(child: CircularProgressIndicator())
              : SecondaryButton(label: OwnerSharedStrings.showMore, tone: TaxiCal.kit, onPressed: loadMore),
        ));
      }
      tail.addAll(widget.footer?.call(context, _cursor != null) ?? const []);
    }
    final count = head.length + _flat.length + tail.length;
    return RefreshIndicator(
      color: TaxiCal.accent,
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DS.insets(l: 16, t: 12, r: 16, b: 24),
        itemCount: count,
        itemBuilder: (context, i) {
          if (i < head.length) return head[i];
          final j = i - head.length;
          if (j < _flat.length) {
            return switch (_flat[j]) {
              _Label(:final month, :final count) => TaxiSectionLabel(text: widget.sectionLabel(month), count: count),
              _Row(:final entry, :final first, :final last) => TaxiCardSegment(first: first, last: last, child: widget.row(context, entry)),
            };
          }
          return tail[j - _flat.length];
        },
      ),
    );
  }
}
