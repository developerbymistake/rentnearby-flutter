import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings_summary.dart';
import '../utils/trip_summary_text.dart';

class TripSummaryTodo extends StatelessWidget {
  const TripSummaryTodo({super.key, required this.record, required this.onOpen});

  final TripSummaryRecord record;
  final void Function(TripEasyRowKey key) onOpen;

  @override
  Widget build(BuildContext context) {
    if (record.isCompleted) return const SizedBox.shrink();
    final todo = record.stillToDo;
    if (todo.isEmpty) {
      if (record.shownRows.isEmpty) return const SizedBox.shrink();
      return _frame(TripStringsSummary.allDone, TripStringsSummary.allDoneSub, const []);
    }
    return _frame(TripStringsSummary.stillToDo, TripStringsSummary.stillToDoSub, [for (final a in todo) _row(a)]);
  }

  Widget _frame(String title, String subtitle, List<Widget> children) => DecoratedBox(
        decoration: TripLook.card(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 16, fontWeight: FontWeight.w700, color: TripLook.textDark)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textMedium)),
              ),
              ...children,
            ],
          ),
        ),
      );

  Widget _row(TripSummaryArrangement a) => Semantics(
        button: true,
        label: TripStringsSummary.openStep(a.title),
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('todo-${a.key.id}'),
          borderRadius: TripLook.softRadius,
          onTap: () => onOpen(a.key),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: FitnessAppTheme.fontName, fontSize: 13.5, fontWeight: FontWeight.w600, color: TripLook.textDark)),
                        if (a.detailLine != null)
                          Text(a.detailLine!,
                              key: ValueKey('todo-detail-${a.key.id}'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textMedium)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(TripSummaryText.stateWord(a.state),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: TripLook.warningText)),
                ),
                const Icon(Icons.chevron_right, size: 20, color: TripLook.textLight),
              ],
            ),
          ),
        ),
      );
}
