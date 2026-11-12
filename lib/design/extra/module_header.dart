import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'template_motion.dart';

class ModuleHeader extends StatelessWidget {
  const ModuleHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.tone = KitTone.brand,
    this.gradient,
    this.onBack,
    this.trailing = const [],
    this.leadingAsset,
    this.bottom,
    this.bottomHeight = 0,
    this.subtitleLines = 1,
    this.tabRoot = false,
    this.animate = true,
    this.leading,
    this.subtitleWidget,
    this.autoHeight = false,
  });

  final Widget? leading;
  final Widget? subtitleWidget;
  final bool autoHeight;

  final String title;
  final String? subtitle;
  final KitTone tone;
  final Gradient? gradient;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final String? leadingAsset;
  final Widget? bottom;
  final double bottomHeight;
  final int subtitleLines;
  final bool tabRoot;
  final bool animate;

  static const double toolbarHeight = 56;
  static const double subtitleHeight = 20;
  static const double paddingTop = 8;
  static const double paddingBottom = 16;
  static const double contentGap = 16;
  static const SystemUiOverlayStyle lightIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static double heightOf(BuildContext context,
          {bool hasSubtitle = false, double bottomHeight = 0, int subtitleLines = 1}) =>
      MediaQuery.paddingOf(context).top +
      paddingTop +
      toolbarHeight +
      (hasSubtitle ? subtitleHeight * subtitleLines : 0) +
      bottomHeight +
      paddingBottom;

  static double contentTop(BuildContext context,
          {bool hasSubtitle = false, double bottomHeight = 0, int subtitleLines = 1}) =>
      heightOf(context,
          hasSubtitle: hasSubtitle, bottomHeight: bottomHeight, subtitleLines: subtitleLines) +
      contentGap;

  @override
  Widget build(BuildContext context) {
    final hasSub = subtitleWidget != null || (subtitle != null && subtitle!.isNotEmpty);
    final total = heightOf(context,
        hasSubtitle: hasSub, bottomHeight: bottomHeight, subtitleLines: subtitleLines);
    final top = MediaQuery.paddingOf(context).top;
    final header = Container(
      height: autoHeight ? null : total,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient ?? tone.gradient,
        borderRadius: tabRoot ? CardRadius.hero : CardRadius.header,
        boxShadow: ShadowTokens.glow(tone.glow),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: top + paddingTop, left: 8, right: 16, bottom: paddingBottom),
        child: Column(
          mainAxisSize: autoHeight ? MainAxisSize.min : MainAxisSize.max,
          children: [
            _Slot(
              height: autoHeight ? null : toolbarHeight + (hasSub ? subtitleHeight * subtitleLines : 0),
              minHeight: toolbarHeight,
              child: Row(
                children: [
                  if (onBack != null)
                    PressScale(
                      child: SizedBox(
                        width: KitMetrics.touch,
                        height: KitMetrics.touch,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          splashColor: DesignColors.whiteSoft,
                          highlightColor: Colors.transparent,
                          onTap: onBack,
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 20, color: DesignColors.textInverse),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  if (leadingAsset != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DesignColors.tint(DesignColors.surfaceAlt, Alpha.soft),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(leadingAsset!),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(22, FontWeight.w700,
                                color: DesignColors.textInverse, letterSpacing: 1.2)),
                        if (hasSub)
                          _Slot(
                            height: autoHeight ? null : subtitleHeight * subtitleLines,
                            child: subtitleWidget ??
                                Text(subtitle!,
                                    maxLines: subtitleLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: TypeTokens.onGradientBody),
                          ),
                      ],
                    ),
                  ),
                  for (final t in trailing) Flexible(child: t),
                ],
              ),
            ),
            if (bottom != null)
              autoHeight ? bottom! : SizedBox(height: bottomHeight, child: bottom),
          ],
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightIcons,
      child: animate && !KitMotion.reduce(context)
          ? _HeaderEntrance(child: header)
          : header,
    );
  }
}

class _HeaderEntrance extends StatefulWidget {
  const _HeaderEntrance({required this.child});
  final Widget child;

  @override
  State<_HeaderEntrance> createState() => _HeaderEntranceState();
}

class _HeaderEntranceState extends State<_HeaderEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TemplateEntrance(
      animation: _a,
      animationController: _c,
      child: widget.child,
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.child, this.height, this.minHeight = 0});
  final Widget child;
  final double? height;
  final double minHeight;

  @override
  Widget build(BuildContext context) => height != null
      ? SizedBox(height: height, child: child)
      : ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight), child: child);
}

class KitStatusBar extends StatelessWidget {
  const KitStatusBar({super.key, required this.child, this.lightIcons = true});

  final Widget child;
  final bool lightIcons;

  static const SystemUiOverlayStyle darkIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: lightIcons ? ModuleHeader.lightIcons : darkIcons,
        child: child,
      );
}
