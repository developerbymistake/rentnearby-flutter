import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'skeleton_3d.dart';

abstract final class DetailArt {
  static const String automobile = 'assets/images/design/travel3d/automobile.png';
}

abstract final class DetailLook {
  static const Color glass = Color(0xE6FFFFFF);
  static const Color darkGlass = Color(0x5217262A);
  static const Color darkGlassStrong = Color(0x8C17262A);
  static const Color backFill = Color(0xFFF2F3F8);
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
  static const List<BoxShadow> glassShadow = [BoxShadow(color: Color(0x33000000), offset: Offset(3, 5), blurRadius: 10)];
  static const List<BoxShadow> backShadow = [BoxShadow(color: Color(0x669E9E9E), offset: Offset(3, 5), blurRadius: 10)];
  static const List<BoxShadow> barShadow = [BoxShadow(color: Color(0x24000000), offset: Offset(0, -4), blurRadius: 18)];
  static const List<BoxShadow> topBarShadow = [BoxShadow(color: Color(0x1F000000), offset: Offset(0, 2), blurRadius: 12)];
  static const List<BoxShadow> whiteCard = [BoxShadow(color: Color(0x339E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)];
  static const Color noteCream = Color(0xFFFFF1DE);
  static const Color noteInk = Color(0xFF6A4A1A);
  static const List<BoxShadow> noteCard = [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)];
  static const List<BoxShadow> callDot = [BoxShadow(color: Color(0x33000000), offset: Offset(2, 3), blurRadius: 5)];

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

  static const BorderRadius r68 = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(68),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius r54 = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(54),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius r40 = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(40),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius r32 = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(32),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius r30 = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(30),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius r24 = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(24),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  static bool narrow(BuildContext context) => MediaQuery.sizeOf(context).width < 340;
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fill, boxShadow: dark ? null : (solid ? DetailLook.backShadow : DetailLook.glassShadow)),
          child: Icon(Icons.chevron_left_rounded, size: 30, color: dark ? Colors.white : Ink3D.title),
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
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: dark ? DetailLook.darkGlass : DetailLook.glass,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: dark ? null : DetailLook.glassShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share_rounded, size: 18, color: ink),
            const SizedBox(width: 6),
            Text('Share', maxLines: 1, textScaler: _capScale(context, 1.2), style: Ink3D.text(14, FontWeight.w700, ink)),
          ],
        ),
      ),
    );
  }
}

TextScaler _capScale(BuildContext context, double max) => MediaQuery.textScalerOf(context).clamp(maxScaleFactor: max);

class DetailHeroArt extends StatelessWidget {
  const DetailHeroArt({super.key, required this.tone, required this.art});

  final ListingTone tone;
  final String art;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: tone.gradient),
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Center(
          child: ExcludeSemantics(
            child: Art3D(asset: art, size: 168, halo: 196, haloColor: DetailLook.heroHalo, shadowBlur: 10, shadowOffset: const Offset(8, 12), shadowAlpha: 0.3),
          ),
        ),
      ),
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
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == index ? Colors.white : DetailLook.dotOff, borderRadius: BorderRadius.circular(3)),
          ),
      ],
    );
  }
}

class DetailTopScrim extends StatelessWidget {
  const DetailTopScrim({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DetailLook.scrimTop, Color(0x00000000)]),
      ),
      child: SizedBox(height: 130, width: double.infinity),
    ),
  );
}

class DetailEdge extends StatelessWidget {
  const DetailEdge({super.key, required this.page});

