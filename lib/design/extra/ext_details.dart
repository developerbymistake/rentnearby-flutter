import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/photo_url.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/listing_palette.dart';
import '../tokens/shadow_tokens.dart';
import 'art_3d.dart';
import 'calm_card_kit.dart';
import 'pill_buttons_3d.dart';
import 'skeleton_3d.dart';
import 'template_motion.dart';
import 'whatsapp_glyph.dart';

abstract final class DetailArt {
  static const String automobile = 'assets/images/design/travel3d/automobile.png';
  static const String droplet = 'assets/images/design/travel3d/droplet.png';
}

abstract final class DetailLook {
  static const Color glass = Color(0xE6FFFFFF);
  static const Color darkGlass = Color(0x5217262A);
  static const Color darkGlassStrong = Color(0x8C17262A);
  static const Color backFill = DesignColors.scaffold;
  static const Color hiddenFill = Color(0xFFECEDF1);
  static const Color hiddenText = Color(0xFF6A6A6A);
  static const Color reportFill = Color(0xFFFDECEC);
  static const Color reportText = Color(0xFFD64545);
  static const Color reportLine = Color(0x59D64545);
  static const Color reportedFill = Color(0xFFF4F5F8);
  static const Color reportedText = Color(0xFF9A9A9A);
  static const Color reportedLine = Color(0xFFE3E5EA);
  static const Color reportedDot = Color(0xFFC9CCD3);
  static const Color dotOff = Color(0x8CFFFFFF);
  static const Color scrimTop = Color(0x73000000);
  static const Color heroHalo = Color(0x38FFFFFF);
  static const Color cardHalo = Color(0x33FFFFFF);
  static const Color slimHalo = Color(0x3DFAFAFA);
  static const Color tileGlow = Color(0x40000000);
  static List<BoxShadow> get glassShadow => DS.shadows(const [BoxShadow(color: Color(0x33000000), offset: Offset(3, 5), blurRadius: 10)]);
  static List<BoxShadow> get backShadow => DS.shadows(const [BoxShadow(color: Color(0x669E9E9E), offset: Offset(3, 5), blurRadius: 10)]);
  static List<BoxShadow> get barShadow => DS.shadows(const [BoxShadow(color: Color(0x24000000), offset: Offset(0, -4), blurRadius: 18)]);
  static List<BoxShadow> get topBarShadow => DS.shadows(const [BoxShadow(color: Color(0x1F000000), offset: Offset(0, 2), blurRadius: 12)]);
  static List<BoxShadow> get whiteCard => DS.shadows(const [BoxShadow(color: Color(0x339E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)]);
  static const Color noteCream = Color(0xFFFFF1DE);
  static const Color noteInk = Color(0xFF6A4A1A);
  static List<BoxShadow> get noteCard => DS.shadows(const [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)]);
  static List<BoxShadow> get callDot => DS.shadows(const [BoxShadow(color: Color(0x33000000), offset: Offset(2, 3), blurRadius: 5)]);

  static final ListingTone chipCoral = ListingTone(
    g1: const Color(0xFFF2646B),
    g2: const Color(0xFFD9434D),
    shadow: const Color(0x99D9434D),
    haloBase: const Color(0xFFD9434D),
    text: const Color(0xFFB83A40),
  );
  static final ListingTone chipOrange = ListingTone(
    g1: const Color(0xFFFFA040),
    g2: const Color(0xFFE66A12),
    shadow: const Color(0x80E66A12),
    haloBase: const Color(0xFFE66A12),
    text: const Color(0xFFB85000),
  );

  static ListingTone card(ListingTone t) {
    if (identical(t, ListingTone.cA)) return chipCoral;
    if (identical(t, ListingTone.cF)) return chipOrange;
    return t;
  }

  static Color wash(ListingTone t, double a) => t.haloBase.withValues(alpha: a);

  static BorderRadius get r68 => DS.br(CardRadius.hero);
  static BorderRadius get r54 => DS.br(CardRadius.hero);
  static BorderRadius get r40 => DS.br(CardRadius.hero);
  static BorderRadius get r32 => DS.br(CardRadius.tile);
  static BorderRadius get r30 => DS.br(CardRadius.tile);
  static BorderRadius get r24 => DS.br(CardRadius.tile);

  static bool narrow(BuildContext context) => MediaQuery.sizeOf(context).width < 340;

  static BoxDecoration calmCard(ListingPalette p, {BorderRadius? radius}) => CalmCard.box(p, radius: radius);

  static ListingPalette paletteOf(ListingTone t) {
    if (identical(t, ListingTone.coral)) return ListingPalette.coral;
    if (identical(t, ListingTone.indigo)) return ListingPalette.indigo;
    return ListingPalette.forest;
  }

