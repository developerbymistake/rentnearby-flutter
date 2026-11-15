import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'trip_status.dart';

class TripStatusCard extends StatelessWidget {
  const TripStatusCard({super.key, required this.status, required this.child, this.onTap});

  final TripDisplayStatus status;
  final Widget child;
  final VoidCallback? onTap;

  static BorderRadius get _radius => DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(32), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  @override
  Widget build(BuildContext context) {
    final tone = TripStatusVisuals.tone3d(status);
    Widget card = DecoratedBox(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: _radius, boxShadow: DS.shadows(Form3D.cardShadow)),
      child: ClipRRect(
        borderRadius: _radius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: tone.gradient), child: SizedBox(width: DS.s(5))),
              Expanded(child: Padding(padding: DS.insets(l: 14, t: 14, r: 16, b: 14), child: child)),
            ],
          ),
        ),
      ),
    );
    if (onTap != null) card = Tap3D(onTap: onTap, child: card);
    return card;
  }
}
