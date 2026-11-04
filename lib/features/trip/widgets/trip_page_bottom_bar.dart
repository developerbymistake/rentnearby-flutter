import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_shadows.dart';
import '../trip_colors.dart';

class TripPageBottomBar extends StatelessWidget {
  const TripPageBottomBar({
    super.key,
    required this.counterText,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    required this.primaryLabel,
    this.onPrimary,
    this.hint,
    this.showPrimary = true,
    this.accent = TripColors.accent,
    this.gradient = TripColors.gradient,
  });

  final String counterText;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? hint;
  final bool showPrimary;
  final Color accent;
  final Gradient gradient;

  static const double _buttonHeight = 48;
  static const double _stackBelow = 340;
  static const double _oneRowFrom = 520;

  Widget _counter() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          counterText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: accent),
        ),
      );

  Widget _secondary() => SizedBox(
        height: _buttonHeight,
        child: OutlinedButton(
          onPressed: onSecondary,
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            backgroundColor: Colors.white,
            side: BorderSide(color: onSecondary == null ? AppColors.divider : accent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 44),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(secondaryIcon, size: 18),
                const SizedBox(width: 6),
                Text(secondaryLabel,
                    maxLines: 1,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );

  Widget _primary() {
    final enabled = onPrimary != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPrimary,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.6,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: _buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: enabled ? gradient : null,
              color: enabled ? null : AppColors.textHint,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled ? AppShadows.premium(accent, alpha: 0.3, blur: 14, offset: const Offset(0, 5)) : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(primaryLabel,
                  maxLines: 1,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint() => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Iconsax.info_circle, size: 16, color: AppColors.warningText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(hint!,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasCounter = counterText.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppShadows.premium(accent, alpha: 0.12, blur: 16, offset: const Offset(0, -4)),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final children = <Widget>[if (hint != null) _hint()];
            if (!showPrimary) {
              if (hasCounter) children.addAll([Align(alignment: Alignment.centerLeft, child: _counter()), const SizedBox(height: 8)]);
              children.add(_secondary());
            } else if (w < _stackBelow) {
              if (hasCounter) children.addAll([Align(alignment: Alignment.centerLeft, child: _counter()), const SizedBox(height: 8)]);
              children.addAll([_secondary(), const SizedBox(height: 8), _primary()]);
            } else if (w < _oneRowFrom) {
              if (hasCounter) children.addAll([Align(alignment: Alignment.centerLeft, child: _counter()), const SizedBox(height: 8)]);
              children.add(Row(children: [
                Expanded(flex: 5, child: _secondary()),
                const SizedBox(width: 10),
                Expanded(flex: 6, child: _primary()),
              ]));
            } else {
              children.add(Row(children: [
                if (hasCounter) ...[Flexible(flex: 4, child: _counter()), const SizedBox(width: 10)],
                Expanded(flex: 5, child: _secondary()),
                const SizedBox(width: 10),
                Expanded(flex: 6, child: _primary()),
              ]));
            }
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
          }),
        ),
      ),
    );
  }
}