  final Color page;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      height: 26,
      decoration: BoxDecoration(
        color: page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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

  static double heightOf(BuildContext context) => MediaQuery.paddingOf(context).top + 64;

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
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: DetailLook.backFill),
                child: const Icon(Icons.chevron_left_rounded, size: 30, color: Ink3D.title),
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
                child: SizedBox(width: 44, height: 44, child: Icon(Icons.ios_share_rounded, size: 20, color: tone.text)),
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
            padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top, 14, 0),
            child: Row(
              children: [
                back,
                const SizedBox(width: 12),
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
                if (share != null) ...[const SizedBox(width: 8), share],
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
  });

  final ListingTone tone;
  final String eyebrow;
  final String title;
  final String caption;
  final String value;
  final String? unit;
  final bool compact;

  static const double topRoom = 26;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 340;
    final art = narrow ? 96.0 : (w < 380 ? 112.0 : 130.0);
    final clear = art - (compact ? 14 : 20);
    final numeric = value.contains(RegExp(r'[0-9]'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, topRoom, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 152),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            decoration: BoxDecoration(borderRadius: DetailLook.r68, gradient: tone.gradient, boxShadow: tone.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: clear),
                  child: Text(eyebrow, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Colors.white, letterSpacing: 0.8)),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.only(right: clear),
                  child: _FitTitle(title: title, style: Ink3D.text(compact ? 18 : 22, FontWeight.w700, Colors.white, height: 1.15)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(caption, style: Ink3D.text(11, FontWeight.w700, Colors.white.withValues(alpha: 0.9), letterSpacing: 0.6)),
                    ),
                    Text(value, style: Ink3D.text(30, FontWeight.w500, Colors.white, height: 1, letterSpacing: numeric ? 0.2 : 0)),
                    if (unit != null && unit!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(unit!, style: Ink3D.text(13, FontWeight.w400, Colors.white.withValues(alpha: 0.92))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            top: narrow ? -28 : (art < 120 ? -36 : -44),
            child: ExcludeSemantics(
              child: Art3D(
                asset: ListingArt.moneyBag,
                size: art,
                halo: art + 6,
                haloColor: DetailLook.cardHalo,
                haloDy: 4,
                shadowBlur: 6,
                shadowOffset: const Offset(5, 8),
                shadowAlpha: 0.3,
              ),
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
  const DetailSlimCard({super.key, required this.tone, required this.art, required this.title, required this.subtitle, required this.price, this.unit});

  final ListingTone tone;
  final String art;
  final String title;
  final String subtitle;
  final String price;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final t = DetailLook.card(tone);
    final narrow = DetailLook.narrow(context);
    final artSize = narrow ? 84.0 : 100.0;
    final left = narrow ? 108.0 : 136.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 38, 14, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 104),
            padding: EdgeInsets.fromLTRB(left, 16, 20, 16),
            decoration: BoxDecoration(borderRadius: DetailLook.r54, gradient: t.gradient, boxShadow: t.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Colors.white, height: 1.2)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w500, Colors.white, height: 1.4)),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 5,
                  children: [
                    Text(price, style: Ink3D.text(22, FontWeight.w600, Colors.white, height: 1)),
                    if (unit != null && unit!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(unit!, style: Ink3D.text(12, FontWeight.w400, Colors.white.withValues(alpha: 0.92))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: narrow ? 8 : 12,
            top: -26,
            child: ExcludeSemantics(
              child: Art3D(
                asset: art,
                size: artSize,
                halo: artSize + 8,
                haloColor: DetailLook.slimHalo,
                haloDy: 4,
                shadowBlur: 6,
                shadowOffset: const Offset(5, 8),
                shadowAlpha: 0.25,
              ),
            ),
          ),
        ],
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
    return Container(
      margin: EdgeInsets.fromLTRB(18, top, 18, 0),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: DetailLook.r40, boxShadow: DetailLook.whiteCard),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: Ink3D.line)),
              ),
              child: MergeSemantics(
                child: Row(
                  children: [
                    _ArtTile(tone: tone, art: rows[i].art),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].label, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                          const SizedBox(height: 1),
                          Text(
                            rows[i].value.isEmpty ? '-' : rows[i].value,
                            style: Ink3D.text(15.5, FontWeight.w500, Ink3D.title, height: 1.3, letterSpacing: 0),
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

class _ArtTile extends StatelessWidget {
  const _ArtTile({required this.tone, required this.art, this.fill});

  final ListingTone tone;
  final String art;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: fill ?? DetailLook.wash(tone, 0.14), borderRadius: BorderRadius.circular(16)),
              ),
            ),
            Positioned(
              left: -4,
              top: -10,
              child: Art3D(asset: art, size: 66, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailChipItem {
  const DetailChipItem({required this.tone, required this.art, required this.label, this.value});

  final ListingTone tone;
  final String art;
  final String label;
  final String? value;
}

class DetailChipGrid extends StatelessWidget {
  const DetailChipGrid({super.key, required this.items, this.rules = false});

  final List<DetailChipItem> items;
  final bool rules;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth - 36;
        final col = (inner - 12) / 2;
        final textRoom = col - (rules ? 86 : 80);
        final cols = textRoom < (rules ? 64 : 60) * scale ? 1 : 2;
        final cells = [for (final it in items) rules ? _RuleTile(item: it) : _FacilityChip(item: it)];
        final rows = <Widget>[];
        for (var i = 0; i < cells.length; i += cols) {
          final slice = cells.sublist(i, (i + cols).clamp(0, cells.length));
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: rules ? 34 : 30),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) const SizedBox(width: 12),
                      Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(children: rows),
        );
      },
    );
  }
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.item});

  final DetailChipItem item;

  @override
  Widget build(BuildContext context) {
    final t = DetailLook.card(item.tone);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(64, 10, 10, 10),
          decoration: BoxDecoration(borderRadius: DetailLook.r24, gradient: t.gradient, boxShadow: t.glow(blur: 8)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.label,
              maxLines: 1,
              style: Ink3D.text(13.5, FontWeight.w700, Colors.white, letterSpacing: 0, height: 1.25),
            ),
          ),
        ),
        Positioned(
          left: 6,
          top: -20,
          child: ExcludeSemantics(
            child: Art3D(asset: item.art, size: 58, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.item});

  final DetailChipItem item;

  @override
  Widget build(BuildContext context) {
    final t = DetailLook.card(item.tone);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 80),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(74, 12, 12, 12),
          decoration: BoxDecoration(borderRadius: DetailLook.r30, gradient: t.gradient, boxShadow: t.glow(blur: 8)),
          child: MergeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: Ink3D.text(11.5, FontWeight.w500, Colors.white.withValues(alpha: 0.92), letterSpacing: 0),
                  ),
                ),
                Text(
                  (item.value ?? '').isEmpty ? '-' : item.value!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(16, FontWeight.w700, Colors.white, letterSpacing: 0, height: 1.25),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: -22,
          child: ExcludeSemantics(
            child: Art3D(asset: item.art, size: 66, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class DetailAboutCard extends StatelessWidget {
  const DetailAboutCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 18),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: const BoxDecoration(color: Colors.white, borderRadius: DetailLook.r32, boxShadow: DetailLook.whiteCard),
    child: Text(text, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, height: 1.6, letterSpacing: 0)),
  );
}