  static Color get secondary => DesignColors.textSecondaryHigh;

  static TextStyle calmText(double size, FontWeight weight, Color color, {double? height}) => Ink3D.text(size, weight, color, height: height, letterSpacing: 0);
}

class DetailGlassButton extends StatelessWidget {
  const DetailGlassButton({super.key, required this.onTap, this.dark = false, this.strong = false, this.solid = false});

  final VoidCallback? onTap;
  final bool dark;
  final bool strong;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fill = solid ? Colors.white : (dark ? (strong ? DetailLook.darkGlassStrong : DetailLook.darkGlass) : DetailLook.glass);
    return Tooltip(
      message: 'Back',
      child: Tap3D(
        onTap: onTap,
        label: 'Back',
        exclude: true,
        child: Container(
          width: DS.s(44),
          height: DS.s(44),
          decoration: BoxDecoration(shape: BoxShape.circle, color: fill, boxShadow: dark ? null : (solid ? DetailLook.backShadow : DetailLook.glassShadow)),
          child: Icon(Icons.chevron_left_rounded, size: DS.s(30), color: dark ? Colors.white : Ink3D.title),
        ),
      ),
    );
  }
}

class DetailSharePill extends StatelessWidget {
  const DetailSharePill({super.key, required this.tone, required this.onTap, this.dark = false, this.height = 44});

  final ListingTone tone;
  final VoidCallback? onTap;
  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : tone.text;
    return Tap3D(
      onTap: onTap,
      label: 'Share',
      exclude: true,
      child: Container(
        height: DS.s(height),
        padding: DS.sym(h: 16),
        decoration: BoxDecoration(
          color: dark ? DetailLook.darkGlass : DetailLook.glass,
          borderRadius: BorderRadius.circular(DS.s(height) / 2),
          boxShadow: dark ? null : DetailLook.glassShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share_rounded, size: DS.s(18), color: ink),
            SizedBox(width: DS.s(6)),
            Text('Share', maxLines: 1, textScaler: _capScale(context, 1.2), style: Ink3D.text(14, FontWeight.w700, ink)),
          ],
        ),
      ),
    );
  }
}

TextScaler _capScale(BuildContext context, double max) => MediaQuery.textScalerOf(context).clamp(maxScaleFactor: max);

class DetailHeroArt extends StatelessWidget {
  const DetailHeroArt({super.key, required this.tone, required this.art, this.photoUrl});

  final ListingTone tone;
  final String art;
  final String? photoUrl;

  Widget _art() => DecoratedBox(
    decoration: BoxDecoration(gradient: tone.gradient),
    child: Padding(
      padding: EdgeInsets.only(top: DS.s(20)),
      child: Center(
        child: ExcludeSemantics(
          child: Art3D(asset: art, size: 168, halo: 196, haloColor: DetailLook.heroHalo, shadowBlur: 10, shadowOffset: const Offset(8, 12), shadowAlpha: 0.3),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = PhotoUrl.parse(photoUrl);
    if (url == null) return _art();
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
          placeholder: (ctx, u) => const TemplatePlaceholder(height: double.infinity, radius: 0),
          errorWidget: (ctx, u, err) => _art(),
        ),
        const Positioned(top: 0, left: 0, right: 0, child: DetailTopScrim()),
      ],
    );
  }
}

class DetailPhotoDots extends StatelessWidget {
  const DetailPhotoDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: DS.sym(h: 3),
            width: DS.s(i == index ? 20 : 6),
            height: DS.s(6),
            decoration: BoxDecoration(color: i == index ? Colors.white : DetailLook.dotOff, borderRadius: DS.circular(3)),
          ),
      ],
    );
  }
}

class DetailTopScrim extends StatelessWidget {
  const DetailTopScrim({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DetailLook.scrimTop, Color(0x00000000)]),
      ),
      child: SizedBox(height: DS.s(130), width: double.infinity),
    ),
  );
}

class DetailEdge extends StatelessWidget {
  const DetailEdge({super.key, required this.page});

  final Color page;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      height: DS.s(26),
      decoration: BoxDecoration(
        color: page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(26))),
      ),
    ),
  );
}

class DetailTopBar extends StatelessWidget {
  const DetailTopBar({super.key, required this.tone, required this.onBack, this.title, this.onShare, this.coloured = false, this.showBackground = true});

  final ListingTone tone;
  final VoidCallback? onBack;
  final String? title;
  final VoidCallback? onShare;
  final bool coloured;
  final bool showBackground;

  static double heightOf(BuildContext context) => MediaQuery.paddingOf(context).top + DS.s(64);

