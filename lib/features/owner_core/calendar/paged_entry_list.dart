import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../data/owner_page.dart';
import '../data/owner_result.dart';
import '../data/single_flight.dart';
import '../strings/owner_shared_strings.dart';
import 'models/calendar_models.dart';

class PagedEntryList extends StatefulWidget {
  const PagedEntryList({
    super.key,
    required this.load,
    required this.row,
    required this.empty,
    required this.errorText,
    this.header,
    this.firstPage,
  });

  final Future<OwnerResult<OwnerPage<CalendarEntry>>> Function(String? cursor) load;
  final Widget Function(BuildContext context, CalendarEntry entry) row;
  final Widget empty;
  final String errorText;
  final Widget? header;
  final OwnerPage<CalendarEntry>? firstPage;

  @override
  State<PagedEntryList> createState() => _PagedEntryListState();
}

class _PagedEntryListState extends State<PagedEntryList> {
  final List<CalendarEntry> _items = [];
  final LatestOnly _latest = LatestOnly();
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final first = widget.firstPage;
    if (first != null) {
      _items.addAll(first.items);
      _cursor = first.nextCursor;
      _loading = false;
    }
    _refresh();
  }

  @override
  void dispose() {
    _latest.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
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
      } else {
        _failed = true;
      }
    });
  }

  Future<void> _loadMore() async {
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
        _failed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final count = _items.length;
    final extra = (header != null ? 1 : 0) + 1;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DS.sym(h: 18, v: 12),
        itemCount: count + extra,
        itemBuilder: (context, i) {
          if (header != null && i == 0) return header;
          final index = header != null ? i - 1 : i;
          if (index < count) {
            return Padding(padding: EdgeInsets.only(bottom: DS.gv(10)), child: widget.row(context, _items[index]));
          }
          return _footer();
        },
      ),
    );
  }

  Widget _footer() {
    if (_loading) return Padding(padding: DS.all(24), child: const Center(child: CircularProgressIndicator()));
    if (_failed && _items.isEmpty) {
      return StateCard.error(title: widget.errorText, actionLabel: OwnerSharedStrings.tryAgain, onAction: _refresh);
    }
    if (_items.isEmpty) return widget.empty;
    if (_cursor == null) return Gap.v(24);
    return Padding(
      padding: DS.sym(v: 8),
      child: Center(
        child: _more
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: _loadMore,
                child: Text(OwnerSharedStrings.showMore, style: Ink3D.text(14, FontWeight.w600, DesignColors.primary)),
              ),
      ),
    );
  }
}
