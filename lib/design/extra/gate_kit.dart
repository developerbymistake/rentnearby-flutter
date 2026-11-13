import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import '../tokens/design_colors.dart';
import '../tokens/card_tokens.dart';
import '../tokens/type_tokens.dart';
import 'package:flutter/services.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'package:pinput/pinput.dart';
import '../template/fitness_app_theme.dart';
import 'template_motion.dart';
import 'travel_icon.dart';
import 'art_3d.dart';
import 'dialog_3d.dart';
import 'pill_buttons_3d.dart';
import '../tokens/listing_palette.dart';
import 'trip_entry_style.dart';
import 'trip_kit.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
import '../tokens/alpha_tokens.dart';

class GateKit {
  GateKit._();

  static const Color whatsApp = DesignColors.whatsApp;
  static Color get scrim =>
      FitnessAppTheme.darkerText.withValues(alpha: Alpha.half);
  static Color get scrimDeep =>
      FitnessAppTheme.nearlyBlack.withValues(alpha: Alpha.high);

  static List<BoxShadow> get shadow => ShadowTokens.elev2;

  static List<BoxShadow> get barShadow => <BoxShadow>[
    ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.strong),
  ];

  static List<BoxShadow> get pillShadow => <BoxShadow>[
    ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.rest),
  ];

  static BoxDecoration card({BorderRadius radius = TripKit.cardRadius}) =>
      BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: radius,
        boxShadow: shadow,
      );

  static BoxDecoration cardSmall() => card(radius: TripKit.cardRadiusSmall);

  static BoxDecoration heroCard() => BoxDecoration(
    color: FitnessAppTheme.white,
    borderRadius: CardRadius.hero,
    boxShadow: ShadowTokens.elev3,
  );

  static TextStyle get bodyText => TypeTokens.style(
    14,
    FontWeight.w400,
    color: TypeTokens.secondary,
    height: 1.6,
  );

  static BoxDecoration pill({Color color = FitnessAppTheme.white}) =>
      BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(38)),
        boxShadow: pillShadow,
      );

  static const TextStyle label = TextStyle(
    fontFamily: FitnessAppTheme.fontName,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: FitnessAppTheme.white,
  );
}

class GateBadge extends StatelessWidget {
  const GateBadge({
    super.key,
    this.asset,
    this.glyph,
    this.size = 84,
    this.gradient = TripEntryStyle.gradient,
  });

  final String? asset;
  final IconData? glyph;
  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          ShadowTokens.tint(DesignColors.lunchEnd, ShadowSpec.glow),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.soft),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: asset != null
                ? TravelIcon(asset!, size: size * 0.5)
                : Icon(glyph, size: size * 0.38, color: FitnessAppTheme.white),
          ),
        ),
      ),
    );
  }
}