class DetailPosted extends StatelessWidget {
  const DetailPosted({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
    child: Row(
      children: [
        const ExcludeSemantics(
          child: Art3D(asset: ListingArt.calendar, size: 28, shadowBlur: 2, shadowOffset: Offset(2, 3), shadowAlpha: 0.25),
        ),
        const SizedBox(width: 8),
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
    margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    decoration: BoxDecoration(color: DetailLook.hiddenFill, borderRadius: BorderRadius.circular(24)),
    child: Row(
      children: [
        const ExcludeSemantics(
          child: Art3D(asset: ListingArt.pushpin, size: 24, shadowBlur: 2, shadowOffset: Offset(1, 2), shadowAlpha: 0.2),
        ),
        const SizedBox(width: 8),
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
      width: 220,
      child: _BarButton.primary(tone: tone, label: actionLabel ?? ' ', onTap: onAction, height: 52),
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
            const SizedBox(height: 32),
            Text(title, textAlign: TextAlign.center, style: Ink3D.text(24, FontWeight.w700, Ink3D.title, height: 1.25, letterSpacing: 0)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 22),
              child: Text(message ?? '', textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
            ),
            const SizedBox(height: 24),
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
    padding: m,
    child: ClipRRect(
      borderRadius: r,
      child: SkeletonBox(height: h, width: w, radius: 0),
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
            _bone(14, BorderRadius.circular(6), const EdgeInsets.fromLTRB(22, 16, 22, 0)),
            _bone(14, BorderRadius.circular(6), const EdgeInsets.fromLTRB(22, 16, 22, 0), w: 200),
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
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 19),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: DetailLook.r32, boxShadow: DetailLook.whiteCard),
      child: Row(
        children: [
          _ArtTile(tone: ListingTone.coral, art: ListingArt.taxi, fill: DetailLook.wash(ListingTone.coral, 0.2)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(14.5, FontWeight.w600, Ink3D.title, letterSpacing: 0, height: 1.35),
            ),
          ),
          if (onSeeAll != null) ...[
            const SizedBox(width: 6),
            Tap3D(
              onTap: onSeeAll,
              label: 'See all',
              exclude: true,
              child: SizedBox(
                height: 44,
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
  const GettingThereNote({super.key, required this.tone, required this.art, required this.text, this.actionLabel, this.onAction});

  final ListingTone tone;
  final String art;
  final String text;
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: tone.gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: live ? Form3D.glow(tone, offset: const Offset(1.1, 3), blur: 8) : null,
        ),
        child: Text(actionLabel ?? 'Retry', maxLines: 1, style: Ink3D.text(13, FontWeight.w700, Colors.white, letterSpacing: 0)),
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: DetailLook.r24, boxShadow: DetailLook.noteCard),
      child: Row(
        children: [
          _ArtTile(tone: tone, art: art),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 38),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(13, FontWeight.w400, Ink3D.sub, height: 1.45, letterSpacing: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
  const DetailBarShell({super.key, required this.tone, required this.safety, required this.children, required this.bottomInset, this.safetyArt});

  final String? safetyArt;
  final ListingTone tone;
  final String safety;
  final List<Widget> children;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32)),
        boxShadow: DetailLook.barShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (safetyArt != null)
            Container(
              color: DetailLook.noteCream,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  ExcludeSemantics(child: Image.asset(safetyArt!, width: 30, height: 30, fit: BoxFit.contain)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(safety, style: Ink3D.text(12.5, FontWeight.w500, DetailLook.noteInk, height: 1.35, letterSpacing: 0))),
                ],
              ),
            )
          else
          Container(
            color: DetailLook.wash(tone, 0.13),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
            child: Text.rich(
              TextSpan(
                children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.info_outline_rounded, size: 12, color: Ink3D.body),
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
            padding: EdgeInsets.fromLTRB(18, safetyArt != null ? 12 : 10, 18, (safetyArt != null ? 10 : 20) + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailBarPair extends StatelessWidget {
  const DetailBarPair({super.key, required this.left, required this.right, required this.leftLabel, required this.rightLabel});

  final Widget left;
  final Widget right;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final half = (box.maxWidth - 8) / 2;
        final need = [leftLabel, rightLabel].map((l) => 30 + 8 + 24 + _width(context, l)).reduce((a, b) => a > b ? a : b);
        if (need * 0.8 > half) {
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 8), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  static double _width(BuildContext context, String text) {
    final p = TextPainter(
      text: TextSpan(text: text, style: Ink3D.text(15, FontWeight.w700, Colors.white)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }
}

enum _BarKind { primary, outline, report, reported }

class DetailBarButton extends StatelessWidget {
  const DetailBarButton._(this._kind, {required this.tone, required this.label, required this.onTap, this.art, this.icon});

  const DetailBarButton.primary({required ListingTone tone, required String label, required VoidCallback? onTap, String? art, IconData? icon})
    : this._(_BarKind.primary, tone: tone, label: label, onTap: onTap, art: art, icon: icon);
  const DetailBarButton.outline({required ListingTone tone, required String label, required VoidCallback? onTap, String? art})
    : this._(_BarKind.outline, tone: tone, label: label, onTap: onTap, art: art);
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

  @override
  Widget build(BuildContext context) => _BarButton(kind: _kind, tone: tone, label: label, onTap: onTap, art: art, icon: icon);
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.kind, required this.tone, required this.label, required this.onTap, this.art, this.icon}) : height = 48;

  const _BarButton.primary({required this.tone, required this.label, required this.onTap, this.height = 48}) : kind = _BarKind.primary, art = null, icon = null;

  final _BarKind kind;
  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final String? art;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color ink;
    final BoxDecoration deco;
    final radius = BorderRadius.circular(16);
    switch (kind) {
      case _BarKind.primary:
        ink = Colors.white;
        deco = BoxDecoration(
          borderRadius: radius,
          gradient: tone.gradient,
          boxShadow: Form3D.glow(tone, offset: const Offset(1.1, 5), blur: 12),
        );
      case _BarKind.outline:
        ink = tone.text;
        deco = BoxDecoration(
          borderRadius: radius,
          color: Colors.white,
          border: Border.all(color: DetailLook.wash(tone, 0.55), width: 2),
        );
      case _BarKind.report:
        ink = DetailLook.reportText;
        deco = BoxDecoration(
          borderRadius: radius,
          color: DetailLook.reportFill,
          border: Border.all(color: DetailLook.reportLine, width: 2),
        );
      case _BarKind.reported:
        ink = DetailLook.reportedText;
        deco = BoxDecoration(
          borderRadius: radius,
          color: DetailLook.reportedFill,
          border: Border.all(color: DetailLook.reportedLine, width: 2),
        );
    }
    Widget? lead;
    if (art != null) {
      lead = Art3D(asset: art!, size: 30, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25);
    } else if (icon != null) {
      final dotFill = switch (kind) {
        _BarKind.report => DetailLook.reportText,
        _BarKind.reported => DetailLook.reportedDot,
        _ => Colors.white,
      };
      final dotInk = kind == _BarKind.primary ? tone.g2 : Colors.white;
      lead = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, color: dotFill, boxShadow: kind == _BarKind.reported ? null : DetailLook.callDot),
        child: Icon(icon, size: 15, color: dotInk),
      );
    }
    final body = Container(
      height: height,
      decoration: deco,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lead != null) ...[ExcludeSemantics(child: lead), const SizedBox(width: 8)],
            Text(label, maxLines: 1, style: Ink3D.text(15, FontWeight.w700, ink, letterSpacing: 0)),
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