  @override
  Widget build(BuildContext context) {
    final back = coloured
        ? DetailGlassButton(onTap: onBack, dark: true)
        : Tooltip(
            message: 'Back',
            child: Tap3D(
              onTap: onBack,
              label: 'Back',
              exclude: true,
              child: Container(
                width: DS.s(44),
                height: DS.s(44),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: DetailLook.backFill),
                child: Icon(Icons.chevron_left_rounded, size: DS.s(30), color: Ink3D.title),
              ),
            ),
          );
    Widget? share;
    if (onShare != null) {
      share = coloured
          ? DetailSharePill(tone: tone, onTap: onShare, dark: true)
          : Tooltip(
              message: 'Share',
              child: Tap3D(
                onTap: onShare,
                label: 'Share',
                exclude: true,
                child: SizedBox(width: DS.s(44), height: DS.s(44), child: Icon(Icons.ios_share_rounded, size: DS.s(20), color: tone.text)),
              ),
            );
    }
    final reduce = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      height: heightOf(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: showBackground ? 1 : 0,
              duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: coloured ? null : Colors.white,
                  gradient: coloured ? tone.gradient : null,
                  boxShadow: coloured ? null : DetailLook.topBarShadow,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(DS.s(14), MediaQuery.paddingOf(context).top, DS.s(14), 0),
            child: Row(
              children: [
                back,
                Gap.h(12),
                Expanded(
                  child: title == null
                      ? const SizedBox.shrink()
                      : Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: _capScale(context, 1.2),
                          style: Ink3D.text(18, FontWeight.w700, Ink3D.title, letterSpacing: 0),
                        ),
                ),
                if (share != null) ...[Gap.h(8), share],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailTitleCard extends StatelessWidget {
  const DetailTitleCard({
    super.key,
    required this.tone,
    required this.eyebrow,
    required this.title,
    required this.caption,
    required this.value,
    this.unit,
    this.compact = false,
    this.was,
    this.chip,
    this.place,
  });

  final ListingTone tone;
  final String eyebrow;
  final String title;
  final String caption;
  final String value;
  final String? unit;
  final bool compact;
  final String? was;
  final String? chip;
  final String? place;

  static const double topRoom = 26;
  static const double priceShare = 0.45;

  @override
  Widget build(BuildContext context) {
    final p = DetailLook.paletteOf(tone);
    final sub = DetailLook.secondary;
    final where = place?.trim() ?? '';
    final u = unit ?? '';
    final w = was ?? '';
    final c = chip ?? '';
    return Padding(
      padding: DS.insets(l: 18, t: topRoom, r: 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: DS.insets(l: 18, t: 16, r: 0, b: 16),
            decoration: DetailLook.calmCard(p, radius: DS.br(CardRadius.hero)),
            child: LayoutBuilder(
              builder: (context, box) {
                final maxPrice = box.maxWidth * priceShare;
                final minPrice = DS.s(120) < maxPrice ? DS.s(120) : maxPrice;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalmChip(eyebrow, palette: p, kind: CalmChipKind.tag, fg: p.text),
                          Gap.v(6),
                          _FitTitle(title: title, style: DetailLook.calmText(compact ? 18 : 22, FontWeight.w700, DesignColors.textStrong, height: 1.15)),
                          if (where.isNotEmpty) ...[
                            Gap.v(3),
                            Row(
                              children: [
                                const ExcludeSemantics(child: Art3D(asset: ListingArt.roundPushpin, size: 17, shadowBlur: 0, shadowAlpha: 0)),
                                Gap.h(5),
                                Flexible(
                                  child: Text(where, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: DetailLook.calmText(12, FontWeight.w500, sub)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Gap.h(12),
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: minPrice, maxWidth: maxPrice),
                      child: Container(
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: p.line))),
                        padding: DS.sym(h: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, sub, letterSpacing: 0.6)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(value, maxLines: 1, softWrap: false, style: DetailLook.calmText(30, FontWeight.w500, p.text, height: 1.1)),
                            ),
                            if (u.isNotEmpty) Text(u, maxLines: 1, overflow: TextOverflow.ellipsis, style: DetailLook.calmText(13, FontWeight.w400, sub)),
                            if (w.isNotEmpty)
                              Text(
                                w,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DetailLook.calmText(13, FontWeight.w500, sub).copyWith(decoration: TextDecoration.lineThrough),
                              ),
                            if (c.isNotEmpty) ...[
                              Gap.v(4),
                              CalmChip(c, palette: p, kind: CalmChipKind.solid),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            right: DS.s(12),
            top: DS.s(-30),
            child: const ExcludeSemantics(
              child: Art3D(asset: ListingArt.moneyBag, size: 60, shadowBlur: 4, shadowOffset: Offset(3, 5), shadowAlpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitTitle extends StatelessWidget {
  const _FitTitle({required this.title, required this.style});

  final String title;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final base = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        var widest = 0.0;
        for (final word in title.split(' ')) {
          final p = TextPainter(text: TextSpan(text: word, style: style), maxLines: 1, textDirection: TextDirection.ltr, textScaler: base)..layout();
          if (p.width > widest) widest = p.width;
          p.dispose();
        }
        final fit = widest > box.maxWidth && widest > 0 ? box.maxWidth / widest * 0.97 : 1.0;
        final scaler = fit < 1 ? TextScaler.linear(base.scale(1) * fit) : base;
        return Text(title, maxLines: 4, overflow: TextOverflow.ellipsis, textScaler: scaler, style: style);
      },
    );
  }
}

class DetailSlimCard extends StatelessWidget {
  const DetailSlimCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.subtitle,
    required this.price,
    this.unit,
    this.was,
    this.tag,
    this.highlight = false,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? subtitle;
  final String price;
  final String? unit;
  final String? was;
  final String? tag;
  final bool highlight;

  static const double priceMax = 104;

  @override
  Widget build(BuildContext context) {
    final p = DetailLook.paletteOf(tone);
    final sub = DetailLook.secondary;
    final st = subtitle?.trim() ?? '';
    final tg = tag?.trim() ?? '';
    final u = unit ?? '';
    final w = was ?? '';
    final small = tg.isNotEmpty;
    final circle = DS.s(small ? 58 : 66);
    final base = DetailLook.calmCard(p);
    return Padding(
      padding: DS.insets(l: 18, t: 14, r: 18),
      child: Container(
        width: double.infinity,
        padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
        decoration: highlight ? base.copyWith(border: Border.all(color: p.g2, width: DS.s(1.5))) : base,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Container(
                width: circle,
                height: circle,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.tint(p.g2, Alpha.tint)),
                child: Art3D(asset: art, size: small ? 40 : 48),
              ),
            ),
            Gap.h(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: DetailLook.calmText(16, FontWeight.w700, DesignColors.textStrong, height: 1.2)),
                  if (st.isNotEmpty) ...[
                    Gap.v(2),
                    Text(st, maxLines: 2, overflow: TextOverflow.ellipsis, style: DetailLook.calmText(13, FontWeight.w500, sub, height: 1.4)),
                  ],
                  if (tg.isNotEmpty) ...[
                    Gap.v(5),
                    CalmChip(tg, palette: p, kind: CalmChipKind.tag, fg: p.text),
                  ],
                ],
              ),
            ),
            Gap.h(12),
            Container(
              constraints: BoxConstraints(maxWidth: DS.s(priceMax)),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: p.line))),
              padding: EdgeInsets.only(left: DS.s(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(price, maxLines: 1, softWrap: false, style: DetailLook.calmText(22, FontWeight.w600, p.text, height: 1.1)),
                  ),
                  if (u.isNotEmpty) Text(u, maxLines: 1, softWrap: false, style: DetailLook.calmText(12, FontWeight.w400, sub)),
                  if (w.isNotEmpty)
                    Text(
                      w,
                      maxLines: 1,
                      softWrap: false,
                      style: DetailLook.calmText(12, FontWeight.w500, sub).copyWith(decoration: TextDecoration.lineThrough),
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

class DetailInfo {
  const DetailInfo(this.art, this.label, this.value);

  final String art;
  final String label;
  final String value;
}

class DetailInfoCard extends StatelessWidget {
  const DetailInfoCard({super.key, required this.tone, required this.rows, this.top = 26});

  final ListingTone tone;
  final List<DetailInfo> rows;
  final double top;

  @override
  Widget build(BuildContext context) {
    final p = DetailLook.paletteOf(tone);
    final sub = DetailLook.secondary;
    return Container(
      margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(top), DS.s(18), 0),
      clipBehavior: Clip.antiAlias,
      decoration: DetailLook.calmCard(p),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: DS.insets(l: 16, t: 12, r: 16, b: 12),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: p.line)),
              ),
              child: MergeSemantics(
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Art3D(asset: rows[i].art, size: 46, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.2),
                    ),
                    Gap.h(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].label, style: DetailLook.calmText(11.5, FontWeight.w500, sub)),
                          Text(
                            rows[i].value.isEmpty ? '-' : rows[i].value,
                            style: DetailLook.calmText(15.5, FontWeight.w500, DesignColors.textStrong, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DetailChipItem {
  const DetailChipItem({required this.art, required this.label, this.value});

  final String art;
  final String label;
  final String? value;
}

class DetailChipGrid extends StatelessWidget {
  const DetailChipGrid({super.key, required this.tone, required this.items, this.rules = false});

  final ListingTone tone;
  final List<DetailChipItem> items;
  final bool rules;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final p = DetailLook.paletteOf(tone);
    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth - DS.s(36);
        final col = (inner - DS.gh(12)) / 2;
        final textRoom = col - DS.s(rules ? 78 : 64);
        final cols = textRoom < DS.s(rules ? 64 : 60) * scale ? 1 : 2;
        final cells = [for (final it in items) rules ? _RuleTile(item: it, palette: p) : _FacilityChip(item: it, palette: p)];
        final rows = <Widget>[];
        for (var i = 0; i < cells.length; i += cols) {
          final slice = cells.sublist(i, (i + cols).clamp(0, cells.length));
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: DS.gv(i == 0 ? 0 : 12)),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) Gap.h(12),
                      Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: DS.sym(h: 18),
          child: Column(children: rows),
        );
      },
    );
  }
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.item, required this.palette});

  final DetailChipItem item;
  final ListingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(44)),
      alignment: Alignment.centerLeft,
      padding: DS.insets(l: 12, t: 10, r: 12, b: 10),
      decoration: DetailLook.calmCard(palette, radius: DS.circular(14)),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Art3D(asset: item.art, size: 32, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.2),
          ),
          Gap.h(8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(item.label, maxLines: 1, style: DetailLook.calmText(13.5, FontWeight.w700, DesignColors.textStrong, height: 1.25)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.item, required this.palette});

