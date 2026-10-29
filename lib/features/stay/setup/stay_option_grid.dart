import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import 'stay_option_sets.dart';

class StayOptionGrid extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final List<String> labels;
  final bool Function(int) isActive;
  final void Function(int) onTap;

  const StayOptionGrid({
    super.key,
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.labels,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: active ? StayColors.accent : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? StayColors.accent : AppColors.divider, width: 1.5),
            ),
            child: Center(
              child: Text(labels[i],
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textMedium)),
            ),
          ),
        );
      },
    );
  }
}
