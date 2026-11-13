import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'trip_status.dart';

class TripStatusCard extends StatelessWidget {
  const TripStatusCard({super.key, required this.status, required this.child, this.onTap});

  final TripDisplayStatus status;
  final Widget child;
  final VoidCallback? onTap;

  static const BorderRadius _radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(32), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final tone = TripStatusVisuals.tone3d(status);
    Widget card = DecoratedBox(
      decoration: const BoxDecoration(color: DesignColors.surface, borderRadius: _radius, boxShadow: Form3D.cardShadow),
      child: ClipRRect(
        borderRadius: _radius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: tone.gradient), child: const SizedBox(width: 5)),
              Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 16, 14), child: child)),
            ],
          ),
        ),
      ),
    );
    if (onTap != null) card = Tap3D(onTap: onTap, child: card);
    return card;
  }
}
