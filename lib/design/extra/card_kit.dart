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

class _Bone extends StatelessWidget {
  const _Bone({this.width, this.height = 12, this.radius = 6});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      TemplatePlaceholder(width: width, height: height, radius: radius);
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
  });

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
      decoration: BoxDecoration(color: color, borderRadius: radius, boxShadow: shadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: DesignColors.splash,
          highlightColor: Colors.transparent,
          child: foreground == null
              ? child
              : DecoratedBox(decoration: foreground!, position: DecorationPosition.foreground, child: child),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: CardRadius.chip),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? c : DesignColors.tint(c, Alpha.tint),
        borderRadius: CardRadius.chip,
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
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: CardRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TravelIcon(TravelIcon.star, size: 12),
          const SizedBox(width: 3),
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
  });

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
        borderRadius: radius,
        gradient: LinearGradient(
          colors: [
            DesignColors.tint(gradient?.colors.first ?? tone.accent, Alpha.soft),
            DesignColors.tint(gradient?.colors.last ?? tone.accentDark, Alpha.tint),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: iconSize + 24,
          height: iconSize + 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.tint(DesignColors.surfaceAlt, Alpha.soft),
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
  });

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
    final fallback = PlaceholderTile(tone: tone, asset: asset, iconSize: iconSize, radius: radius, width: width, height: height);
    final longest = math.max(width.isFinite ? width : 0.0, height.isFinite ? height : 0.0) * dpr;
    final shrink = longest > maxDecodePx ? maxDecodePx / longest : 1.0;
    int? px(double v) => v.isFinite ? math.max(1, (v * dpr * shrink).round()) : null;
    final image = url == null || url!.isEmpty
        ? fallback
        : ClipRRect(
            borderRadius: radius,
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
            borderRadius: radius,
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
      const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: gridMaxExtent,
        mainAxisExtent: height,
        mainAxisSpacing: gridSpacing,
        crossAxisSpacing: gridSpacing,
      );

  static Widget skeleton({double? cardWidth}) => SizedBox(
        width: cardWidth ?? width,
        height: height,
        child: _Surface(
          press: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Bone(height: photoHeight, radius: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Bone(height: 14),
                    SizedBox(height: 6),
                    _Bone(height: 14, width: 90),
                    SizedBox(height: 8),
                    _Bone(height: 11, width: 70),
                    SizedBox(height: 8),
                    Row(children: [_Bone(height: 18, width: 44, radius: 8), SizedBox(width: 6), _Bone(height: 18, width: 44, radius: 8)]),
                    SizedBox(height: 12),
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
        const SizedBox(width: 6),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(gradient: tone.gradient, shape: BoxShape.circle),
          child: const Icon(Icons.chevron_right_rounded, size: 20, color: DesignColors.onPrimary),
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
              border: Border.all(color: tone.accentDark, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: photoHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                media ??
                    LayoutBuilder(
                      builder: (context, c) => KitPhoto(
                        url: thumbnailUrl,
                        width: c.maxWidth,
                        height: photoHeight,
                        tone: tone,
                        asset: fallbackAsset,
                        iconSize: 40,
                      ),
                    ),
                if (tagLabel != null && tagLabel!.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: KitTagChip(tagLabel!, tone: tone, solid: true),
                    ),
                  ),
                if (isFeatured)
                  Positioned(left: 8, bottom: 8, child: PlanBadgeChip(color: tone.accentDark, compact: false)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textStrong, height: 1.2)),
                  if (locationLabel != null && locationLabel!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const TravelIcon(TravelIcon.place, size: 12),
                        const SizedBox(width: 3),
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
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 22,
                      width: double.infinity,
                      child: ClipRect(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
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
  });

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
      padding: margin,
      child: _Surface(
        shadow: ShadowTokens.elev1,
        press: false,
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 8),
          child: Row(
            children: [
              _Bone(width: t, height: t, radius: 12),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bone(width: 56, height: 14, radius: 8),
                    SizedBox(height: 6),
                    _Bone(height: 14),
                    SizedBox(height: 6),
                    _Bone(width: 110, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _Bone(width: 44, height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = compact ? tileSizeCompact : tileSize;
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
            ),
            if (isFeatured)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  width: 20,
                  height: 20,
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
                    Icon(Icons.chevron_right_rounded, size: 22, color: DesignColors.textDisabled),
                ],
              )
            : null);
    return Padding(
      padding: margin,
      child: _Surface(
        onTap: onTap,
        shadow: elevated ? ShadowTokens.elev3 : ShadowTokens.elev1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 72 : minHeight),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: trailingTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    lead,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((tag != null && tag!.isNotEmpty) || notice != null || tagBadge != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
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
                              style: TypeTokens.style(14, FontWeight.w700, color: titleColor, height: 1.2)),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!,
                                maxLines: subtitleLines,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.caption),
                          ],
                          if (facts.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [for (final f in facts.take(2)) KitFactChip(f, tone: tone)],
                            ),
                          ],
                          if (body != null) ...[const SizedBox(height: 6), body!],
                        ],
                      ),
                    ),
                    if (right != null) ...[const SizedBox(width: 8), right],
                  ],
                ),
                for (final r in rows) ...[const SizedBox(height: 8), r],
                if (footer != null) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Divider(height: 1, color: DesignColors.dividerSoft),
                  ),
                  Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: footer),
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
        padding: margin,
        child: _Surface(
          shadow: ShadowTokens.elev1,
          press: false,
          child: const SizedBox(
            height: 56,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _Bone(width: 32, height: 32, radius: 16),
                SizedBox(width: 12),
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
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? DesignColors.whiteSoft : tone.tint,
                ),
                child: Image.asset(leadingAsset!),
              )
            : null);
    return Padding(
      padding: margin,
      child: _Surface(
        onTap: onTap,
        shadow: filled ? ShadowTokens.glow(tone.glow) : (elevated ? ShadowTokens.elev3 : ShadowTokens.elev1),
        color: filled ? Colors.transparent : DesignColors.surface,
        foreground: null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: filled ? BoxDecoration(gradient: tone.gradient) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
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
              if (trailing != null) ...[const SizedBox(width: 8), trailing!]
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 22, color: filled ? DesignColors.onPrimary : DesignColors.textDisabled),
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
        padding: margin,
        child: _Surface(
          shadow: ShadowTokens.elev1,
          press: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
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
      padding: margin,
      child: _Surface(
        onTap: onTap,
        shadow: selected ? ShadowTokens.elev3 : ShadowTokens.elev1,
        foreground: selected
            ? BoxDecoration(
                borderRadius: CardRadius.tile,
                border: Border.all(color: tone.accentDark, width: 2))
            : null,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(title!, style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong)),
                const SizedBox(height: 12),
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
          height: height,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _Bone(width: 84, height: 84, radius: 42),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_Bone(height: 16), SizedBox(height: 8), _Bone(height: 12, width: 120)],
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
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(18),
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
            ? const BoxDecoration(
                borderRadius: CardRadius.hero,
                border: Border.fromBorderSide(BorderSide(color: DesignColors.onPrimary, width: 3)))
            : null,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(gradient: tone.gradient),
          child: Stack(
            children: [
              Positioned(
                right: -28,
                bottom: -36,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(color: DesignColors.overlayWhiteFaint, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                right: 30,
                top: -26,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: DesignColors.overlayWhiteFaint, shape: BoxShape.circle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    art,
                    const SizedBox(width: 14),
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
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.pill),
                                child: Text(badge ?? 'CURRENT',
                                    style: TypeTokens.style(10, FontWeight.w700, color: tone.accentDark, chip: true)),
                              ),
                            ),
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.onGradientTitle),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
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
                            const SizedBox(height: 8),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(cta!, style: TypeTokens.style(12, FontWeight.w700, color: DesignColors.onPrimary)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: DesignColors.onPrimary),
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
        padding: margin,
        child: _Surface(
          shadow: ShadowTokens.elev1,
          press: false,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    _Bone(width: 72, height: 72, radius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_Bone(height: 14), SizedBox(height: 6), _Bone(width: 110, height: 11)],
                      ),
                    ),
                    SizedBox(width: 12),
                    _Bone(width: 56, height: 20, radius: 8),
                  ],
                ),
                SizedBox(height: 12),
                Row(children: [_Bone(width: 88, height: 36, radius: 18), SizedBox(width: 8), _Bone(width: 88, height: 36, radius: 18)]),
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
          : Wrap(spacing: 8, runSpacing: 0, children: actions),
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
        padding: margin,
        child: _Surface(
          shadow: ShadowTokens.elev2,
          press: false,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    _Bone(width: 48, height: 48, radius: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_Bone(height: 14, width: 140), SizedBox(height: 6), _Bone(height: 11, width: 90)],
                      ),
                    ),
                    SizedBox(width: 12),
                    _Bone(width: 56, height: 20),
                  ],
                ),
                SizedBox(height: 12),
                Row(children: [_Bone(width: 88, height: 36, radius: 18), SizedBox(width: 8), _Bone(width: 88, height: 36, radius: 18)]),
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
      padding: margin,
      child: _Surface(
        onTap: onTap,
        shadow: selected ? ShadowTokens.elev3 : ShadowTokens.elev2,
        foreground: selected
            ? BoxDecoration(
                borderRadius: CardRadius.tile,
                border: Border.all(color: tone.accentDark, width: 2),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null)
              Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: header),
            Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(10),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null || isFeatured)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Wrap(spacing: 4, children: [
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
                          const SizedBox(height: 6),
                          Wrap(spacing: 4, runSpacing: 4, children: [for (final f in facts.take(3)) KitFactChip(f, tone: tone)]),
                        ],
                      ],
                    ),
                  ),
                  if (fareValue != null && fareValue!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width < 340 ? 84 : 112),
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
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Divider(height: 1, color: DesignColors.dividerSoft),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 8, children: actions),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: DesignColors.tint(color, Alpha.tint), borderRadius: KitMetrics.tileSmall),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
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
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, c) => KitPhoto(
                url: url,
                width: c.maxWidth,
                height: height,
                tone: tone,
                asset: asset,
                radius: BorderRadius.zero,
                iconSize: 44,
              ),
            ),
            if (badge != null) Positioned(top: 8, left: 8, child: badge!),
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

