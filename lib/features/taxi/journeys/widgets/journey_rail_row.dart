import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';

class JourneyRailRow extends StatelessWidget {
  final Widget marker;
  final Widget child;
  final Color? topColor;
  final Color? bottomColor;

  const JourneyRailRow({super.key, required this.marker, required this.child, this.topColor, this.bottomColor});

  Widget _line(Color? c) => Container(width: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 32,
          child: Column(children: [
            Expanded(child: Center(child: _line(topColor))),
            marker,
            Expanded(child: Center(child: _line(bottomColor))),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ]),
    );
  }
}

class JourneyDot extends StatelessWidget {
  final Color color;

  const JourneyDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: color, spreadRadius: 2)],
      ),
    );
  }
}

class JourneyChangeDot extends StatelessWidget {
  const JourneyChangeDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.warningSurface,
        border: Border.all(color: AppColors.warning, width: 2),
      ),
      child: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.warningText),
    );
  }
}

class JourneyStop extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? tag;

  const JourneyStop({super.key, required this.title, this.subtitle, this.tag});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(999)),
              child: Text(tag!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
            ),
        ]),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
          ),
      ]),
    );
  }
}
