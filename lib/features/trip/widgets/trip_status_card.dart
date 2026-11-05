import 'package:flutter/material.dart';
import '../../../config/app_shadows.dart';
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.premium(bar, alpha: 0.10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
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
