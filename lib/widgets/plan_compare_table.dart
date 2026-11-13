import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';

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
        'Stay' => '${_dir}house_with_garden.png',
        'Taxi' => '${_dir}taxi.png',
        _ => '${_dir}briefcase.png',
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
  final String? featureKey;

  const PlanCompareTable({super.key, required this.rows, required this.paidNames, required this.accent, this.featureKey});

  bool get _showBest => paidNames.length == 1;

  String? get _key {
    if (featureKey != null) return featureKey;
    if (accent == PlanAccent.of('Stay')) return 'Stay';
    if (accent == PlanAccent.of('Taxi')) return 'Taxi';
    return null;
  }

  static String artFor(String label) => switch (label) {
        'Shown first' => ListingArt.compass,
        'Featured badge' => ListingArt.star,
        _ => ListingArt.clipboard,
      };

  static PlanCellData _cell(CompareCell c) => PlanCellData(c.text, switch (c.kind) {
        CompareCellKind.number => PlanCellKind.number,
        CompareCellKind.yes => PlanCellKind.yes,
        CompareCellKind.no => PlanCellKind.no,
      });

  @override
  Widget build(BuildContext context) {
    return PlanCompareCard3D(
      tone: PlanLook.toneOf(_key),
      paidNames: paidNames,
      showBest: _showBest,
      rows: [
        for (final r in rows) PlanRowData(label: r.label, art: artFor(r.label), cells: [for (final c in r.cells) _cell(c)]),
      ],
    );
  }
}
