import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../models/browse_item.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings_summary.dart';
import '../utils/trip_summary_text.dart';

class TripSummaryStats extends StatelessWidget {
  const TripSummaryStats({super.key, required this.record});

  final TripSummaryRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final rows = r.shownRows;
    final days = r.days.where((d) => d.spots.isNotEmpty).length;
    final spots = TripSummaryText.spotCount(r);
    final items = <(String, String)>[
      if (days > 0) (TripStringsSummary.statDays, '$days'),
      if (spots > 0) (TripStringsSummary.statPlaces, '$spots'),
      if (rows.isNotEmpty)
        (TripStringsSummary.statArranged, TripStringsSummary.arranged(rows.where((a) => a.state.isDone).length, rows.length)),
      if (r.agreedTotal > 0) (TripStringsSummary.statTotal, BrowseItem.inr(r.agreedTotal)),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final perRow = (c.maxWidth >= 400 || items.length <= 3) ? items.length : 2;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final i in items) SizedBox(width: w, child: _tile(i.$1, i.$2))],
        );
      },
    );
  }

  Widget _tile(String label, String value) => DecoratedBox(
        decoration: TripLook.card(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 18, fontWeight: FontWeight.w800, color: TripLook.textDark)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textMedium)),
            ],
          ),
        ),
      );
}
