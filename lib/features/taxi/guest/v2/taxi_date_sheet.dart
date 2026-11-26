import 'package:flutter/material.dart';
import '../../../../design/design.dart';
import 'taxi_journey_date.dart';
import 'taxi_search_strings.dart';

class TaxiDateSheet extends StatefulWidget {
  const TaxiDateSheet({super.key, required this.initial, required this.today});

  final DateTime initial;
  final DateTime today;

  static Future<DateTime?> pick(BuildContext context, {required DateTime initial, DateTime? today}) {
    final t = today ?? TaxiJourneyDate.today();
    return Sheet3D.show<DateTime>(
      context,
      builder: (_) => TaxiDateSheet(initial: TaxiJourneyDate.clamp(initial, t), today: t),
    );
  }

  @override
  State<TaxiDateSheet> createState() => _TaxiDateSheetState();
}

class _TaxiDateSheetState extends State<TaxiDateSheet> {
  late DateTime _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Sheet3D(
      tone: ListingTone.coral,
      title: TaxiSearchStrings.dateSheetTitle,
      subtitle: TaxiSearchStrings.dateSheetBody,
      footer: PrimaryButton(
        label: TaxiSearchStrings.done,
        tone: KitTone.taxi,
        heroCorner: true,
        onPressed: () => Navigator.of(context).pop(_picked),
      ),
      child: TemplateCalendarGrid(
        start: _picked,
        min: widget.today,
        max: TaxiJourneyDate.last(widget.today),
        tone: ListingTone.coral,
        allowJump: false,
        onChange: (s, _) {
          if (s == null) return;
          setState(() => _picked = TaxiJourneyDate.clamp(s, widget.today));
        },
      ),
    );
  }
}
