import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../template/ui_view/mediterranean_diet_view.dart' show CurvePainter;
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/template_tokens.dart';
import '../tokens/type_tokens.dart';
import 'card_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'template_motion.dart';
import 'travel_icon.dart';

class ScrollFadeTopBar extends StatefulWidget {
  const ScrollFadeTopBar({
    super.key,
    required this.title,
    required this.scrollController,
    this.onBack,
    this.trailing = const [],
    this.subtitle,
    this.threshold = 24,
  });

  final String title;
  final ScrollController scrollController;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final String? subtitle;
  final double threshold;

  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 16 + 38 + 12 + 16;

  @override
  State<ScrollFadeTopBar> createState() => _ScrollFadeTopBarState();
}

class _ScrollFadeTopBarState extends State<ScrollFadeTopBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn);
  double _op = 0;
  bool _started = false;

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final o = widget.scrollController.offset;
    final v = o >= widget.threshold ? 1.0 : (o <= 0 ? 0.0 : o / widget.threshold);
    if (v != _op) setState(() => _op = v);
  }

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (KitMotion.reduce(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(ScrollFadeTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final op = _op;
    return TemplateEntrance(
      animation: _a,
      animationController: _c,
      child: Container(
        decoration: BoxDecoration(
          color: DesignColors.tint(DesignColors.surface, op),
          borderRadius: CardRadius.header,
          boxShadow: [
            ShadowTokens.tint(DesignColors.textGrey,
                const ShadowSpec(0.4, Offset(1.1, 1.1), 10).scaled(op)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top),
            Padding(
              padding: EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 12),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: InkWell(
                        highlightColor: Colors.transparent,
                        borderRadius: const BorderRadius.all(Radius.circular(32)),
                        onTap: widget.onBack,
                        child: const Icon(Icons.keyboard_arrow_left,
                            size: 28, color: DesignColors.textGrey),
                      ),
                    ),
                  if (widget.onBack != null) const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(
                                24, FontWeight.w700,
                                color: DesignColors.textStrong,
                                letterSpacing: 1.2)),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.caption),
                      ],
                    ),
                  ),
                  if (widget.trailing.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [for (final t in widget.trailing) Flexible(child: t)]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1000),
  });

  final int value;
  final TextStyle style;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final d = KitMotion.reduce(context) ? Duration.zero : duration;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: d,
      curve: Curves.fastOutSlowIn,
      builder: (context, v, _) =>
          Text('${(value * v).toInt()}$suffix', style: style),
    );
  }
}

class RingSweep extends StatelessWidget {
  const RingSweep({
    super.key,
    required this.progress,
    this.size = 108,
    this.colors = const [
      DesignColors.primary,
      DesignColors.ringLight,
      DesignColors.ringLight
    ],
    this.center,
    this.duration = const Duration(milliseconds: 1000),
  });

  final double progress;
  final double size;
  final List<Color> colors;
  final Widget? center;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final d = KitMotion.reduce(context) ? Duration.zero : duration;
    final inner = size - 8;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: p),
      duration: d,
      curve: Curves.fastOutSlowIn,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                color: DesignColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                    width: 4,
                    color: DesignColors.tint(DesignColors.primary, Alpha.soft)),
              ),
              child: center == null ? null : Center(child: center),
            ),
            CustomPaint(
              painter: CurvePainter(colors: colors, angle: 5 + 360 * v),
              child: SizedBox(width: size, height: size),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroGradientCard extends StatelessWidget {
  const HeroGradientCard({
    super.key,
    required this.title,
    required this.onTap,
    this.label,
    this.iconAsset,
    this.tone = KitTone.brand,
    this.gradient,
    this.margin =
        const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 12),
  });

  final String title;
  final String? label;
  final String? iconAsset;
  final VoidCallback? onTap;
  final KitTone tone;
  final Gradient? gradient;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: PressScale(
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient ?? tone.gradient,
            borderRadius: CardRadius.hero,
            boxShadow: ShadowTokens.glow(tone.glow),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: CardRadius.hero,
              splashColor: TemplateTokens.white24,
              highlightColor: Colors.transparent,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (label != null)
                                Text(label!, style: TypeTokens.onGradientBody),
                              const SizedBox(height: 8),
                              Text(title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TypeTokens.style(20, FontWeight.w700,
                                      color: DesignColors.onPrimary)),
                            ],
                          ),
                        ),
                        if (iconAsset != null)
                          Container(
                            width: 84,
                            height: 84,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: DesignColors.tint(
                                  DesignColors.surfaceAlt, Alpha.soft),
                            ),
                            child: Image.asset(iconAsset!),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DesignColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            ShadowTokens.tint(TemplateTokens.nearlyBlack,
                                const ShadowSpec(0.4, Offset(8, 8), 8))
                          ],
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 22, color: tone.accentDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OverlappedImageCard extends StatelessWidget {
  const OverlappedImageCard({
    super.key,
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.caption,
    this.ratingText,
    this.priceText,
    this.tone = KitTone.stay,
    this.fallbackAsset = TravelIcon.stay,
    this.actionIcon = Icons.add,
    this.onAction,
  });

  static const double width = 280;
  static const double height = 144;

  final String title;
  final VoidCallback? onTap;
  final String? imageUrl;
  final String? caption;
  final String? ratingText;
  final String? priceText;
  final KitTone tone;
  final String fallbackAsset;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    const photo = height - 48.0;
    return PressScale(
      child: SizedBox(
        width: width,
        height: height,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                left: 48,
                child: Container(
                  decoration: const BoxDecoration(
                    color: TemplateTokens.courseCardBackground,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.fromLTRB(72 + 16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(16, FontWeight.w600,
                              color: DesignColors.textStrong,
                              letterSpacing: 0.27)),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(caption ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.style(12, FontWeight.w400,
                                    color: DesignColors.textGrey,
                                    letterSpacing: 0.27)),
                          ),
                          if (ratingText != null) ...[
                            Text(ratingText!,
                                style: TypeTokens.style(14, FontWeight.w600,
                                    color: DesignColors.textGrey)),
                            const SizedBox(width: 2),
                            const TravelIcon(TravelIcon.star, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(priceText ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.style(18, FontWeight.w600,
                                    color: tone.accentDark,
                                    letterSpacing: 0.27)),
                          ),
                          GestureDetector(
                            onTap: onAction ?? onTap,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                  color: tone.accentDark,
                                  borderRadius: CardRadius.chip),
                              child: Icon(actionIcon,
                                  size: 20, color: DesignColors.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: KitMetrics.photo,
                    boxShadow: [
                      ShadowTokens.tint(
                          DesignColors.textGrey, ShadowSpec.ring)
                    ],
                  ),
                  child: KitPhoto(
                    url: imageUrl,
                    width: photo,
                    height: photo,
                    tone: tone,
                    asset: fallbackAsset,
                    radius: KitMetrics.photo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinnedFilterBar extends StatelessWidget {
  const PinnedFilterBar({
    super.key,
    required this.child,
    this.extent = defaultExtent,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 4),
  });

  final Widget child;
  final double extent;
  final EdgeInsetsGeometry padding;
  static const double defaultExtent = 52;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedDelegate(child, extent, padding),
    );
  }
}

class FixedFilterBar extends StatelessWidget {
  const FixedFilterBar({super.key, required this.child, this.height = PinnedFilterBar.defaultExtent});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: DesignColors.scaffold,
        boxShadow: [ShadowTokens.tint(DesignColors.textGrey, ShadowSpec.topBar)],
        border: const Border(bottom: BorderSide(color: DesignColors.divider)),
      ),
      child: child,
    );
  }
}

