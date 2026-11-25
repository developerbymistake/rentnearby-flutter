import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';

class NumberTile {
  const NumberTile({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  static const String missing = '-';

  static String of(int? n) => n == null ? missing : '$n';
}

class NumbersRow extends StatelessWidget {
  const NumbersRow({super.key, required this.tiles});

  final List<NumberTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final radius = OwnerLook.cardRadius();
    return DecoratedBox(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: OwnerFacts(facts: tiles),
        ),
      ),
    );
  }
}

class OwnerFacts extends StatelessWidget {
  const OwnerFacts({super.key, required this.facts, this.labelFirst = false, this.padding});

  final List<NumberTile> facts;
  final bool labelFirst;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, indent: DS.gv(10), endIndent: DS.gv(10), color: OwnerLook.greySoft),
              Expanded(child: _Fact(fact: facts[i], labelFirst: labelFirst)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.fact, required this.labelFirst});

  final NumberTile fact;
  final bool labelFirst;

  @override
  Widget build(BuildContext context) {
    final children = labelFirst
        ? [
            Text(fact.label, maxLines: 2, style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.6)),
            Gap.v(2),
            Text(fact.value, maxLines: 2, style: Ink3D.text(12.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ]
        : [
            Text(fact.value, maxLines: 2, style: Ink3D.text(20, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            Text(fact.label, maxLines: 2, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ];
    final body = Padding(
      padding: labelFirst ? DS.sym(h: 10, v: 8) : DS.sym(h: 12, v: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
    );
    if (fact.onTap == null) return body;
    return InkWell(onTap: fact.onTap, child: body);
  }
}
