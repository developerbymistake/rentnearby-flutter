import 'package:bakhli/design/tokens/design_scale.dart';
import 'dart:math' as math;
import 'package:bakhli/models/card_fact.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/widgets/plan_badge_chip.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'template_motion.dart';
import 'travel_icon.dart';

EdgeInsets _scaleMargin(EdgeInsets m) => EdgeInsets.fromLTRB(DS.s(m.left), DS.gv(m.top), DS.s(m.right), DS.gv(m.bottom));

class _Bone extends StatelessWidget {
  const _Bone({this.width, this.height = 12, this.radius = 6});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      TemplatePlaceholder(width: width == null ? null : DS.s(width!), height: DS.s(height), radius: DS.radius(radius));
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.onTap,
    this.shadow = ShadowTokens.elev2,
    this.radius = CardRadius.tile,
    this.color = DesignColors.surface,
    this.press = true,
    this.foreground,
    this.gradient,
  });

  final Gradient? gradient;
  final Widget child;
  final VoidCallback? onTap;
  final List<BoxShadow> shadow;
  final BorderRadius radius;
  final Color color;
  final bool press;
  final Decoration? foreground;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(color: gradient == null ? color : null, borderRadius: DS.br(radius), boxShadow: DS.shadows(shadow)),
      child: Material(
        color: Colors.transparent,
        borderRadius: DS.br(radius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: gradient == null ? null : BoxDecoration(gradient: gradient, borderRadius: DS.br(radius)),
          child: InkWell(
            onTap: onTap,
            splashColor: DesignColors.splash,
            highlightColor: Colors.transparent,
            child: foreground == null
                ? child
                : DecoratedBox(decoration: foreground!, position: DecorationPosition.foreground, child: child),
          ),
        ),
      ),
    );
    return press && onTap != null ? PressScale(child: card) : card;
  }
}

class KitFactChip extends StatelessWidget {
  const KitFactChip(this.fact, {super.key, this.tone = KitTone.stay});

  final CardFact fact;
  final KitTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (fact.tone) {
      FactTone.accent => (tone.tint, tone.accentDark),
      FactTone.cyan => (DesignColors.infoTint, DesignColors.primary),
      FactTone.slate => (DesignColors.scaffold, DesignColors.textGrey),
    };
    return Container(
      padding: DS.sym(h: 6, v: 3),
      decoration: BoxDecoration(color: bg, borderRadius: DS.br(CardRadius.chip)),
      child: Text(fact.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TypeTokens.style(10, FontWeight.w700, color: fg, chip: true)),
    );
  }
}

class KitTagChip extends StatelessWidget {
  const KitTagChip(this.label, {super.key, this.tone = KitTone.stay, this.solid = false, this.color});

  final String label;
  final KitTone tone;
  final bool solid;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? tone.accentDark;
    return Container(
      padding: DS.sym(h: 8, v: 3),
      decoration: BoxDecoration(
        color: solid ? c : DesignColors.tint(c, Alpha.tint),
        borderRadius: DS.br(CardRadius.chip),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TypeTokens.style(10, FontWeight.w700,
              color: solid ? DesignColors.onPrimary : c, chip: true, letterSpacing: 0.4)),
    );
  }
}

class KitFeaturedRibbon extends StatelessWidget {
  const KitFeaturedRibbon({super.key, this.tone = KitTone.stay, this.label = 'Featured'});

  final KitTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.insets(l: 6, t: 3, r: 8, b: 3),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.br(CardRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TravelIcon(TravelIcon.star, size: 12),
          SizedBox(width: DS.s(3)),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(10, FontWeight.w700, color: DesignColors.onPrimary, chip: true)),
          ),
        ],
      ),
    );
  }
}

class PlaceholderTile extends StatelessWidget {
  const PlaceholderTile({
    super.key,
    this.tone = KitTone.stay,
    this.asset = TravelIcon.stay,
    this.iconSize = 36,
    this.radius = BorderRadius.zero,
    this.width,
    this.height,
    this.gradient,
    this.rich = false,
  });

  final bool rich;
  final LinearGradient? gradient;
  final KitTone tone;
  final String asset;
  final double iconSize;
  final BorderRadius radius;
  final double? width;
  final double? height;

