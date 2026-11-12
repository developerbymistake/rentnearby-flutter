import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'trip_status.dart';

class TripStatusCard extends StatelessWidget {
  const TripStatusCard({super.key, required this.status, required this.child, this.onTap});

  final TripDisplayStatus status;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bar = TripStatusVisuals.bar(status);
    return DecoratedBox(
      decoration: TripLook.card(),
      child: ClipRRect(
        borderRadius: TripLook.softRadius,
        child: Material(
          color: DesignColors.surface,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: onTap == null ? Colors.transparent : DesignColors.primary.withValues(alpha: Alpha.v04),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(border: Border(left: BorderSide(color: bar, width: 4))),
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