class GateButton extends StatelessWidget {
  const GateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 52,
    this.gradient = TripEntryStyle.gradient,
    this.shadowColor = DesignColors.lunchEnd,
    this.icon,
    this.iconAsset,
    this.radius = KitMetrics.buttonRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final Gradient gradient;
  final Color shadowColor;
  final IconData? icon;
  final String? iconAsset;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !isLoading;
    final h = height < KitMetrics.touch ? KitMetrics.touch : height;
    return PressScale(
      enabled: !disabled && !isLoading,
      child: Container(
        width: double.infinity,
        height: h,
        decoration: BoxDecoration(
          gradient: disabled ? null : gradient,
          color: disabled ? FitnessAppTheme.spacer : null,
          borderRadius: radius,
          boxShadow: disabled ? null : ShadowTokens.glow(shadowColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            splashColor: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
            highlightColor: Colors.transparent,
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? const KitDots()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (iconAsset != null) ...<Widget>[
                          TravelIcon(iconAsset!, size: 20),
                          const SizedBox(width: 8),
                        ] else if (icon != null) ...<Widget>[
                          Icon(icon, size: 18, color: FitnessAppTheme.white),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GateKit.label.copyWith(
                              fontSize: 16,
                              color: disabled
                                  ? FitnessAppTheme.deactivatedText
                                  : FitnessAppTheme.white,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class GateOutlineButton extends StatelessWidget {
  const GateOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.color = FitnessAppTheme.nearlyDarkBlue,
    this.icon,
    this.iconAsset,
    this.fill = FitnessAppTheme.nearlyWhite,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color color;
  final IconData? icon;
  final String? iconAsset;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    const radius = KitMetrics.buttonRadius;
    final disabled = onPressed == null;
    final tint = disabled ? FitnessAppTheme.deactivatedText : color;
    final h = height < KitMetrics.touch ? KitMetrics.touch : height;
    return PressScale(
      enabled: !disabled,
      child: Container(
        width: double.infinity,
        height: h,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: Border.all(
            width: 1.5,
            color: disabled
                ? FitnessAppTheme.grey.withValues(alpha: Alpha.soft)
                : color.withValues(alpha: Alpha.half),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            splashColor: color.withValues(alpha: Alpha.tint),
            highlightColor: Colors.transparent,
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (iconAsset != null) ...<Widget>[
                    TravelIcon(iconAsset!, size: 18),
                    const SizedBox(width: 8),
                  ] else if (icon != null) ...<Widget>[
                    Icon(icon, size: 18, color: tint),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitnessAppTheme.body2.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GateTextButton extends StatelessWidget {
  const GateTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = FitnessAppTheme.nearlyDarkBlue,
    this.fontSize = 14,
    this.weight = FontWeight.w600,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double fontSize;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(KitMetrics.touch, KitMetrics.touch),
      ),
      child: Text(
        label,
        style: FitnessAppTheme.body2.copyWith(
          fontSize: fontSize < TypeTokens.floor ? TypeTokens.floor : fontSize,
          fontWeight: weight,
          color: onPressed == null ? FitnessAppTheme.deactivatedText : color,
        ),
      ),
    );
  }
}

class GateDialog extends StatelessWidget {
  const GateDialog({
    super.key,
    required this.title,
    this.body,
    this.asset,
    this.glyph,
    this.gradient = TripEntryStyle.gradient,
    this.content,
    this.actions = const <Widget>[],
    this.horizontalActions = false,
    this.tone,
  });

  final String title;
  final String? body;
  final String? asset;
  final IconData? glyph;
  final Gradient gradient;
  final Widget? content;
  final List<Widget> actions;
  final bool horizontalActions;
  final ListingTone? tone;

  static Widget _pill(Widget a, ListingTone tone) {
    if (a is GateButton) {
      return GradientPillButton(
        key: a.key,
        tone: tone,
        label: a.label,
        onTap: a.onPressed,
        loading: a.isLoading,
        icon: a.icon,
        danger: identical(a.gradient, TripEntryStyle.rose),
        height: 50,
        fontSize: 15,
      );
    }
    if (a is GateOutlineButton) {
      return WhitePillButton(
        key: a.key,
        tone: tone,
        label: a.label,
        onTap: a.onPressed,
        icon: a.icon,
        height: 50,
        fontSize: 15,
      );
    }
    if (a is GateTextButton) {
      return WhitePillButton(
        key: a.key,
        tone: tone,
        label: a.label,
        onTap: a.onPressed,
        danger: a.color != FitnessAppTheme.nearlyDarkBlue,
        height: 50,
        fontSize: 15,
      );
    }
    return a;
  }

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.indigo;
    return Dialog3D(
      tone: t,
      art: asset ?? ListingArt.clipboard,
      title: title,
      body: body,
      content: content,
      actions: <Widget>[for (final a in actions) _pill(a, t)],
      actionsHorizontal: horizontalActions,
    );
  }
}

class GateSheetHeader extends StatelessWidget {
  const GateSheetHeader({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        gradient: TripEntryStyle.gradient,
        borderRadius: CardRadius.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FitnessAppTheme.nearlyWhite.withValues(
                  alpha: Alpha.half,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitnessAppTheme.title.copyWith(
                    color: FitnessAppTheme.white,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: FitnessAppTheme.caption.copyWith(
                color: FitnessAppTheme.white.withValues(alpha: Alpha.strong),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GateSearchBar extends StatelessWidget {
  const GateSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.autofocus = false,
    this.inputFormatters,
    this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: GateKit.pill(color: FitnessAppTheme.background),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: FitnessAppTheme.nearlyBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              cursorColor: FitnessAppTheme.nearlyDarkBlue,
              style: FitnessAppTheme.body1,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: hint,
                hintStyle: FitnessAppTheme.body1.copyWith(
                  color: FitnessAppTheme.deactivatedText,
                ),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

class GateStatusPage extends StatelessWidget {
  const GateStatusPage({
    super.key,
    required this.asset,
    required this.title,
    required this.body,
    this.primary,
    this.secondary,
    this.footer,
    this.extra,
    this.tone,
  });

  final String asset;
  final String title;
  final String body;
  final Widget? primary;
  final Widget? secondary;
  final Widget? footer;
  final Widget? extra;
  final ListingTone? tone;

  static const double panelHeight = 376;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.indigo;
    final mq = MediaQuery.of(context);
    final scale = mq.textScaler.scale(1);
    final panel = Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: panelHeight + mq.viewPadding.bottom,
      ),
      padding: EdgeInsets.fromLTRB(24, 30, 24, 34 + mq.viewPadding.bottom),
      decoration: const BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: Ink3D.topEdge,
      ),
      child: Align(
        heightFactor: 1,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 2 * 25 * 1.25 * scale),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Ink3D.text(
                        25,
                        FontWeight.w700,
                        Ink3D.title,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Ink3D.text(15, FontWeight.w400, Ink3D.copy, height: 1.5),
              ),
              if (extra != null) ...<Widget>[
                const SizedBox(height: 12),
                DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: Ink3D.text(13, FontWeight.w400, Ink3D.grey),
                  child: Center(child: extra!),
                ),
              ],
              if (primary != null) ...<Widget>[
                const SizedBox(height: 24),
                primary!,
              ],
              if (secondary != null) ...<Widget>[
                SizedBox(height: primary == null ? 24 : 12),
                secondary!,
              ],
              if (footer != null) ...<Widget>[
                const SizedBox(height: 12),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
    return Material(
      color: FitnessAppTheme.background,
      child: LayoutBuilder(
        builder: (context, box) => Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: mq.viewPadding.top),
                child: LayoutBuilder(
                  builder: (context, top) {
                    final size = (top.maxHeight - 40)
                        .clamp(0.0, 206.0)
                        .toDouble();
                    if (size < 72) return const SizedBox.shrink();
                    return Center(
                      child: ExcludeSemantics(
                        child: Art3D(
                          asset: asset,
                          size: size,
                          halo: size * 236 / 206,
                          haloColor: t.haloBase.withValues(alpha: Alpha.v14),
                          shadowBlur: 10,
                          shadowOffset: const Offset(8, 12),
                          shadowAlpha: Alpha.v25,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (box.maxHeight - mq.viewPadding.top - 20)
                    .clamp(panelHeight, double.infinity)
                    .toDouble(),
              ),
              child: panel,
            ),
          ],
        ),
      ),
    );
  }
}

class GateHeroHeader extends StatelessWidget {
  const GateHeroHeader({
    super.key,
    this.asset,
    this.glyph,
    this.imageProvider,
    required this.title,
    this.subtitle,
    this.height,
    this.top,
    this.titleSize = 30,
  });

  final String? asset;
  final IconData? glyph;
  final ImageProvider? imageProvider;
  final String title;
  final String? subtitle;
  final double? height;
  final Widget? top;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final clamped = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: clamped),
        child: Container(
          width: double.infinity,
          height: height,
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.fromLTRB(
            KitMetrics.gutter,
            topPad + 12,
            KitMetrics.gutter,
            40,
          ),
          decoration: BoxDecoration(
            gradient: TripEntryStyle.gradient,
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(CardRadius.heroNotch),
              bottomLeft: Radius.circular(CardRadius.corner),
            ),
            boxShadow: ShadowTokens.glow(DesignColors.lunchEnd),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(right: -56, top: -24, child: _halo(180)),
              Positioned(left: -40, bottom: -64, child: _halo(140)),
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (top != null) top!,
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: FitnessAppTheme.nearlyWhite.withValues(
                          alpha: Alpha.soft,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: imageProvider != null
                          ? ClipOval(
                              child: Image(
                                image: imageProvider!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: asset != null
                                  ? TravelIcon(asset!, size: 48)
                                  : Icon(
                                      glyph,
                                      size: 40,
                                      color: FitnessAppTheme.white,
                                    ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: FitnessAppTheme.headline.copyWith(
                        fontSize: titleSize,
                        letterSpacing: 1.2,
                        color: FitnessAppTheme.white,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: TypeTokens.style(
                          14,
                          FontWeight.w500,
                          color: DesignColors.whiteHigh,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _halo(double size) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.faint),
      ),
    ),
  );
}

class GateHeroLayout extends StatelessWidget {
  const GateHeroLayout({
    super.key,
    required this.hero,
    required this.child,
    this.heroHeight = 250,
    this.overlap = 56,
  });

  final Widget hero;
  final Widget child;
  final double heroHeight;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final h = heroHeight + MediaQuery.paddingOf(context).top;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(top: 0, left: 0, right: 0, height: h, child: hero),
        Padding(
          padding: EdgeInsets.only(top: h - overlap),
          child: child,
        ),
      ],
    );
  }
}

class GatePageBar extends StatelessWidget {
  const GatePageBar({
    super.key,
    required this.title,
    required this.onBack,
    this.opacity,
    this.scroll = 1,
  });

  final String title;
  final VoidCallback onBack;
  final Animation<double>? opacity;
  final double scroll;

  @override
  Widget build(BuildContext context) {
    final op = scroll.clamp(0.0, 1.0);
    final bar = Container(
      decoration: BoxDecoration(
        color: FitnessAppTheme.white.withValues(alpha: op),
        borderRadius: CardRadius.header,
        boxShadow: <BoxShadow>[
          ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.strong.scaled(op)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 16 - 8.0 * op,
          left: 8,
          right: 16,
          bottom: 12 - 8.0 * op,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: KitMetrics.touch,
              height: KitMetrics.touch,
              child: InkWell(
                highlightColor: Colors.transparent,
                borderRadius: CardRadius.pill,
                onTap: onBack,
                child: const Center(
                  child: Icon(
                    Icons.keyboard_arrow_left,
                    color: FitnessAppTheme.grey,
                    size: 28,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FitnessAppTheme.fontName,
                  fontWeight: FontWeight.w700,
                  fontSize: 28 - 6 * op,
                  letterSpacing: 1.2,
                  color: FitnessAppTheme.darkerText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (opacity == null) return bar;
    return FadeTransition(opacity: opacity!, child: bar);
  }
}

class GatePinThemes {
  GatePinThemes._();

  static PinTheme base(double boxSize) => PinTheme(
    width: boxSize,
    height: boxSize + 8,
    textStyle: FitnessAppTheme.title.copyWith(
      fontSize: boxSize * 0.38,
      color: FitnessAppTheme.nearlyDarkBlue,
    ),
    decoration: BoxDecoration(
      color: FitnessAppTheme.white,
      borderRadius: CardRadius.chip,
      border: Border.all(
        color: FitnessAppTheme.grey.withValues(alpha: Alpha.soft),
        width: 1.5,
      ),
      boxShadow: <BoxShadow>[
        ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.elev2Spec),
      ],
    ),
  );

  static PinTheme focused(double boxSize) => base(boxSize).copyWith(
    decoration: BoxDecoration(
      color: FitnessAppTheme.white,
      borderRadius: CardRadius.chip,
      border: Border.all(color: FitnessAppTheme.nearlyDarkBlue, width: 2),
      boxShadow: <BoxShadow>[
        ShadowTokens.tint(FitnessAppTheme.nearlyDarkBlue, ShadowSpec.ringStrong),
      ],
    ),
  );

  static PinTheme submitted(double boxSize) => base(boxSize).copyWith(
    textStyle: FitnessAppTheme.title.copyWith(
      fontSize: boxSize * 0.38,
      color: FitnessAppTheme.white,
    ),
    decoration: BoxDecoration(
      gradient: TripEntryStyle.gradient,
      borderRadius: CardRadius.chip,
    ),
  );
}

class GateSwitcher extends StatelessWidget {
  const GateSwitcher({
    super.key,
    required this.child,
    this.reverse = false,
    this.horizontal = false,
  });

  final Widget child;
  final bool reverse;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: templateTransitionDuration,
      reverse: reverse,
      transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
        fillColor: Colors.transparent,
        animation: primary,
        secondaryAnimation: secondary,
        transitionType: horizontal
            ? SharedAxisTransitionType.horizontal
            : SharedAxisTransitionType.vertical,
        child: child,
      ),
      child: child,
    );
  }
}

class GateScreenMotion extends StatefulWidget {
  const GateScreenMotion({
    super.key,
    required this.count,
    required this.builder,
  });

  final int count;
  final Widget Function(
    BuildContext context,
    Widget Function(int index, Widget child) wrap,
  )
  builder;

  @override
  State<GateScreenMotion> createState() => _GateScreenMotionState();
}

class _GateScreenMotionState extends State<GateScreenMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _wrap(int index, Widget child) {
    final i = index < widget.count ? index : widget.count - 1;
    return TemplateEntrance(
      animation: templateInterval(_controller, i, widget.count),
      animationController: _controller,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _wrap);
}

class GateLegalPage extends StatefulWidget {
  const GateLegalPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  State<GateLegalPage> createState() => _GateLegalPageState();
}

class _GateLegalPageState extends State<GateLegalPage>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );
  late final Animation<double> _barAnimation = Tween<double>(begin: 0, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.5, curve: Curves.fastOutSlowIn),
        ),
      );
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _fade = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) _controller.value = 1;
  }

  void _onScroll() {
    final o = _scroll.offset;
    final v = o >= 24 ? 1.0 : (o <= 0 ? 0.0 : o / 24);
    if (v != _fade.value) _fade.value = v;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    final topPad = MediaQuery.paddingOf(context).top + 64 + 16;
    return Container(
      color: FitnessAppTheme.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            ListView.builder(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                0,
                topPad,
                0,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: n,
              itemBuilder: (context, i) {
                final idx = i < 9 ? i : 9;
                return TemplateEntrance(
                  animation: templateInterval(_controller, idx, 10),
                  animationController: _controller,
                  child: widget.children[i],
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _fade,
                builder: (context, v, _) => GatePageBar(
                  title: widget.title,
                  opacity: _barAnimation,
                  scroll: v,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GateLegalHeading extends StatelessWidget {
  const GateLegalHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      KitMetrics.gutter,
      0,
      KitMetrics.gutter,
      4,
    ),
    child: Text(text, style: FitnessAppTheme.headline),
  );
}

class GateLegalCaption extends StatelessWidget {
  const GateLegalCaption(this.text, {super.key, this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      KitMetrics.gutter,
      4,
      KitMetrics.gutter,
      12,
    ),
    child: Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary),
    ),
  );
}

class GateLegalBody extends StatelessWidget {
  const GateLegalBody(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      KitMetrics.gutter,
      4,
      KitMetrics.gutter,
      8,
    ),
    child: Text(text, style: GateKit.bodyText),
  );
}

class GateLegalSection extends StatelessWidget {
  const GateLegalSection({
    super.key,
    required this.title,
    this.body,
    this.bullets,
  });

  final String title;
  final String? body;
  final List<String>? bullets;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: KitMetrics.gutter,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: GateKit.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title.isNotEmpty) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    gradient: TripEntryStyle.gradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(child: Text(title, style: FitnessAppTheme.title)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (body != null) Text(body!, style: GateKit.bodyText),
          if (body != null && bullets != null) const SizedBox(height: 8),
          if (bullets != null)
            for (final b in bullets!)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 8, right: 10),
                      decoration: const BoxDecoration(
                        color: FitnessAppTheme.nearlyBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Text(b, style: GateKit.bodyText)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
