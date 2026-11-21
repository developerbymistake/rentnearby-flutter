import 'package:flutter/material.dart';

import '../../../design/design.dart';

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) Gap.h(10),
          Expanded(child: _Tile(tile: tiles[i])),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile});

  final NumberTile tile;

  @override
  Widget build(BuildContext context) {
    final radius = DS.br(CardRadius.hero);
    return Material(
      color: DesignColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: tile.onTap,
        child: Padding(
          padding: DS.sym(h: 12, v: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(tile.value, maxLines: 1, style: Ink3D.text(20, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              ),
              Text(tile.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
            ],
          ),
        ),
      ),
    );
  }
}
