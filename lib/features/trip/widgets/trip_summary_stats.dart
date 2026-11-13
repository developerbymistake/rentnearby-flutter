import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../models/browse_item.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings_summary.dart';
import '../utils/trip_summary_text.dart';

class TripSummaryStats extends StatelessWidget {
  const TripSummaryStats({super.key, required this.record});

  final TripSummaryRecord record;

  static const String _arrangedSub = 'Stay, taxi\nand ways';
  static const String _totalSub = 'Stays and taxis\nso far';

  static String _cities(TripSummaryRecord r) {
    final counts = <String, int>{};
    for (final d in r.days) {
      final c = d.city;
      if (c == null || c.isEmpty || d.spots.isEmpty) continue;
      counts[c] = (counts[c] ?? 0) + d.spots.length;
    }
    if (counts.length < 2) return '';
    return counts.entries.take(2).map((e) => '${e.key} ${e.value}').join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    final rows = r.shownRows;
    final days = r.days.where((d) => d.spots.isNotEmpty).length;
    final spots = TripSummaryText.spotCount(r);
    final dates = TripSummaryText.datesOf(r);
    final items = <(String, String, String, String, String)>[
      if (days > 0) (TripStringsSummary.statDays, dates, '$days', days == 1 ? 'day' : 'days', ListingArt.calendar),
      if (spots > 0) (TripStringsSummary.statPlaces, _cities(r), '$spots', spots == 1 ? 'place' : 'places', ListingArt.roundPushpin),
      if (rows.isNotEmpty)
        (TripStringsSummary.statArranged, _arrangedSub, '${rows.where((a) => a.state.isDone).length}', 'of ${rows.length}', ListingArt.star),
      if (r.agreedTotal > 0) (TripStringsSummary.statTotal, _totalSub, BrowseItem.inr(r.agreedTotal), '', ListingArt.moneyBag),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return MealsGrid(
      count: items.length,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      cardBuilder: (context, i, width) {
        final it = items[i];
        return MealsCardV(
          tone: ListingTone.indigo,
          title: it.$1,
          description: it.$2,
          number: it.$3,
          unit: it.$4,
          art: it.$5,
          width: width,
          semanticsLabel: '${it.$1}, ${it.$3} ${it.$4}',
        );
      },
    );
  }
}