  static Widget skeleton({double? width, double? height, double radius = 12}) =>
      _Bone(width: width, height: height ?? 72, radius: radius);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: DS.br(radius),
        gradient: LinearGradient(
          colors: rich
              ? [gradient?.colors.first ?? tone.accent, gradient?.colors.last ?? tone.accentDark]
              : [
                  DesignColors.tint(gradient?.colors.first ?? tone.accent, Alpha.soft),
                  DesignColors.tint(gradient?.colors.last ?? tone.accentDark, Alpha.tint),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: DS.s(iconSize + 24),
          height: DS.s(iconSize + 24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.tint(DesignColors.surfaceAlt, rich ? Alpha.half : Alpha.soft),
            boxShadow: rich ? DS.shadows(ShadowTokens.tight(tone.accentDark)) : null,
          ),
          child: Center(child: TravelIcon(asset, size: iconSize)),
        ),
      ),
    );
  }
}

class KitPhoto extends StatelessWidget {
  const KitPhoto({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.tone = KitTone.stay,
    this.asset = TravelIcon.stay,
    this.radius = BorderRadius.zero,
    this.iconSize = 36,
    this.dimmed = false,
    this.rich = false,
  });

  final bool rich;
  final String? url;
  final double width;
  final double height;
  final KitTone tone;
  final String asset;
  final BorderRadius radius;
  final double iconSize;
  final bool dimmed;

  static const int maxDecodePx = 480;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fallback = PlaceholderTile(tone: tone, asset: asset, iconSize: iconSize, radius: radius, width: width, height: height, rich: rich);
    final longest = math.max(width.isFinite ? width : 0.0, height.isFinite ? height : 0.0) * dpr;
    final shrink = longest > maxDecodePx ? maxDecodePx / longest : 1.0;
    int? px(double v) => v.isFinite ? math.max(1, (v * dpr * shrink).round()) : null;
    final image = url == null || url!.isEmpty
        ? fallback
        : ClipRRect(
            borderRadius: DS.br(radius),
            child: CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              memCacheWidth: px(width),
              memCacheHeight: px(height),
              placeholder: (_, _) => TemplatePlaceholder(width: width, height: height, radius: 0),
              errorWidget: (_, _, _) => fallback,
            ),
          );
    if (!dimmed) return image;
    return Stack(children: [
      image,
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DesignColors.tint(DesignColors.surface, Alpha.strong),
            borderRadius: DS.br(radius),
          ),
        ),
      ),
    ]);
  }
}

class RailCard extends StatelessWidget {
  const RailCard({
    super.key,
    required this.title,
    required this.onTap,
    this.thumbnailUrl,
    this.tagLabel,
    this.locationLabel,
    this.facts = const [],
    this.priceCaption = '',
    this.priceValue = '',
    this.priceUnit = '',
    this.isFeatured = false,
    this.tone = KitTone.stay,
    this.fallbackAsset = TravelIcon.stay,
    this.trailing,
    this.selected = false,
    this.media,
    this.stackedCaption = false,
    this.noPriceLabel,
  });

  final bool stackedCaption;
  final String? noPriceLabel;

  static const double width = 168;
  static const double photoHeight = 112;
  static const double height = 260;
  static const double gridMaxExtent = 190;
  static const double gridSpacing = 16;

  final String title;
  final VoidCallback? onTap;
  final String? thumbnailUrl;
  final String? tagLabel;
  final String? locationLabel;
  final List<CardFact> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;
  final bool isFeatured;
  final KitTone tone;
  final String fallbackAsset;
  final Widget? trailing;
  final bool selected;
  final Widget? media;