  final DetailChipItem item;
  final ListingPalette palette;

  @override
  Widget build(BuildContext context) {
    final v = item.value ?? '';
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(64)),
      alignment: Alignment.centerLeft,
      padding: DS.insets(l: 14, t: 12, r: 14, b: 12),
      decoration: DetailLook.calmCard(palette),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: item.art, size: 40)),
          Gap.h(10),
          Expanded(
            child: MergeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(item.label, maxLines: 1, style: DetailLook.calmText(11.5, FontWeight.w500, DetailLook.secondary)),
                  ),
                  Text(
                    v.isEmpty ? '-' : v,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DetailLook.calmText(16, FontWeight.w700, DesignColors.textStrong, height: 1.25),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailAboutCard extends StatelessWidget {
  const DetailAboutCard({super.key, required this.text, this.tone});

  final String text;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: DS.sym(h: 18),
    padding: DS.insets(l: 18, t: 16, r: 18, b: 16),
    decoration: DetailLook.calmCard(DetailLook.paletteOf(tone ?? ListingTone.forest)),
    child: Text(text, style: DetailLook.calmText(14, FontWeight.w400, Ink3D.sub, height: 1.6)),
  );
}

class DetailPosted extends StatelessWidget {
  const DetailPosted({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(DS.s(22), DS.gv(20), DS.s(22), 0),
    child: Row(
      children: [
        const ExcludeSemantics(
          child: Art3D(asset: ListingArt.calendar, size: 28, shadowBlur: 2, shadowOffset: Offset(2, 3), shadowAlpha: 0.25),
        ),
        SizedBox(width: DS.s(8)),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
        ),
      ],
    ),
  );
}

