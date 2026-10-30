import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class PlanAccent {
  const PlanAccent._();

  static Color of(String? featureKey) => switch (featureKey) {
        'Plot' => AppColors.plot,
        'Stay' => AppColors.stay,
        'Taxi' => AppColors.taxi,
        _ => AppColors.primary,
      };

  static LinearGradient gradientOf(String? featureKey) => switch (featureKey) {
        'Plot' => AppColors.plotGradient,
        'Stay' => AppColors.stayGradient,
        'Taxi' => AppColors.taxiGradient,
        _ => AppColors.primaryGradient,
      };
}

enum CompareCellKind { number, yes, no }

class CompareCell {
  final String text;
  final CompareCellKind kind;

  const CompareCell(this.text, this.kind);
  const CompareCell.number(int value)
      : text = '$value',
        kind = CompareCellKind.number;
  const CompareCell.flag(bool value)
      : text = '',
        kind = value ? CompareCellKind.yes : CompareCellKind.no;
}

class CompareRow {
  final String label;
  final List<CompareCell> cells;

  const CompareRow(this.label, this.cells);
}

class PlanCompareTable extends StatelessWidget {
  final List<CompareRow> rows;
  final List<String> paidNames;
  final Color accent;

  const PlanCompareTable({super.key, required this.rows, required this.paidNames, required this.accent});

  bool get _showBest => paidNames.length == 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            const Expanded(flex: 5, child: SizedBox()),
            const Expanded(
              flex: 3,
              child: Center(
                child: Text('Free',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMedium)),
              ),
            ),
            for (final name in paidNames)
              Expanded(
                flex: 4,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: accent)),
                  if (_showBest)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                      child: const Text('BEST',
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                ]),
              ),
          ]),
        ),
        for (final row in rows) ...[
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Text(row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
              ),
              for (var i = 0; i < row.cells.length; i++)
                Expanded(flex: i == 0 ? 3 : 4, child: Center(child: _cell(row.cells[i], paid: i > 0))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _cell(CompareCell c, {required bool paid}) => switch (c.kind) {
        CompareCellKind.yes => const Icon(Icons.check_rounded, size: 16, color: AppColors.successDark),
        CompareCellKind.no => const Text('−',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textHint)),
        CompareCellKind.number => Text(c.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: paid ? accent : AppColors.textMedium)),
      };
}