  static SliverGridDelegate gridDelegate() =>
      SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: DS.s(gridMaxExtent),
        mainAxisExtent: DS.s(height),
        mainAxisSpacing: DS.gv(gridSpacing),
        crossAxisSpacing: DS.gh(gridSpacing),
      );

  static Widget skeleton({double? cardWidth}) => SizedBox(
        width: DS.s(cardWidth ?? width),
        height: DS.s(height),
        child: _Surface(
          press: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Bone(height: photoHeight, radius: 0),
              Padding(
                padding: DS.insets(l: 10, t: 10, r: 10, b: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bone(height: 14),
                    SizedBox(height: DS.s(6)),
                    _Bone(height: 14, width: 90),
                    SizedBox(height: DS.s(8)),
                    _Bone(height: 11, width: 70),
                    SizedBox(height: DS.s(8)),
                    Row(children: [_Bone(height: 18, width: 44, radius: 8), SizedBox(width: DS.s(6)), _Bone(height: 18, width: 44, radius: 8)]),
                    SizedBox(height: DS.s(12)),
                    _Bone(height: 16, width: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  bool get _hasPriceRow => priceValue.isNotEmpty || (noPriceLabel != null && noPriceLabel!.isNotEmpty);

  Widget _priceRow() {
    return Row(
      children: [
        Expanded(
          child: priceValue.isEmpty
              ? Text(noPriceLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w800, color: tone.accentDark, letterSpacing: 0.8))
              : stackedCaption && priceCaption.isNotEmpty
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(priceCaption, maxLines: 1, style: TypeTokens.caption),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: priceValue,
                                  style: TypeTokens.style(15, FontWeight.w800, color: tone.accentDark)),
                              if (priceUnit.isNotEmpty) TextSpan(text: priceUnit, style: TypeTokens.caption),
                            ]),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(children: [
                          if (priceCaption.isNotEmpty) TextSpan(text: '$priceCaption ', style: TypeTokens.caption),
                          TextSpan(
                              text: priceValue,
                              style: TypeTokens.style(15, FontWeight.w800, color: tone.accentDark)),
                          if (priceUnit.isNotEmpty) TextSpan(text: priceUnit, style: TypeTokens.caption),
                        ]),
                        maxLines: 1,
                      ),
                    ),
        ),
        SizedBox(width: DS.s(6)),
        Container(
          width: DS.s(28),
          height: DS.s(28),
          decoration: BoxDecoration(gradient: tone.gradient, shape: BoxShape.circle),
          child: Icon(Icons.chevron_right_rounded, size: DS.s(20), color: DesignColors.onPrimary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Surface(
      onTap: onTap,
      shadow: selected ? ShadowTokens.elev3 : ShadowTokens.elev2,
      foreground: selected
          ? BoxDecoration(
              borderRadius: CardRadius.tile,
              border: Border.all(color: tone.accentDark, width: DS.s(2)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: DS.s(photoHeight),
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                media ??
                    LayoutBuilder(
                      builder: (context, c) => KitPhoto(
                        url: thumbnailUrl,
                        width: c.maxWidth,
                        height: DS.s(photoHeight),
                        tone: tone,
                        asset: fallbackAsset,
                        iconSize: 40,
                      ),
                    ),
                if (tagLabel != null && tagLabel!.isNotEmpty)
                  Positioned(
                    top: DS.s(8),
                    left: DS.s(8),
                    right: DS.s(8),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: KitTagChip(tagLabel!, tone: tone, solid: true),
                    ),
                  ),
                if (isFeatured)
                  Positioned(left: DS.s(8), bottom: DS.s(8), child: PlanBadgeChip(color: tone.accentDark, compact: false)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: DS.insets(l: 10, t: 8, r: 10, b: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textStrong, height: 1.2)),
                  if (locationLabel != null && locationLabel!.isNotEmpty) ...[
                    SizedBox(height: DS.s(4)),
                    Row(
                      children: [
                        const TravelIcon(TravelIcon.place, size: 12),
                        SizedBox(width: DS.s(3)),
                        Expanded(
                          child: Text(locationLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.caption),
                        ),
                      ],
                    ),
                  ],
                  if (facts.isNotEmpty) ...[
                    SizedBox(height: DS.s(6)),
                    SizedBox(
                      height: DS.s(22),
                      width: double.infinity,
                      child: ClipRect(
                        child: Wrap(
                          spacing: DS.gh(4),
                          runSpacing: DS.gv(4),
                          children: [for (final f in facts) KitFactChip(f, tone: tone)],
                        ),
                      ),
                    ),
                  ],
                  if (trailing != null || !_hasPriceRow) const Spacer(),
                  if (trailing != null) Align(alignment: Alignment.centerLeft, child: trailing),
                  if (_hasPriceRow)
                    trailing == null
                        ? Expanded(child: Align(alignment: Alignment.bottomCenter, child: _priceRow()))
                        : _priceRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.onTap,
    this.subtitle,
    this.tag,
    this.facts = const [],
    this.priceValue,
    this.priceUnit,
    this.priceCaption,
    this.thumbnailUrl,
    this.iconAsset = TravelIcon.stay,
    this.leading,
    this.trailing,
    this.trailingTop = false,
    this.footer,
    this.tone = KitTone.stay,
    this.compact = false,
    this.dimmed = false,
    this.notice,
    this.isFeatured = false,
    this.showChevron = true,
    this.margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
    this.titleMaxLines,
    this.subtitleLines = 1,
    this.elevated = false,
    this.header,
    this.body,
    this.rows = const [],
    this.tagBadge,
    this.solidTag = false,
    this.rich = false,
  });

  final bool rich;
  final String title;
  final VoidCallback? onTap;
  final String? subtitle;
  final String? tag;
  final List<CardFact> facts;
  final String? priceValue;
  final String? priceUnit;
  final String? priceCaption;
  final String? thumbnailUrl;
  final String iconAsset;
  final Widget? leading;
  final Widget? trailing;
  final bool trailingTop;
  final Widget? footer;
  final KitTone tone;
  final bool compact;
  final bool dimmed;
  final String? notice;
  final bool isFeatured;
  final bool showChevron;
  final EdgeInsets margin;
  final int? titleMaxLines;
  final int subtitleLines;
  final bool elevated;
  final Widget? header;
  final Widget? body;
  final List<Widget> rows;
  final Widget? tagBadge;
  final bool solidTag;

  static const double minHeight = 88;
  static const double tileSize = 72;
  static const double tileSizeCompact = 56;

  static Widget skeleton({bool compact = false, EdgeInsets margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6)}) {
    final t = compact ? tileSizeCompact : tileSize;
    return Padding(
      padding: _scaleMargin(margin),
      child: _Surface(
        shadow: ShadowTokens.elev1,
        press: false,
        child: Padding(
          padding: DS.all(8),
          child: Row(
            children: [
              _Bone(width: t, height: t, radius: 12),
              SizedBox(width: DS.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bone(width: 56, height: 14, radius: 8),
                    SizedBox(height: DS.s(6)),
                    _Bone(height: 14),
                    SizedBox(height: DS.s(6)),
                    _Bone(width: 110, height: 11),
                  ],
                ),
              ),
              SizedBox(width: DS.s(12)),
              const _Bone(width: 44, height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = DS.s(compact ? tileSizeCompact : tileSize);
    final titleColor = dimmed ? DesignColors.textMuted : DesignColors.textStrong;
    final lead = leading ??
        Stack(
          children: [
            KitPhoto(
              url: thumbnailUrl,
              width: t,
              height: t,
              tone: tone,
              asset: iconAsset,
              radius: KitMetrics.tileSmall,
              iconSize: compact ? 28 : 36,
              dimmed: dimmed,
              rich: rich,
            ),
            if (isFeatured)
              Positioned(
                left: DS.s(4),
                bottom: DS.s(4),
                child: Container(
                  width: DS.s(20),
                  height: DS.s(20),
                  decoration: BoxDecoration(gradient: tone.gradient, shape: BoxShape.circle),
                  child: const Center(child: TravelIcon(TravelIcon.star, size: 12)),
                ),
              ),
          ],
        );
    final hasPrice = priceValue != null && priceValue!.isNotEmpty;
    final right = trailing ??
        (hasPrice || showChevron
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasPrice) ...[
                    if (priceCaption != null && priceCaption!.isNotEmpty)
                      Text(priceCaption!, style: TypeTokens.caption),
                    Text(priceValue!,
                        style: TypeTokens.style(15, FontWeight.w800,
                            color: dimmed ? DesignColors.textMuted : tone.accentDark)),
                    if (priceUnit != null && priceUnit!.isNotEmpty)
                      Text(priceUnit!, style: TypeTokens.caption),
                  ],
                  if (showChevron && onTap != null)
                    Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
                ],
              )
            : null);
    return Padding(
      padding: _scaleMargin(margin),
      child: _Surface(
        onTap: onTap,
        shadow: rich ? ShadowTokens.tight(tone.accentDark) : (elevated ? ShadowTokens.elev3 : ShadowTokens.elev1),
        gradient: rich
            ? LinearGradient(colors: [DesignColors.surface, tone.wash], begin: Alignment.topCenter, end: Alignment.bottomCenter)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(compact ? 72 : minHeight)),
          child: Padding(
            padding: DS.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: trailingTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    lead,
                    SizedBox(width: DS.s(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((tag != null && tag!.isNotEmpty) || notice != null || tagBadge != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: DS.s(4)),
                              child: Wrap(
                                spacing: DS.gh(4),
                                runSpacing: DS.gv(4),
                                children: [
                                  if (tag != null && tag!.isNotEmpty) KitTagChip(tag!, tone: tone, solid: solidTag),
                                  if (tagBadge != null) tagBadge!,
                                  if (notice != null)
                                    KitTagChip(notice!, color: DesignColors.textMuted),
                                ],
                              ),
                            ),
                          Text(title,
                              maxLines: titleMaxLines ?? (compact ? 1 : 2),
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(rich ? 16 : 14, FontWeight.w700, color: titleColor, height: 1.2)),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            SizedBox(height: DS.s(2)),
                            Text(subtitle!,
                                maxLines: subtitleLines,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.caption),
                          ],
                          if (facts.isNotEmpty) ...[
                            SizedBox(height: DS.s(6)),
                            Wrap(
                              spacing: DS.gh(4),
                              runSpacing: DS.gv(4),
                              children: [for (final f in facts.take(2)) KitFactChip(f, tone: tone)],
                            ),
                          ],
                          if (body != null) ...[SizedBox(height: DS.s(6)), body!],
                        ],
                      ),
                    ),
                    if (right != null) ...[SizedBox(width: DS.s(8)), right],
                  ],
                ),
                for (final r in rows) ...[SizedBox(height: DS.s(8)), r],
                if (footer != null) ...[
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(8)),
                    child: Divider(height: 1, color: DesignColors.dividerSoft),
                  ),
                  Padding(padding: DS.insets(l: 4, t: 4, r: 4, b: 0), child: footer),
                ],
              ],
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }
}