class DetailHiddenBanner extends StatelessWidget {
  const DetailHiddenBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(18), DS.s(18), 0),
    padding: DS.sym(h: 16, v: 11),
    decoration: BoxDecoration(color: DetailLook.hiddenFill, borderRadius: DS.circular(24)),
    child: Row(
      children: [
        const ExcludeSemantics(
          child: Art3D(asset: ListingArt.pushpin, size: 24, shadowBlur: 2, shadowOffset: Offset(1, 2), shadowAlpha: 0.2),
        ),
        SizedBox(width: DS.s(8)),
        Expanded(child: Text(text, style: Ink3D.text(13, FontWeight.w600, DetailLook.hiddenText, letterSpacing: 0))),
      ],
    ),
  );
}

class DetailStateView extends StatelessWidget {
  const DetailStateView({super.key, required this.tone, required this.art, required this.title, this.message, this.actionLabel, this.onAction});

  final ListingTone tone;
  final String art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    final button = SizedBox(
      width: DS.s(220),
      child: _BarButton.primary(tone: tone, label: actionLabel ?? ' ', onTap: onAction, height: 52),
    );
    return Center(
      child: SingleChildScrollView(
        padding: DS.sym(h: 24, v: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Art3D(
                asset: art,
                size: 176,
                halo: 200,
                haloColor: DetailLook.wash(tone, 0.16),
                shadowBlur: 10,
                shadowOffset: const Offset(8, 12),
                shadowAlpha: 0.25,
              ),
            ),
            Gap.v(32),
            Text(title, textAlign: TextAlign.center, style: Ink3D.text(24, FontWeight.w700, Ink3D.title, height: 1.25, letterSpacing: 0)),
            Gap.v(6),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(22)),
              child: Text(message ?? '', textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
            ),
            Gap.v(24),
            if (hasAction)
              button
            else
              ExcludeSemantics(
                child: IgnorePointer(child: Opacity(opacity: 0, child: button)),
              ),
          ],
        ),
      ),
    );
  }
}