class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  _PinnedDelegate(this.child, this.extent, this.padding);
  final Widget child;
  final double extent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: DesignColors.scaffold,
              boxShadow: [
                ShadowTokens.tint(DesignColors.textGrey, ShadowSpec.topBar)
              ],
            ),
          ),
        ),
        Container(
          color: DesignColors.scaffold,
          padding: padding,
          child: child,
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Divider(height: 1, color: DesignColors.divider),
        ),
      ],
    );
  }

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  bool shouldRebuild(covariant _PinnedDelegate oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.extent != extent ||
      oldDelegate.padding != padding;
}

double kitSigma(double radius) => radius * 0.57735 + 0.5;

void paintRingThumb(Canvas canvas, Offset c, Color color) {
  canvas.drawPath(
    Path()
      ..addOval(Rect.fromCenter(center: c, width: 24, height: 24))
      ..fillType = PathFillType.evenOdd,
    Paint()
      ..color = TemplateTokens.black.withValues(alpha: Alpha.half)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, kitSigma(8)),
  );
  canvas.drawCircle(c, 12, Paint()..color = TemplateTokens.white);
  canvas.drawCircle(c, 10, Paint()..color = color);
}

class RingThumbShape extends SliderComponentShape {
  const RingThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(12);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    paintRingThumb(
        context.canvas, center, sliderTheme.thumbColor ?? DesignColors.primary);
  }
}

class RingRangeThumbShape extends RangeSliderThumbShape {
  const RingRangeThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(12);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    paintRingThumb(
        context.canvas, center, sliderTheme.thumbColor ?? DesignColors.primary);
  }
}

SliderThemeData ringSliderTheme(BuildContext context, {Color? color}) {
  final c = color ?? DesignColors.primary;
  return SliderTheme.of(context).copyWith(
    activeTrackColor: c,
    inactiveTrackColor: DesignColors.tint(DesignColors.textGrey, Alpha.soft),
    thumbColor: c,
    overlayColor: DesignColors.tint(c, Alpha.tint),
    trackHeight: 4,
    thumbShape: const RingThumbShape(),
    rangeThumbShape: const RingRangeThumbShape(),
  );
}

class RingSlider extends StatelessWidget {
  const RingSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
    this.color,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final Color? color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = max <= min ? 0.0 : ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          LayoutBuilder(
            builder: (context, c) {
              const pad = 12.0;
              final w = math.max(0.0, c.maxWidth - pad * 2);
              return Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: pad + w * t),
                child: FractionalTranslation(
                  translation: const Offset(-0.5, 0),
                  child: Text(label!,
                      style: TypeTokens.style(12, FontWeight.w600,
                          color: DesignColors.textStrong)),
                ),
              );
            },
          ),
        SliderTheme(
          data: ringSliderTheme(context, color: color),
          child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged),
        ),
      ],
    );
  }
}
