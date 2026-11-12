import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';

class PlanAccent {
  const PlanAccent._();

  static const String _dir = 'assets/images/design/travel3d/';

  static Color startOf(String? featureKey) => switch (featureKey) {
        'Stay' => DesignColors.sunriseDeep,
        'Taxi' => DesignColors.roseDeepStart,
        _ => DesignColors.skyDeepStart,
      };

  static Color endOf(String? featureKey) => switch (featureKey) {
        'Stay' => DesignColors.sunriseDeepEnd,
        'Taxi' => DesignColors.roseDeep,
        _ => DesignColors.lunchEnd,
      };

  static Color of(String? featureKey) => endOf(featureKey);

  static LinearGradient gradientOf(String? featureKey) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [startOf(featureKey), endOf(featureKey)],
      );

  static KitTone toneOf(String? featureKey) => KitTone(
        accent: startOf(featureKey),
        accentDark: endOf(featureKey),
        tint: DesignColors.tint(endOf(featureKey), Alpha.tint),
        gradient: gradientOf(featureKey),
        glow: endOf(featureKey),
      );

  static String iconAsset(String? featureKey) => switch (featureKey) {
        'Stay' => '${_dir}hotel.png',
        'Taxi' => '${_dir}taxi.png',
        _ => '${_dir}backpack.png',
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

  static final TextStyle _head = TypeTokens.style(12, FontWeight.w600, letterSpacing: 0.2);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.elev2,
      ),
      child: Column(children: [
        Container(
          color: DesignColors.scaffold,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            const Expanded(flex: 5, child: SizedBox()),
            Expanded(
              flex: 3,
              child: Center(
                child: Text('Free',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _head.copyWith(color: DesignColors.textGrey)),
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
                      style: _head.copyWith(fontWeight: FontWeight.w700, color: accent)),
                  if (_showBest)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: accent, borderRadius: CardRadius.pill),
                      child: Text('BEST',
                          style: TypeTokens.style(10, FontWeight.w700, color: DesignColors.surface, chip: true)),
                    ),
                ]),
              ),
          ]),
        ),
        for (final row in rows) ...[
          const Divider(height: 1, thickness: 1, color: DesignColors.dividerSoft),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Text(row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(14, FontWeight.w500,
                        color: DesignColors.textStrong, letterSpacing: 0.2)),
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
        CompareCellKind.yes => const Icon(Icons.check_rounded, size: 16, color: DesignColors.goodDeep),
        CompareCellKind.no => Text('−',
            style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textMuted)),
        CompareCellKind.number => Text(c.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeTokens.style(14, FontWeight.w700,
                color: paid ? accent : DesignColors.textGrey)),
      };
}
