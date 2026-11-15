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

  static double get _buttonHeight => DS.s(48);
  static const double _stackBelow = 340;
  static const double _oneRowFrom = 520;

  Widget _counter() => Container(
        padding: DS.sym(h: 12, v: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: Alpha.v10),
          borderRadius: DS.circular(16),
        ),
        child: Text(
          counterText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(12), fontWeight: FontWeight.w700, color: accent),
        ),
      );

  Widget _secondary() => _TripPress(
        enabled: onSecondary != null,
        child: Material(
          color: DesignColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: DS.circular(16),
            side: BorderSide(color: onSecondary == null ? TripEntryStyle.border : accent, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSecondary,
            highlightColor: Colors.transparent,
            child: Container(
              height: _buttonHeight,
              padding: DS.sym(h: 12),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(secondaryIcon, size: DS.s(18), color: onSecondary == null ? DesignColors.textMuted : accent),
                    Gap.h(6),
                    Text(secondaryLabel,
                        maxLines: 1,
                        style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontSize: DS.f(13),
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
            padding: DS.sym(h: 12),
            decoration: BoxDecoration(
              gradient: enabled ? gradient : null,
              color: enabled ? null : DesignColors.textMuted,
              borderRadius: DS.circular(16),
              boxShadow: enabled ? DS.shadows(TripEntryStyle.skyShadow) : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(primaryLabel,
                  maxLines: 1,
                  style: TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(14), fontWeight: FontWeight.w700, color: DesignColors.surface)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint() => Container(
        margin: EdgeInsets.only(bottom: DS.gv(8)),
        padding: DS.sym(h: 12, v: 8),
        decoration: BoxDecoration(color: TripEntryStyle.sunriseTint, borderRadius: DS.circular(16)),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: DS.s(16), color: DesignColors.textGreyDark),
            Gap.h(8),
            Expanded(
              child: Text(hint!,
                  style: TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(12), fontWeight: FontWeight.w600, color: DesignColors.textGreyDark)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasCounter = counterText.isNotEmpty;
    return TemplateEntranceOnce(
      child: Container(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(10), DS.s(16), AppInsets.bottomViewPadding(context) + DS.s(10)),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        boxShadow: DS.shadows(TripEntryStyle.topShadow),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final children = <Widget>[if (hint != null) _hint()];
            if (!showPrimary) {
              if (hasCounter) children.addAll([Align(alignment: Alignment.centerLeft, child: _counter()), Gap.v(8)]);
              children.add(_secondary());
            } else if (w < _stackBelow) {
              if (hasCounter) children.addAll([Align(alignment: Alignment.centerLeft, child: _counter()), Gap.v(8)]);
              children.addAll([_secondary(), Gap.v(8), _primary()]);
            } else if (w < _oneRowFrom) {
              if (hasCounter) children.addAll([Align(alignment: Alignment.centerLeft, child: _counter()), Gap.v(8)]);
              children.add(Row(children: [
                Expanded(flex: 5, child: _secondary()),
                Gap.h(10),
                Expanded(flex: 6, child: _primary()),
              ]));
            } else {
              children.add(Row(children: [
                if (hasCounter) ...[Flexible(flex: 4, child: _counter()), Gap.h(10)],
                Expanded(flex: 5, child: _secondary()),
                Gap.h(10),
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
