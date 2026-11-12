import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../config/app_insets.dart';

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
    this.accent = TripEntryStyle.accent,
    this.gradient = TripEntryStyle.gradient,
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
          color: accent.withValues(alpha: Alpha.v10),
          borderRadius: const BorderRadius.all(Radius.circular(16.0)),
        ),
        child: Text(
          counterText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w700, color: accent),
        ),
      );

  Widget _secondary() => _TripPress(
        enabled: onSecondary != null,
        child: Material(
          color: DesignColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
            side: BorderSide(color: onSecondary == null ? TripEntryStyle.border : accent, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSecondary,
            highlightColor: Colors.transparent,
            child: Container(
              height: _buttonHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(secondaryIcon, size: 18, color: onSecondary == null ? DesignColors.textMuted : accent),
                    const SizedBox(width: 6),
                    Text(secondaryLabel,
                        maxLines: 1,
                        style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: onSecondary == null ? DesignColors.textMuted : accent)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _primary() {
    final enabled = onPrimary != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: _TripPress(
        enabled: enabled,
        child: GestureDetector(
        onTap: onPrimary,
        child: Container(
            height: _buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: enabled ? gradient : null,
              color: enabled ? null : DesignColors.textMuted,
              borderRadius: const BorderRadius.all(Radius.circular(16.0)),
              boxShadow: enabled ? TripEntryStyle.skyShadow : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(primaryLabel,
                  maxLines: 1,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: DesignColors.surface)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint() => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: TripEntryStyle.sunriseTint, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: DesignColors.textGreyDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(hint!,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: DesignColors.textGreyDark)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasCounter = counterText.isNotEmpty;
    return TemplateEntranceOnce(
      child: Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        boxShadow: TripEntryStyle.topShadow,
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
    ),
    );
  }
}

class _TripPress extends StatefulWidget {
  const _TripPress({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_TripPress> createState() => _TripPressState();
}

class _TripPressState extends State<_TripPress> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(duration: const Duration(milliseconds: 400), vsync: this, value: 1.0);
  late final Animation<double> _scale = Tween<double>(begin: 0.88, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (widget.enabled) _c.forward(from: 0);
      },
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
