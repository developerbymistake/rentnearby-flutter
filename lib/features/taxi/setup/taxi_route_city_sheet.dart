import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../trip/data/trip_city_catalog.dart';
import '../../trip/models/trip_city_model.dart';
import 'taxi_route_strings.dart';

sealed class TaxiRouteCityChoice {
  const TaxiRouteCityChoice();
}

class TaxiRouteCityPicked extends TaxiRouteCityChoice {
  final TripCityModel city;
  const TaxiRouteCityPicked(this.city);
}

class TaxiRouteOtherPlace extends TaxiRouteCityChoice {
  const TaxiRouteOtherPlace();
}

class TaxiRouteCitySheet extends StatefulWidget {
  final String title;
  final int? selectedKey;
  final TripCityCatalog? catalog;

  const TaxiRouteCitySheet({super.key, required this.title, this.selectedKey, this.catalog});

  static Future<TaxiRouteCityChoice?> pick(BuildContext context, {required String title, int? selectedKey}) =>
      Sheet3D.show<TaxiRouteCityChoice>(
        context,
        builder: (_) => TaxiRouteCitySheet(title: title, selectedKey: selectedKey),
      );

  @override
  State<TaxiRouteCitySheet> createState() => _TaxiRouteCitySheetState();
}

class _TaxiRouteCitySheetState extends State<TaxiRouteCitySheet> {
  static final ListingTone _tone = ListingTone.coral;
  final _searchCtrl = TextEditingController();
  late final TripCityCatalog _catalog = widget.catalog ?? TripCityCatalog.to;
  List<TripCityModel> _items = const [];
  String _query = '';
  bool _loading = false;
  bool _failed = false;
  double? _baseHeight;
  double? _baseTopPadding;

  @override
  void initState() {
    super.initState();
    _catalog.warmFromDisk();
    _items = _catalog.search('');
    _loading = _items.isEmpty;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _baseHeight ??= media.size.height;
    _baseTopPadding ??= media.padding.top;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _catalog.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = false;
        _items = _catalog.search(_query);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = _catalog.search(_query);
        _failed = _items.isEmpty;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  void _onSearch(String v) => setState(() {
        _query = v;
        _items = _catalog.search(v);
      });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final baseHeight = _baseHeight ?? media.size.height;
    final baseTopPadding = _baseTopPadding ?? media.padding.top;
    final maxHeight = (baseHeight - baseTopPadding) * 0.94;
    final sheetHeight = math.max(baseHeight * 0.75, DS.s(634)).clamp(0.0, maxHeight);
    return SizedBox(
      height: sheetHeight + Sheet3D.artRoom,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Sheet3D(
          tone: _tone,
          art: ListingArt.taxi,
          centerTitle: false,
          scrollable: false,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetListHeader(
                tone: _tone,
                title: widget.title,
                subtitle: TaxiRouteStrings.sheetSub,
                action: TaxiRouteStrings.otherPlace,
                onAction: () => Navigator.pop(context, const TaxiRouteOtherPlace()),
              ),
              SheetSearchField(
                tone: _tone,
                controller: _searchCtrl,
                hint: TaxiRouteStrings.searchCity,
                leadingArt: ListingArt.search,
                inputFormatters: noEmojiInputFormatters,
                onChanged: _onSearch,
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_items.isEmpty) {
      if (_loading) return sheetSkeleton(twoLines: true);
      if (_failed) return sheetStateView(_tone, TaxiRouteStrings.citiesFailed, onRetry: _retry);
      return sheetStateView(_tone, _query.trim().isEmpty ? TaxiRouteStrings.noCities : TaxiRouteStrings.noCityMatch(_query.trim()));
    }
    return ListView.builder(
      padding: DS.insets(t: 4, b: 8),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final c = _items[i];
        final line = c.placeLine;
        return SheetListRow(
          key: ValueKey('route_city_${c.cityKey}'),
          tone: _tone,
          title: c.name,
          subtitle: line.isEmpty ? null : line,
          art: ListingArt.roundPushpin,
          selected: c.cityKey == widget.selectedKey,
          divider: i > 0,
          onTap: () => Navigator.pop(context, TaxiRouteCityPicked(c)),
        );
      },
    );
  }
}
