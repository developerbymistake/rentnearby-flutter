import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// One option in a [SlidingChipToggle] — label/icon plus the gradient the
/// sliding pill takes on when this option is selected.
class ToggleOption {
  final String label;
  final IconData icon;
  final Color activeColor;
  final Gradient gradient;

  const ToggleOption({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.gradient,
  });
}

/// A single rounded track holding exactly 2 options, with a gradient pill
/// that physically slides between them (AnimatedAlign) rather than two
/// independent chips swapping color — the "chip jaisa slide feel" toggle
/// design, shared by Home's hero toggle and ViewAllScreen's Rooms/Plots
/// toggle so both get identical behaviour.
class SlidingChipToggle extends StatelessWidget {
  final List<ToggleOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SlidingChipToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(options.length == 2);

  @override
  Widget build(BuildContext context) {
    final selected = options[selectedIndex];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final pillWidth = (constraints.maxWidth - 0) / 2;
              return AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: selectedIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: selected.gradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: selected.activeColor.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 5)),
                    ],
                  ),
                ),
              );
            },
          ),
          Row(
            children: List.generate(options.length, (i) {
              final opt = options[i];
              final isSelected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(opt.icon, size: 15, color: isSelected ? Colors.white : AppColors.textHint),
                        const SizedBox(width: 6),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