class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key, required this.heroHeight, this.taxi = false});

  final double heroHeight;
  final bool taxi;

  Widget _bone(double h, BorderRadius r, EdgeInsets m, {double? w}) => Padding(
    padding: EdgeInsets.fromLTRB(DS.s(m.left), DS.gv(m.top), DS.s(m.right), DS.gv(m.bottom)),
    child: ClipRRect(
      borderRadius: r,
      child: SkeletonBox(height: DS.s(h), width: w == null ? null : DS.s(w), radius: 0),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: heroHeight, radius: 0),
          _bone(152, DetailLook.r68, const EdgeInsets.fromLTRB(18, 30, 18, 0)),
          if (taxi) ...[
            _bone(140, DetailLook.r40, const EdgeInsets.fromLTRB(18, 22, 18, 0)),
            _bone(120, DetailLook.r54, const EdgeInsets.fromLTRB(18, 22, 18, 0)),
          ] else ...[
            _bone(88, DetailLook.r54, const EdgeInsets.fromLTRB(18, 22, 18, 0)),
            _bone(88, DetailLook.r54, const EdgeInsets.fromLTRB(18, 22, 18, 0)),
            _bone(14, DS.circular(6), const EdgeInsets.fromLTRB(22, 16, 22, 0)),
            _bone(14, DS.circular(6), const EdgeInsets.fromLTRB(22, 16, 22, 0), w: 200),
          ],
        ],
      ),
    );
  }
}

class GettingThereHeader extends StatelessWidget {
  const GettingThereHeader({super.key, required this.tone, required this.label, this.onSeeAll});

  final ListingTone tone;
  final String label;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: DS.sym(h: 18),
      padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
      decoration: DetailLook.calmCard(ListingPalette.forest),
      child: Row(
        children: [
          const ExcludeSemantics(child: Art3D(asset: ListingArt.taxi, size: 52)),
          Gap.h(14),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DetailLook.calmText(14.5, FontWeight.w600, DesignColors.textStrong, height: 1.35),
            ),
          ),
          if (onSeeAll != null) ...[
            SizedBox(width: DS.s(6)),
            Tap3D(
              onTap: onSeeAll,
              label: 'See all',
              exclude: true,
              child: SizedBox(
                height: DS.s(44),
                child: Center(child: Text('See all ›', maxLines: 1, style: Ink3D.text(13, FontWeight.w700, tone.text, letterSpacing: 0))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GettingThereNote extends StatelessWidget {
  const GettingThereNote({super.key, required this.tone, required this.art, required this.text, this.caption, this.actionLabel, this.onAction});

  final ListingTone tone;
  final String art;
  final String text;
  final String? caption;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final live = actionLabel != null && onAction != null;
    final pill = Tap3D(
      onTap: live ? onAction : null,
      label: live ? actionLabel : null,
      exclude: true,
      child: Container(
        padding: DS.sym(h: 14, v: 8),
        decoration: BoxDecoration(
          gradient: tone.gradient,
          borderRadius: DS.circular(18),
          boxShadow: live ? DS.shadows(Form3D.glow(tone, offset: const Offset(1.1, 3), blur: 8)) : null,
        ),
        child: Text(actionLabel ?? 'Retry', maxLines: 1, style: Ink3D.text(13, FontWeight.w700, Colors.white, letterSpacing: 0)),
      ),
    );
    return Container(
      margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(16), DS.s(18), 0),
      constraints: BoxConstraints(minHeight: DS.s(112)),
      padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
      decoration: DetailLook.calmCard(ListingPalette.forest),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 52)),
          Gap.h(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (caption != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: DS.gv(4)),
                    child: Text(caption!, maxLines: 2, overflow: TextOverflow.ellipsis, style: DetailLook.calmText(13, FontWeight.w600, DesignColors.textStrong, height: 1.35)),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: DS.s(38)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: DetailLook.calmText(13, FontWeight.w400, Ink3D.sub, height: 1.45),
                    ),
                  ),
                ),
                SizedBox(height: DS.s(8)),
                if (live)
                  pill
                else
                  ExcludeSemantics(
                    child: IgnorePointer(child: Opacity(opacity: 0, child: pill)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailBarShell extends StatelessWidget {
  const DetailBarShell({super.key, required this.tone, required this.safety, required this.children, required this.bottomInset, this.safetyArt, this.calm = false});

  final String? safetyArt;
  final ListingTone tone;
  final String safety;
  final List<Widget> children;
  final double bottomInset;
  final bool calm;

  Widget _calm() {
    final line = safety.trim();
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), DS.s(16) + bottomInset),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(const BorderRadius.vertical(top: Radius.circular(24))),
        boxShadow: DetailLook.barShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (line.isNotEmpty) ...[
            Text(line, textAlign: TextAlign.center, style: DetailLook.calmText(11, FontWeight.w400, DetailLook.secondary, height: 1.4)),
            Gap.v(10),
          ],
          for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.v(10), children[i]],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (calm) return _calm();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(32))),
        boxShadow: DetailLook.barShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (safetyArt != null)
            Container(
              color: DetailLook.noteCream,
              padding: DS.sym(h: 18, v: 10),
              child: Row(
                children: [
                  ExcludeSemantics(child: Image.asset(safetyArt!, width: DS.s(30), height: DS.s(30), fit: BoxFit.contain)),
                  SizedBox(width: DS.s(10)),
                  Expanded(child: Text(safety, style: Ink3D.text(12.5, FontWeight.w500, DetailLook.noteInk, height: 1.35, letterSpacing: 0))),
                ],
              ),
            )
          else
          Container(
            color: DetailLook.wash(tone, 0.13),
            padding: DS.sym(h: 22, v: 7),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: DS.s(4)),
                      child: Icon(Icons.info_outline_rounded, size: DS.s(12), color: Ink3D.body),
                    ),
                  ),
                  TextSpan(text: safety),
                ],
              ),
              textAlign: TextAlign.center,
              style: Ink3D.text(11, FontWeight.w400, Ink3D.body, height: 1.4, letterSpacing: 0),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(safetyArt != null ? 12 : 10), DS.s(18), DS.s(safetyArt != null ? 10 : 20) + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.v(8), children[i]],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailBarRow extends StatelessWidget {
  const DetailBarRow({super.key, required this.children, this.calm = false});

  final List<Widget> children;
  final bool calm;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.h(calm ? 10 : 8), Expanded(child: children[i])],
        ],
      );
}