class SlimBar extends StatelessWidget {
  const SlimBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingAsset,
    this.trailing,
    this.onTap,
    this.tone = KitTone.brand,
    this.filled = false,
    this.margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
    this.elevated = false,
  });

  final bool elevated;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? leadingAsset;
  final Widget? trailing;
  final VoidCallback? onTap;
  final KitTone tone;
  final bool filled;
  final EdgeInsets margin;

  static Widget skeleton({EdgeInsets margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6)}) =>
      Padding(
        padding: _scaleMargin(margin),
        child: _Surface(
          shadow: ShadowTokens.elev1,
          press: false,
          child: SizedBox(
            height: DS.s(56),
            child: Padding(
              padding: DS.sym(h: 12),
              child: Row(children: [
                _Bone(width: 32, height: 32, radius: 16),
                SizedBox(width: DS.s(12)),
                Expanded(child: _Bone(height: 14)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final fg = filled ? DesignColors.onPrimary : DesignColors.textStrong;
    final sub = filled ? DesignColors.whiteHigh : TypeTokens.secondary;
    final lead = leading ??
        (leadingAsset != null
            ? Container(
                width: DS.s(36),
                height: DS.s(36),
                padding: DS.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? DesignColors.whiteSoft : tone.tint,
                ),
                child: Image.asset(leadingAsset!),
              )
            : null);
    return Padding(
      padding: _scaleMargin(margin),
      child: _Surface(
        onTap: onTap,
        shadow: filled ? ShadowTokens.glow(tone.glow) : (elevated ? ShadowTokens.elev3 : ShadowTokens.elev1),
        color: filled ? Colors.transparent : DesignColors.surface,
        foreground: null,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(56)),
          decoration: filled ? BoxDecoration(gradient: tone.gradient) : null,
          padding: DS.sym(h: 12, v: 8),
          child: Row(
            children: [
              if (lead != null) ...[lead, SizedBox(width: DS.s(12))],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(14, FontWeight.w600, color: fg)),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(11, FontWeight.w500, color: sub)),
                  ],
                ),
              ),
              if (trailing != null) ...[SizedBox(width: DS.s(8)), trailing!]
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: DS.s(22), color: filled ? DesignColors.onPrimary : DesignColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTile extends StatelessWidget {
  const SectionTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.title,
    this.selected = false,
    this.tone = KitTone.brand,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final String? title;
  final bool selected;
  final KitTone tone;

  static Widget skeleton({int lines = 3, EdgeInsets margin = EdgeInsets.zero}) => Padding(
        padding: _scaleMargin(margin),
        child: _Surface(
          shadow: ShadowTokens.elev1,
          press: false,
          child: Padding(
            padding: DS.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines; i++) ...[
                  if (i > 0) SizedBox(height: DS.s(10)),
                  _Bone(height: 14, width: i == lines - 1 ? 120 : null),
                ],
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _scaleMargin(margin),
      child: _Surface(
        onTap: onTap,
        shadow: selected ? ShadowTokens.elev3 : ShadowTokens.elev1,
        foreground: selected
            ? BoxDecoration(
                borderRadius: DS.br(CardRadius.tile),
                border: Border.all(color: tone.accentDark, width: DS.s(2)))
            : null,
        child: Padding(
          padding: DS.insets(l: padding.left, t: padding.top, r: padding.right, b: padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(title!, style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong)),
                SizedBox(height: DS.s(12)),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.iconAsset,
    this.illustration,
    this.tone = KitTone.brand,
    this.onTap,
    this.selected = false,
    this.badge,
    this.cta,
    this.height = 120,
    this.subtitleLines = 2,
    this.reserveSubtitle = false,
  });

  final bool reserveSubtitle;
  final String title;
  final String? subtitle;
  final String? iconAsset;
  final Widget? illustration;
  final KitTone tone;
  final VoidCallback? onTap;
  final bool selected;
  final String? badge;
  final String? cta;
  final double height;
  final int subtitleLines;

  static Widget skeleton({double height = 120}) => _Surface(
        press: false,
        radius: CardRadius.hero,
        shadow: ShadowTokens.elev1,
        child: SizedBox(
          height: DS.s(height),
          child: Padding(
            padding: DS.all(16),
            child: Row(
              children: [
                _Bone(width: 84, height: 84, radius: 42),
                SizedBox(width: DS.s(14)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_Bone(height: 16), SizedBox(height: DS.s(8)), _Bone(height: 12, width: 120)],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final art = illustration ??
        Container(
          width: DS.s(84),
          height: DS.s(84),
          padding: DS.all(18),
          decoration: const BoxDecoration(color: DesignColors.whiteSoft, shape: BoxShape.circle),
          child: iconAsset == null ? null : Image.asset(iconAsset!),
        );
    final body = SelectionPop(
      selected: selected,
      child: _Surface(
        onTap: onTap,
        radius: CardRadius.hero,
        shadow: ShadowTokens.glow(tone.glow),
        color: Colors.transparent,
        foreground: selected
            ? BoxDecoration(
                borderRadius: DS.br(CardRadius.hero),
                border: Border.fromBorderSide(BorderSide(color: DesignColors.onPrimary, width: DS.s(3))))
            : null,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(height)),
          decoration: BoxDecoration(gradient: tone.gradient),
          child: Stack(
            children: [
              Positioned(
                right: DS.s(-28),
                bottom: DS.s(-36),
                child: Container(
                  width: DS.s(120),
                  height: DS.s(120),
                  decoration: const BoxDecoration(color: DesignColors.overlayWhiteFaint, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                right: DS.s(30),
                top: DS.s(-26),
                child: Container(
                  width: DS.s(56),
                  height: DS.s(56),
                  decoration: const BoxDecoration(color: DesignColors.overlayWhiteFaint, shape: BoxShape.circle),
                ),
              ),
              Padding(
                padding: DS.all(16),
                child: Row(
                  children: [
                    art,
                    SizedBox(width: DS.s(14)),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badge != null || reserveSubtitle)
                            Visibility(
                              visible: badge != null,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              maintainSemantics: false,
                              child: Container(
                                margin: EdgeInsets.only(bottom: DS.s(4)),
                                padding: DS.sym(h: 8, v: 2),
                                decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.pill)),
                                child: Text(badge ?? 'CURRENT',
                                    style: TypeTokens.style(10, FontWeight.w700, color: tone.accentDark, chip: true)),
                              ),
                            ),
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.onGradientTitle),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            SizedBox(height: DS.s(4)),
                            Stack(
                              children: [
                                if (reserveSubtitle)
                                  ExcludeSemantics(
                                    child: Text(List.filled(subtitleLines, ' ').join('\n'),
                                        maxLines: subtitleLines,
                                        style: TypeTokens.onGradientBody.copyWith(color: Colors.transparent)),
                                  ),
                                Text(subtitle!,
                                    maxLines: subtitleLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: TypeTokens.onGradientBody),
                              ],
                            ),
                          ],
                          if (cta != null) ...[
                            SizedBox(height: DS.s(8)),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(cta!, style: TypeTokens.style(12, FontWeight.w700, color: DesignColors.onPrimary)),
                              SizedBox(width: DS.s(4)),
                              Icon(Icons.arrow_forward_rounded, size: DS.s(16), color: DesignColors.onPrimary),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return body;
  }
}

class OwnerListingCard extends StatelessWidget {
  const OwnerListingCard({
    super.key,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.iconAsset = TravelIcon.stay,
    this.tone = KitTone.stay,
    this.status,
    this.statusColor,
    this.facts = const [],
    this.actions = const [],
    this.onTap,
    this.dimmed = false,
    this.notice,
    this.tag,
    this.margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
    this.header,
    this.body,
    this.toggle,
    this.rows = const [],
    this.strips = const [],
  });

  final Widget? header;
  final Widget? body;
  final Widget? toggle;
  final List<Widget> rows;
  final List<Widget> strips;
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final String iconAsset;
  final KitTone tone;
  final String? status;
  final Color? statusColor;
  final List<CardFact> facts;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool dimmed;
  final String? notice;
  final String? tag;
  final EdgeInsets margin;

  static Widget skeleton({EdgeInsets margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6)}) =>
      Padding(
        padding: _scaleMargin(margin),
        child: _Surface(
          shadow: ShadowTokens.elev1,
          press: false,
          child: Padding(
            padding: DS.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    _Bone(width: 72, height: 72, radius: 12),
                    SizedBox(width: DS.s(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_Bone(height: 14), SizedBox(height: DS.s(6)), _Bone(width: 110, height: 11)],
                      ),
                    ),
                    SizedBox(width: DS.s(12)),
                    _Bone(width: 56, height: 20, radius: 8),
                  ],
                ),
                SizedBox(height: DS.s(12)),
                Row(children: [_Bone(width: 88, height: 36, radius: 18), SizedBox(width: DS.s(8)), _Bone(width: 88, height: 36, radius: 18)]),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: title,
      subtitle: subtitle,
      tag: tag,
      notice: notice,
      thumbnailUrl: thumbnailUrl,
      iconAsset: iconAsset,
      tone: tone,
      facts: facts,
      onTap: onTap,
      dimmed: dimmed,
      margin: margin,
      showChevron: false,
      header: header,
      body: body,
      rows: [if (toggle != null) toggle!, ...rows, ...strips],
      trailing: status == null
          ? null
          : KitTagChip(status!, tone: tone, color: statusColor),
      footer: actions.isEmpty
          ? null
          : Wrap(spacing: DS.gh(8), runSpacing: DS.gv(0), children: actions),
    );
  }
}

class DriverOptionCard extends StatelessWidget {
  const DriverOptionCard({
    super.key,
    required this.name,
    this.vehicle,
    this.subtitle,
    this.facts = const [],
    this.fareValue,
    this.fareUnit,
    this.badge,
    this.actions = const [],
    this.onTap,
    this.tone = KitTone.taxi,
    this.avatarAsset = TravelIcon.taxi,
    this.dimmed = false,
    this.isFeatured = false,
    this.margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
    this.nameMaxLines = 1,
    this.header,
    this.selected = false,
    this.legColor,
    this.avatarInitial,
    this.avatarWidget,
  });

  final int nameMaxLines;
  final Widget? header;
  final bool selected;
  final Color? legColor;
  final String? avatarInitial;
  final Widget? avatarWidget;
  final String name;
  final String? vehicle;
  final String? subtitle;
  final List<CardFact> facts;
  final String? fareValue;
  final String? fareUnit;
  final String? badge;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final KitTone tone;
  final String avatarAsset;
  final bool dimmed;
  final bool isFeatured;
  final EdgeInsets margin;

  static Widget skeleton({EdgeInsets margin = const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6)}) =>
      Padding(
        padding: _scaleMargin(margin),
        child: _Surface(
          shadow: ShadowTokens.elev2,
          press: false,
          child: Padding(
            padding: DS.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    _Bone(width: 48, height: 48, radius: 24),
                    SizedBox(width: DS.s(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_Bone(height: 14, width: 140), SizedBox(height: DS.s(6)), _Bone(height: 11, width: 90)],
                      ),
                    ),
                    SizedBox(width: DS.s(12)),
                    _Bone(width: 56, height: 20),
                  ],
                ),
                SizedBox(height: DS.s(12)),
                Row(children: [_Bone(width: 88, height: 36, radius: 18), SizedBox(width: DS.s(8)), _Bone(width: 88, height: 36, radius: 18)]),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nameColor = dimmed ? DesignColors.textMuted : DesignColors.textStrong;
    final tone = legColor == null ? this.tone : KitTone.solid(legColor!);
    return Padding(
      padding: _scaleMargin(margin),
      child: _Surface(
        onTap: onTap,
        shadow: selected ? ShadowTokens.elev3 : ShadowTokens.elev2,
        foreground: selected
            ? BoxDecoration(
                borderRadius: DS.br(CardRadius.tile),
                border: Border.all(color: tone.accentDark, width: DS.s(2)),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null)
              Padding(padding: DS.insets(l: 12, t: 10, r: 12, b: 0), child: header),
            Padding(
          padding: DS.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: DS.s(48),
                    height: DS.s(48),
                    padding: DS.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [DesignColors.tint(tone.accent, Alpha.soft), DesignColors.tint(tone.accentDark, Alpha.tint)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: avatarWidget ??
                        (avatarInitial != null && avatarInitial!.isNotEmpty
                            ? Center(
                                child: Text(avatarInitial!,
                                    maxLines: 1,
                                    style: TypeTokens.style(18, FontWeight.w800, color: tone.accentDark)))
                            : Image.asset(avatarAsset)),
                  ),
                  SizedBox(width: DS.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null || isFeatured)
                          Padding(
                            padding: EdgeInsets.only(bottom: DS.s(4)),
                            child: Wrap(spacing: DS.gh(4), children: [
                              if (isFeatured) KitFeaturedRibbon(tone: tone),
                              if (badge != null) KitTagChip(badge!, tone: tone),
                            ]),
                          ),
                        Text(name,
                            maxLines: nameMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(14, FontWeight.w700, color: nameColor)),
                        if (vehicle != null && vehicle!.isNotEmpty)
                          Text(vehicle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
                        if (facts.isNotEmpty) ...[
                          SizedBox(height: DS.s(6)),
                          Wrap(spacing: DS.gh(4), runSpacing: DS.gv(4), children: [for (final f in facts.take(3)) KitFactChip(f, tone: tone)]),
                        ],
                      ],
                    ),
                  ),
                  if (fareValue != null && fareValue!.isNotEmpty) ...[
                    SizedBox(width: DS.s(8)),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: DS.s(MediaQuery.sizeOf(context).width < 340 ? 84 : 112)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(fareValue!,
                                maxLines: 1,
                                style: TypeTokens.style(18, FontWeight.w800,
                                    color: dimmed ? DesignColors.textMuted : tone.accentDark)),
                          ),
                          if (fareUnit != null && fareUnit!.isNotEmpty)
                            Text(fareUnit!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (actions.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(top: DS.s(8)),
                  child: Divider(height: 1, color: DesignColors.dividerSoft),
                ),
                SizedBox(height: DS.s(4)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: DS.gh(8), children: actions),
                ),
              ],
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}

class KitStatusStrip extends StatelessWidget {
  const KitStatusStrip({super.key, required this.label, this.color = DesignColors.textSecondary, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: DS.sym(h: 10, v: 8),
        decoration: BoxDecoration(color: DesignColors.tint(color, Alpha.tint), borderRadius: DS.br(KitMetrics.tileSmall)),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: DS.s(16), color: color), SizedBox(width: DS.s(6))],
            Expanded(
              child: Text(label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w600, color: color)),
            ),
          ],
        ),
      );
}

class OwnerPhotoBand extends StatelessWidget {
  const OwnerPhotoBand({
    super.key,
    this.url,
    this.tone = KitTone.stay,
    this.asset = TravelIcon.stay,
    this.height = 120,
    this.badge,
  });

  final String? url;
  final KitTone tone;
  final String asset;
  final double height;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: DS.s(height),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, c) => KitPhoto(
                url: url,
                width: c.maxWidth,
                height: DS.s(height),
                tone: tone,
                asset: asset,
                radius: BorderRadius.zero,
                iconSize: 44,
              ),
            ),
            if (badge != null) Positioned(top: DS.s(8), left: DS.s(8), child: badge!),
          ],
        ),
      );
}

class KitCardEntrance extends StatelessWidget {
  const KitCardEntrance({super.key, required this.index, required this.child, this.offset = 50});

  final int index;
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      EntranceOnce(index: index, offset: offset, child: child);
}

