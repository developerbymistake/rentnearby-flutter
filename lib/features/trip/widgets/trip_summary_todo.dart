import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings_summary.dart';
import '../utils/trip_summary_text.dart';

class TripSummaryTodo extends StatelessWidget {
  const TripSummaryTodo({super.key, required this.record, required this.onOpen});

  final TripSummaryRecord record;
  final void Function(TripEasyRowKey key) onOpen;

  static ListingTone toneOf(TripEasyRowKind k) => switch (k) {
        TripEasyRowKind.stay => ListingTone.forest,
        TripEasyRowKind.taxi || TripEasyRowKind.gettingThere || TripEasyRowKind.between || TripEasyRowKind.comingBack => ListingTone.coral,
      };

  static String artOf(TripEasyRowKind k) => switch (k) {
        TripEasyRowKind.stay => ListingArt.hotel,
        TripEasyRowKind.taxi || TripEasyRowKind.gettingThere => ListingArt.taxi,
        TripEasyRowKind.between => ListingArt.compass,
        TripEasyRowKind.comingBack => ListingArt.airplane,
      };

  @override
  Widget build(BuildContext context) {
    if (record.isCompleted) return const SizedBox.shrink();
    final todo = record.stillToDo;
    if (todo.isEmpty) {
      if (record.shownRows.isEmpty) return const SizedBox.shrink();
      return TitleRow3D(title: TripStringsSummary.allDone, subtitle: TripStringsSummary.allDoneSub, tone: ListingTone.indigo);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TitleRow3D(title: TripStringsSummary.stillToDo, subtitle: TripStringsSummary.stillToDoSub, tone: ListingTone.indigo),
        for (final a in todo) _row(a),
      ],
    );
  }

  Widget _row(TripSummaryArrangement a) => KeyedSubtree(
        key: ValueKey('todo-${a.key.id}'),
        child: WideCard(
          kind: WideKind.slim,
          tone: toneOf(a.key.kind),
          art: artOf(a.key.kind),
          title: a.title,
          subtitle: a.detailLine ?? '',
          badge: TripSummaryText.stateWord(a.state),
          reserveChips: false,
          showPrice: false,
          semanticsLabel: TripStringsSummary.openStep(a.title),
          onTap: () => onOpen(a.key),
        ),
      );
}