enum DetailCalmKind { tint, whatsApp, report, reported }

class DetailCalmButton extends StatelessWidget {
  const DetailCalmButton({super.key, required this.kind, required this.palette, required this.label, this.onTap, this.icon, this.iconColor});

  final DetailCalmKind kind;
  final ListingPalette palette;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? iconColor;

  static const double height = 44;
  static const double reportHeight = 42;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final Color ink;
    final BoxDecoration deco;
    final report = kind == DetailCalmKind.report || kind == DetailCalmKind.reported;
    final radius = DS.circular(22);
    switch (kind) {
      case DetailCalmKind.tint:
        ink = p.text;
        deco = BoxDecoration(color: p.button, borderRadius: radius);
      case DetailCalmKind.whatsApp:
        ink = DesignColors.onPrimary;
        deco = BoxDecoration(gradient: p.gradient, borderRadius: radius, boxShadow: DS.shadows(ShadowTokens.tight(p.shadow)));
      case DetailCalmKind.report:
        ink = p.text;
        deco = BoxDecoration(color: DesignColors.surface, borderRadius: radius, border: Border.all(color: p.line, width: DS.s(1.5)));
      case DetailCalmKind.reported:
        ink = DetailLook.reportedText;
        deco = BoxDecoration(color: DetailLook.reportedFill, borderRadius: radius, border: Border.all(color: DetailLook.reportedLine, width: DS.s(1.5)));
    }
    final Widget? lead = switch (kind) {
      DetailCalmKind.whatsApp => WhatsAppGlyph(size: 18, color: DesignColors.onPrimary, onColor: p.g2),
      DetailCalmKind.report || DetailCalmKind.reported => Icon(Icons.flag_rounded, size: DS.s(16), color: ink),
      DetailCalmKind.tint => icon == null ? null : Icon(icon, size: DS.s(18), color: iconColor ?? ink),
    };
    final body = Container(
      height: DS.s(report ? reportHeight : height),
      decoration: deco,
      padding: DS.sym(h: 12),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lead != null) ...[ExcludeSemantics(child: lead), Gap.h(7)],
            Text(label, maxLines: 1, style: DetailLook.calmText(15, FontWeight.w700, ink)),
          ],
        ),
      ),
    );
    if (kind == DetailCalmKind.reported) {
      return Semantics(button: true, enabled: false, label: label, excludeSemantics: true, child: body);
    }
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: onTap == null ? Opacity(opacity: Alpha.v60, child: body) : body,
    );
  }
}

