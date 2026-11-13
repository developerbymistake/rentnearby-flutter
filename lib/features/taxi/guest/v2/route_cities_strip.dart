import 'package:flutter/material.dart';
import '../../../../design/design.dart';
import '../../../trip/widgets/trip_city_sheet.dart';
import '../../ways/models/taxi_ways_models.dart';
import '../../ways/taxi_ways_repository.dart';

class RouteCityRow {
  final String name;
  final int? cityKey;
  final int? drivers;

  const RouteCityRow({required this.name, this.cityKey, this.drivers});

  RouteCityRow withDrivers(int? n) => RouteCityRow(name: name, cityKey: cityKey, drivers: n);

  String get supplyText => drivers == null
      ? ''
      : drivers == 0
          ? 'No taxi listed yet'
          : drivers == 1
              ? '1 taxi listed'
              : '$drivers taxis listed';
}

abstract final class RouteCities {
  static const maxCities = 8;

  // Stop keys of Atlas cities look like a123.
  static int? cityKeyOf(String key) {
    if (key.length < 2 || key[0] != 'a') return null;
    return int.tryParse(key.substring(1));
  }

  static List<RouteCityRow> fromResult(TaxiWaysResult r) {
    final seen = <String>{};
    final out = <RouteCityRow>[];
    for (final plan in r.plans) {
      for (final leg in plan.legs) {
        for (final s in leg.passStops) {
          if (out.length >= maxCities) return out;
          final id = s.key.isNotEmpty ? s.key : s.name.toLowerCase();
          if (seen.add(id)) out.add(RouteCityRow(name: s.name, cityKey: cityKeyOf(s.key)));
        }
      }
      if (out.isNotEmpty) break;
    }
    return out;
  }
}

class RouteCitiesStrip extends StatefulWidget {
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final String? fromName;
  final String? toName;

  const RouteCitiesStrip({
    super.key,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    this.fromName,
    this.toName,
  });

  @override
  State<RouteCitiesStrip> createState() => _RouteCitiesStripState();
}

class _RouteCitiesStripState extends State<RouteCitiesStrip> {
  static final _cache = <String, List<RouteCityRow>>{};
  List<RouteCityRow> _rows = const [];

  String get _key => '${widget.fromLat.toStringAsFixed(3)},${widget.fromLng.toStringAsFixed(3)}'
      '|${widget.toLat.toStringAsFixed(3)},${widget.toLng.toStringAsFixed(3)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RouteCitiesStrip old) {
    super.didUpdateWidget(old);
    final same = old.fromLat == widget.fromLat &&
        old.fromLng == widget.fromLng &&
        old.toLat == widget.toLat &&
        old.toLng == widget.toLng;
    if (!same) {
      setState(() => _rows = const []);
      _load();
    }
  }

  Future<void> _load() async {
    final key = _key;
    final hit = _cache[key];
    if (hit != null) {
      _rows = hit;
      return;
    }
    try {
      final res = await const TaxiWaysRepository().ways(
        fromLat: widget.fromLat,
        fromLng: widget.fromLng,
        toLat: widget.toLat,
        toLng: widget.toLng,
        date: DateTime.now(),
        people: 1,
        fromName: widget.fromName,
        toName: widget.toName,
      );
      var rows = RouteCities.fromResult(res);
      if (!mounted || key != _key) return;
      setState(() => _rows = rows);
      rows = await Future.wait([
        for (final r in rows) _supply(r),
      ]);
      _cache[key] = rows;
      if (!mounted || key != _key) return;
      setState(() => _rows = rows);
    } catch (_) {
      // Silent: the strip is only a bonus.
    }
  }

  Future<RouteCityRow> _supply(RouteCityRow r) async {
    final k = r.cityKey;
    if (k == null) return r;
    try {
      return r.withDrivers((await TripCitySupplyCache.load(k)).drivers);
    } catch (_) {
      return r;
    }
  }

  @override
  Widget build(BuildContext context) => RouteCitiesStripView(rows: _rows);
}

class RouteCitiesStripView extends StatelessWidget {
  final List<RouteCityRow> rows;
  const RouteCitiesStripView({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: WhiteCard3D(
        padding: const EdgeInsets.fromLTRB(20, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cities on the way', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w600, Ink3D.title)),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Art3D(asset: ListingArt.roundPushpin, size: 20, shadowBlur: 2, shadowOffset: Offset(1, 2), shadowAlpha: 0.3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: r.name,
                          style: Ink3D.text(14, FontWeight.w600, Ink3D.body),
                          children: [
                            if (r.supplyText.isNotEmpty) TextSpan(text: '. ${r.supplyText}', style: Ink3D.text(13, FontWeight.w400, Ink3D.grey)),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
