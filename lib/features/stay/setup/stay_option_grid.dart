import 'package:flutter/material.dart';
import '../../../design/design.dart';

class StayOptionGrid extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final List<String> labels;
  final bool Function(int) isActive;
  final void Function(int) onTap;
  final Color accent;

  const StayOptionGrid({
    super.key,
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.labels,
    required this.isActive,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(24));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: labels.length,
      itemBuilder: (_, i) {
        final active = isActive(i);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? accent : DesignColors.surface,
            borderRadius: radius,
            border: Border.all(color: active ? accent : DesignColors.dividerSoft, width: 1.5),
            boxShadow: active ? ShadowTokens.elev3 : ShadowTokens.elev1,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: () => onTap(i),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(labels[i],
                        maxLines: 1,
                        softWrap: false,
                        style: TripKit.text(12,
                                weight: FontWeight.w600,
                                color: active ? DesignColors.surface : DesignColors.textStrong)
                            .copyWith(letterSpacing: 0.2)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