enum _BarKind { primary, outline, report, reported }

class DetailBarButton extends StatelessWidget {
  const DetailBarButton._(this._kind, {required this.tone, required this.label, required this.onTap, this.art, this.icon, this.stacked = false});

  const DetailBarButton.primary({required ListingTone tone, required String label, required VoidCallback? onTap, String? art, IconData? icon, bool stacked = false})
    : this._(_BarKind.primary, tone: tone, label: label, onTap: onTap, art: art, icon: icon, stacked: stacked);
  const DetailBarButton.outline({required ListingTone tone, required String label, required VoidCallback? onTap, String? art, IconData? icon, bool stacked = false})
    : this._(_BarKind.outline, tone: tone, label: label, onTap: onTap, art: art, icon: icon, stacked: stacked);
  const DetailBarButton.report({required ListingTone tone, required String label, required VoidCallback? onTap})
    : this._(_BarKind.report, tone: tone, label: label, onTap: onTap, icon: Icons.flag_rounded);
  const DetailBarButton.reported({required ListingTone tone, required String label})
    : this._(_BarKind.reported, tone: tone, label: label, onTap: null, icon: Icons.flag_rounded);

  final _BarKind _kind;
  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final String? art;
  final IconData? icon;
  final bool stacked;

  @override
  Widget build(BuildContext context) => _BarButton(kind: _kind, tone: tone, label: label, onTap: onTap, art: art, icon: icon, stacked: stacked);
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.kind, required this.tone, required this.label, required this.onTap, this.art, this.icon, this.stacked = false}) : height = null;

  const _BarButton.primary({required this.tone, required this.label, required this.onTap, this.height}) : kind = _BarKind.primary, art = null, icon = null, stacked = false;

  final _BarKind kind;
  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final String? art;
  final IconData? icon;
  final bool stacked;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final Color ink;
    final BoxDecoration deco;
    final radius = DS.circular(16);
    switch (kind) {
      case _BarKind.primary:
        ink = Colors.white;
        deco = BoxDecoration(
          borderRadius: radius,
          gradient: tone.gradient,
          boxShadow: DS.shadows(Form3D.glow(tone, offset: const Offset(1.1, 5), blur: 12)),
        );
      case _BarKind.outline:
        ink = tone.text;
        deco = BoxDecoration(
          borderRadius: radius,
          color: Colors.white,
          border: Border.all(color: DetailLook.wash(tone, 0.55), width: DS.s(2)),
        );
      case _BarKind.report:
        ink = DetailLook.reportText;
        deco = BoxDecoration(
          borderRadius: radius,
          color: DetailLook.reportFill,
          border: Border.all(color: DetailLook.reportLine, width: DS.s(2)),
        );
      case _BarKind.reported:
        ink = DetailLook.reportedText;
        deco = BoxDecoration(
          borderRadius: radius,
          color: DetailLook.reportedFill,
          border: Border.all(color: DetailLook.reportedLine, width: DS.s(2)),
        );
    }
    Widget? lead;
    if (art != null) {
      lead = Art3D(asset: art!, size: stacked ? 24 : 30, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25);
    } else if (icon != null) {
      final dotFill = switch (kind) {
        _BarKind.report => DetailLook.reportText,
        _BarKind.reported => DetailLook.reportedDot,
        _BarKind.outline => tone.g2,
        _ => Colors.white,
      };
      final dotInk = kind == _BarKind.primary ? tone.g2 : Colors.white;
      final dot = DS.s(stacked ? 24.0 : 28.0);
      lead = Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(shape: BoxShape.circle, color: dotFill, boxShadow: kind == _BarKind.reported ? null : DetailLook.callDot),
        child: Icon(icon, size: DS.s(stacked ? 13 : 15), color: dotInk),
      );
    }
    final text = Text(label, maxLines: 1, style: Ink3D.text(stacked ? 12.5 : 15, FontWeight.w700, ink, letterSpacing: 0));
    final body = Container(
      height: DS.s(height ?? (stacked ? 58 : 48)),
      decoration: deco,
      padding: DS.sym(h: stacked ? 6 : 12),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lead != null) ...[ExcludeSemantics(child: lead), SizedBox(height: DS.s(3))],
                  text,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lead != null) ...[ExcludeSemantics(child: lead), SizedBox(width: DS.s(8))],
                  text,
                ],
              ),
      ),
    );
    if (kind == _BarKind.reported) {
      return Semantics(button: true, enabled: false, label: label, excludeSemantics: true, child: body);
    }
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: onTap == null && kind != _BarKind.primary ? Opacity(opacity: 0.6, child: body) : body,
    );
  }
}
