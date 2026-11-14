import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'meals_card_v.dart';
import 'motion_kit.dart';
import 'template_motion.dart';

enum WideKind { halo, photo, slim }

abstract final class KitText {
  static const String star = '★';

  static double widthOf(String text, TextStyle style, TextScaler scaler) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  static double heightOf(String text, TextStyle style, TextScaler scaler, double width, int maxLines) {
    if (text.isEmpty || width <= 0) return 0;
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: maxLines)..layout(maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  // Narrowest width that keeps the same line count, so a wrapped line never leaves one word alone.
  static double balancedWidth(String text, TextStyle style, TextScaler scaler, double maxWidth) {
    int linesAt(double w) {
      final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler)..layout(maxWidth: w);
      final n = tp.computeLineMetrics().length;
      tp.dispose();
      return n;
    }

    if (maxWidth <= 0) return maxWidth;
    final target = linesAt(maxWidth);
    if (target <= 1) return maxWidth;
    var lo = maxWidth / 2;
    var hi = maxWidth;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      if (linesAt(mid) > target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hi + 1 > maxWidth ? maxWidth : hi + 1;
  }

  static String cut(String text, TextStyle style, TextScaler scaler, double room) {
    bool fits(String t) => widthOf(t, style, scaler) <= room;
    if (fits(text)) return text;
    var lo = 0, hi = text.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (fits('${text.substring(0, mid).trimRight()}…')) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return '${text.substring(0, lo).trimRight()}…';
  }

  // Text as given when every word fits the room (Text wraps at words itself), else wordLines.
  static String fitWords(String text, TextStyle style, TextScaler scaler, double room, int maxLines) {
    final wide = text.split(RegExp(r'\s+')).any((w) => w.isNotEmpty && widthOf(w, style, scaler) > room);
    return wide ? wordLines(text, style, scaler, room, maxLines) : text;
  }

  // Wraps at word boundaries only; a single word wider than the room is ellipsized at the same size.
  static String wordLines(String text, TextStyle style, TextScaler scaler, double room, int maxLines) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final lines = <String>[];
    var cur = '';
    var i = 0;
    for (; i < words.length && lines.length < maxLines; i++) {
      final w = words[i];
      final next = cur.isEmpty ? w : '$cur $w';
      if (widthOf(next, style, scaler) <= room) {
        cur = next;
        continue;
      }
      if (cur.isNotEmpty) {
        lines.add(cur);
        cur = '';
        if (lines.length == maxLines) break;
      }
      if (widthOf(w, style, scaler) <= room) {
        cur = w;
      } else {
        lines.add(cut(w, style, scaler, room));
        i++;
        break;
      }
    }
    if (cur.isNotEmpty && lines.length < maxLines) {
      lines.add(cur);
    }
    final rest = i < words.length;
    if (rest && lines.isNotEmpty && !lines.last.endsWith('…')) {
      lines[lines.length - 1] = cut('${lines.last}…', style, scaler, room);
    }
    return lines.join('\n');
  }

  // Shrinks the font (down to 0.7) so the longest word fits the width; words never break inside.
  static TextStyle wholeWords(String text, TextStyle style, double width, TextScaler scaler) {
    var longest = 0.0;
    for (final w in text.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      final x = widthOf(w, style, scaler);
      if (x > longest) longest = x;
    }
    if (width <= 0 || longest <= width) return style;
    final fit = (width / longest).clamp(0.7, 1.0);
    return style.copyWith(fontSize: (style.fontSize ?? 14) * fit);
  }
}

// Text that draws U+2605 as an icon: Poppins has no star glyph.
class StarText extends StatelessWidget {
  const StarText(this.text, {super.key, required this.style, this.maxLines = 1, this.overflow = TextOverflow.ellipsis});

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    if (!text.contains(KitText.star)) return Text(text, maxLines: maxLines, overflow: overflow, style: style);
    final size = (style.fontSize ?? 12) * 1.05;
    final parts = text.split(KitText.star);
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 1),
                  child: Icon(Icons.star_rounded, size: MediaQuery.textScalerOf(context).scale(size), color: style.color),
                ),
              ),
            TextSpan(text: parts[i]),
          ],
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
      style: style,
      semanticsLabel: text.replaceAll('${KitText.star} ', '').replaceAll(KitText.star, ''),
    );
  }
}

class WideAction {
  const WideAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
    this.busy = false,
    this.itemKey,
    this.child,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool busy;
  final Key? itemKey;
  final Widget? child;
}

class RingBadge extends StatelessWidget {
  const RingBadge({super.key, required this.progress, required this.fill, this.size = 66, this.label});

  final double progress;
  final Color fill;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0, 1).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(p, fill),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.25),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label ?? '${(p * 100).round()}%', maxLines: 1, style: Ink3D.text(15, FontWeight.w700, Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.fill);

  final double p;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.3));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -1.5707963, 6.2831853 * p, true, Paint()..color = Colors.white);
    canvas.drawCircle(c, r - 6, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.p != p || old.fill != fill;
}

class _WideMetrics {
  const _WideMetrics(this.top, this.headPad, this.headMin, this.art, this.halo, this.artAt, this.haloAt);

  final double top;
  final EdgeInsets headPad;
  final double headMin;
  final double art;
  final double halo;
  final Offset artAt;
  final Offset haloAt;

  static const double side = 14;
  static const double gap = 8;

  static _WideMetrics of(WideKind kind, double width, [double scale = 1]) {
    final narrow = width < 340;
    final mid = width < 400;
    final tight = narrow && scale > 1.15;
    return switch (kind) {
      WideKind.halo => tight
          ? const _WideMetrics(50, EdgeInsets.fromLTRB(104, 18, 16, 0), 84, 90, 94, Offset(4, -32), Offset(2, -28))
          : narrow
          ? const _WideMetrics(56, EdgeInsets.fromLTRB(124, 18, 16, 0), 92, 108, 112, Offset(4, -38), Offset(2, -32))
          : mid
              ? const _WideMetrics(60, EdgeInsets.fromLTRB(146, 20, 18, 0), 100, 128, 132, Offset(6, -46), Offset(4, -40))
              : const _WideMetrics(60, EdgeInsets.fromLTRB(160, 20, 20, 0), 100, 144, 148, Offset(6, -52), Offset(4, -46)),
      WideKind.photo => narrow
          ? const _WideMetrics(28, EdgeInsets.fromLTRB(100, 14, 20, 0), 62, 76, 0, Offset(12, 126), Offset.zero)
          : const _WideMetrics(28, EdgeInsets.fromLTRB(124, 14, 20, 0), 62, 96, 0, Offset(14, 112), Offset.zero),
      WideKind.slim => narrow
          ? const _WideMetrics(44, EdgeInsets.fromLTRB(108, 16, 20, 16), 76, 84, 92, Offset(10, -20), Offset(6, -16))
          : const _WideMetrics(48, EdgeInsets.fromLTRB(132, 16, 20, 16), 80, 100, 108, Offset(12, -24), Offset(8, -20)),
    };
  }
}

class WideCard extends StatelessWidget {
  const WideCard({
    super.key,
    required this.tone,
    required this.title,
    this.kind = WideKind.halo,
    this.tag,
    this.subtitle = '',
    this.subtitleSlots,
    this.badge,
    this.badgeSolid = false,
    this.art,
    this.photo,
    this.sticker,
    this.chips = const [],
    this.reserveChips = false,
    this.showPrice = true,
    this.priceCaption,
    this.number,
    this.unit = '',
    this.label,
    this.labelNote,
    this.actions = const [],
    this.actionRows,
    this.onGo,
    this.progress,
    this.trailing,
    this.trailingWidth,
    this.picked = false,
    this.ringColor,
    this.dimmed = false,
    this.onTap,
    this.titleKey,
    this.semanticsLabel,
  });

  final ListingTone tone;
  final String title;
  final WideKind kind;
  final String? tag;
  final String subtitle;
  final List<int>? subtitleSlots;
  final String? badge;
  final bool badgeSolid;
  final String? art;
  final Widget? photo;
  final String? sticker;
  final List<String> chips;
  final bool reserveChips;
  final bool showPrice;
  final String? priceCaption;
  final String? number;
  final String unit;
  final String? label;
  final String? labelNote;
  final List<WideAction> actions;
  final List<List<WideAction>>? actionRows;
  final VoidCallback? onGo;
  final double? progress;
  final Widget? trailing;
  final double? trailingWidth;
  final bool picked;
  final Color? ringColor;
  final bool dimmed;
  final VoidCallback? onTap;
  final Key? titleKey;
  final String? semanticsLabel;

  static const double bannerHeight = 164;

  int _slotLines(int i) => subtitleSlots != null && i < subtitleSlots!.length ? subtitleSlots![i] : 2;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 340;
    final kind = this.kind == WideKind.photo && photo == null ? WideKind.halo : this.kind;
    final art = kind == this.kind ? this.art : (this.art ?? sticker);
    final slim = kind == WideKind.slim;
    final photoKind = kind == WideKind.photo;
    final m = _WideMetrics.of(kind, width, scaler.scale(1));
    final trailW = trailingWidth ?? (slim ? 96.0 : 38.0);
    const bannerH = WideCard.bannerHeight;
    const white = Colors.white;

    final rows = <List<WideAction>>[
      if (!slim && actions.isNotEmpty) actions,
      if (!slim)
        for (final r in actionRows ?? const <List<WideAction>>[])
          if (r.isNotEmpty) r,
    ];
    final hasBar = rows.isNotEmpty;
    final hasBadge = !photoKind && badge != null && badge!.isNotEmpty;
    final hasTag = tag != null && tag!.isNotEmpty;
    final hasTrailing = trailing != null;

    final tagText = hasTag
        ? StarText(tag!.toUpperCase(), maxLines: subtitleSlots != null ? 1 : 2, style: Ink3D.text(10.5, FontWeight.w700, white.withValues(alpha: 0.9), letterSpacing: 0.6))
        : null;
    final badgePill = !hasBadge
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(color: badgeSolid ? white : white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(badge!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, badgeSolid ? tone.g2 : white, letterSpacing: 0.3)),
            ),
          );

    final titleSize = slim ? 17.0 : (narrow ? 18.0 : 20.0);
    final textW = width - _WideMetrics.side * 2 - m.headPad.horizontal - (hasTrailing && !slim ? trailW : 0);
    final slimText = width - _WideMetrics.side * 2 - m.headPad.horizontal - 10 - trailW;
    final iconTrailing = slim && hasTrailing && trailW <= 56;
    final stackTrailing = slim && hasTrailing && !iconTrailing && slimText < scaler.scale(120);
    final lines = subtitle.split('\n').where((e) => e.isNotEmpty).toList();
    final splitSub = iconTrailing && lines.isNotEmpty;
    final titleW = slim && hasTrailing && !stackTrailing && !splitSub ? slimText : textW;
    final titleStyle = KitText.wholeWords(title, Ink3D.text(titleSize, FontWeight.w700, white, height: 1.2), titleW, scaler);
    final stackBadge = hasBadge && textW < scaler.scale(badgeSolid ? 120 : 190);
    final slimSub = Text(subtitle, maxLines: 6, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, white.withValues(alpha: 0.96), height: 1.5));
    final headText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badgePill != null && stackBadge)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Align(alignment: Alignment.centerLeft, child: badgePill)),
        if (badgePill != null && !stackBadge)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Expanded(child: tagText ?? const SizedBox.shrink()),
                const SizedBox(width: 6),
                badgePill,
              ],
            ),
          )
        else if (tagText != null)
          Padding(padding: const EdgeInsets.only(bottom: 2), child: tagText),
        Text(KitText.fitWords(title, titleStyle, scaler, titleW - 1, subtitleSlots != null ? 1 : 2), key: titleKey, maxLines: subtitleSlots != null ? 1 : 2, overflow: TextOverflow.ellipsis, style: titleStyle),
        if (lines.isNotEmpty && !splitSub)
          Padding(
            padding: EdgeInsets.only(top: slim ? 2 : 4),
            child: slim
                ? slimSub
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < lines.length; i++)
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: subtitleSlots == null ? 0 : _slotLines(i) * scaler.scale(12.5 * 1.5)),
                          child: Text(lines[i], maxLines: _slotLines(i), overflow: TextOverflow.ellipsis, style: KitText.wholeWords(lines[i], Ink3D.text(12.5, FontWeight.w500, white.withValues(alpha: 0.96), height: 1.5), textW, scaler)),
                        ),
                    ],
                  ),
          ),
      ],
    );
    final headPad = m.headPad.copyWith(right: m.headPad.right + (hasTrailing && !slim ? trailW : 0));
    final head = ConstrainedBox(
      constraints: BoxConstraints(minHeight: m.headMin),
      child: Padding(
        padding: headPad,
        child: !slim || !hasTrailing
            ? Align(alignment: Alignment.centerLeft, child: headText)
            : splitSub
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  headText,
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Expanded(child: slimSub),
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: trailW), child: trailing),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : stackTrailing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [headText, const SizedBox(height: 10), trailing!],
                  )
                : Row(
                    children: [
                      Expanded(child: headText),
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: trailW), child: trailing),
                      ),
                    ],
                  ),
      ),
    );

    final hasRing = !slim && progress != null;
    final hasChips = !slim && (chips.isNotEmpty || reserveChips || hasRing);
    final chipWrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in chips)
          DecoratedBox(
            decoration: BoxDecoration(color: white.withValues(alpha: 0.26), borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, white)),
            ),
          ),
      ],
    );
    final chipsRow = !hasChips
        ? null
        : Padding(
            padding: EdgeInsets.fromLTRB(20, hasRing ? 6 : 12, 20, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: scaler.scale(26)),
              child: hasRing
                  ? Row(
                      children: [
                        Expanded(child: chipWrap),
                        SizedBox(width: 78, child: Align(alignment: Alignment.centerRight, child: RingBadge(progress: progress!, fill: tone.g2))),
                      ],
                    )
                  : Align(alignment: Alignment.topLeft, child: chipWrap),
            ),
          );

    final hasNumber = number != null && number!.isNotEmpty;
    final showGo = !hasBar && onGo != null;
    final priceRow = (slim || !(showPrice || showGo))
        ? null
        : Padding(
            padding: EdgeInsets.fromLTRB(20, hasChips ? 12 : 10, 20, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: scaler.scale(28)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: showPrice && hasNumber
                        ? _WidePrice(number: number!, unit: unit, caption: priceCaption, room: width - _WideMetrics.side * 2 - 40 - (showGo ? 52 : 0))
                        : const SizedBox.shrink(),
                  ),
                  if (showGo) Padding(padding: const EdgeInsets.only(left: 10), child: RoundGoButton(color: tone.button, size: 42, onTap: onGo)),
                ],
              ),
            ),
          );

    final hasStrip = !slim && label != null && label!.isNotEmpty;
    final hasNote = labelNote != null && labelNote!.isNotEmpty;
    final stripStyle = Ink3D.text(12.5, FontWeight.w500, white, height: 1.35);
    final strip = !hasStrip
        ? null
        : Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            color: Colors.black.withValues(alpha: 0.11),
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-4, 0),
                  child: const Art3D(asset: ListingArt.roundPushpin, size: 20, shadowBlur: 2, shadowOffset: Offset(1, 2), shadowAlpha: 0.3),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: KitText.balancedWidth(label!, stripStyle, scaler, width - _WideMetrics.side * 2 - 40 - 20),
                        child: Text(label!, maxLines: 3, overflow: TextOverflow.ellipsis, style: stripStyle),
                      ),
                      if (hasNote) Text(labelNote!, maxLines: 2, overflow: TextOverflow.ellipsis, style: stripStyle.copyWith(color: white.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ],
            ),
          );

    final bar = !hasBar
        ? null
        : Padding(
            padding: EdgeInsets.only(top: hasStrip ? 0 : 14),
            child: DecoratedBox(
              decoration: BoxDecoration(color: white.withValues(alpha: 0.2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Container(height: 1, color: white.withValues(alpha: 0.28)),
                    _ActionRow(actions: rows[i], tone: tone, width: width - _WideMetrics.side * 2),
                  ],
                ],
              ),
            ),
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (photoKind) _Banner(photo: photo, badge: badge, height: bannerH),
        head,
        ?chipsRow,
        ?priceRow,
        ?strip,
        ?bar,
        if (!slim && !hasBar && !hasStrip) const SizedBox(height: 16),
      ],
    );
    final ring = ringColor ?? white;
    final cardBox = Container(
      decoration: BoxDecoration(
        borderRadius: kMealsRadius,
        gradient: tone.gradient,
        boxShadow: picked || ringColor != null
            ? [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 6), blurRadius: 14)]
            : tone.glow(),
      ),
      foregroundDecoration: picked || ringColor != null
          ? BoxDecoration(borderRadius: kMealsRadius, border: Border.all(color: ring, width: 3, strokeAlign: BorderSide.strokeAlignOutside))
          : null,
      child: ClipRRect(
        borderRadius: kMealsRadius,
        child: Stack(
          children: [
            content,
            if (hasTrailing && !slim) Positioned(right: 6, top: photoKind ? bannerH + 6 : 6, child: trailing!),
          ],
        ),
      ),
    );

    final artAsset = photoKind ? sticker : art;
    Widget body = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: EdgeInsets.fromLTRB(_WideMetrics.side, m.top, _WideMetrics.side, _WideMetrics.gap), child: cardBox),
        if (!photoKind && artAsset != null)
          Positioned(
            left: _WideMetrics.side + m.haloAt.dx,
            top: m.top + m.haloAt.dy,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: 0.24)),
                child: SizedBox(width: m.halo, height: m.halo),
              ),
            ),
          ),
        if (artAsset != null)
          Positioned(
            left: _WideMetrics.side + m.artAt.dx,
            top: m.top + m.artAt.dy,
            child: IgnorePointer(
              child: photoKind
                  ? Art3D(asset: artAsset, size: m.art, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.3)
                  : Art3D(asset: artAsset, size: m.art),
            ),
          ),
      ],
    );
    if (dimmed) body = Opacity(opacity: 0.6, child: body);
    if (onTap != null) {
      body = PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body));
    }
    if (semanticsLabel == null) return body;
    return Semantics(label: semanticsLabel, button: onTap != null, container: true, excludeSemantics: !hasBar, child: body);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.photo, required this.badge, required this.height});

  final Widget? photo;
  final String? badge;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo ??
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0.10)],
                  ),
                ),
              ),
          if (photo == null)
            Positioned(
              right: -30,
              top: -34,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
                  child: SizedBox(width: height * 1.05, height: height * 1.05),
                ),
              ),
            ),
          if (badge != null && badge!.isNotEmpty)
            Positioned(
              left: 14,
              top: 12,
              right: 60,
              child: Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 8)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Ink3D.title),
                        const SizedBox(width: 4),
                        Flexible(child: Text(badge!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.title))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WidePrice extends StatelessWidget {
  const _WidePrice({required this.number, required this.unit, required this.room, this.caption});

  final String number;
  final String unit;
  final double room;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final scaler = MediaQuery.textScalerOf(context);
    final cap = caption ?? '';
    final capStyle = Ink3D.text(11, FontWeight.w700, white.withValues(alpha: 0.9), letterSpacing: 0.5);
    final capText = Text(cap, maxLines: 1, overflow: TextOverflow.ellipsis, style: capStyle);
    if (!RegExp(r'\d').hasMatch(number)) {
      final text = unit.isEmpty ? number : '$number $unit';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (cap.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6, bottom: 3), child: capText),
          Flexible(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, white, height: 1.25))),
        ],
      );
    }
    final numStyle = Ink3D.text(28, FontWeight.w500, white, height: 1);
    final unitStyle = Ink3D.text(12, FontWeight.w500, white, height: 1.25);
    final capW = cap.isEmpty ? 0.0 : KitText.widthOf(cap, capStyle, scaler) + 6;
    final numW = KitText.widthOf(number, numStyle, scaler) + 1;
    final firstWord = unit.trim().split(RegExp(r'\s+')).first;
    final unitMin = unit.isEmpty ? 0.0 : KitText.widthOf(firstWord, unitStyle, scaler) + 6;
    final capInline = capW + numW + unitMin <= room;
    final numRoom = room - (capInline ? capW : 0) - unitMin;
    var fit = numW <= numRoom ? 1.0 : (numRoom / numW).clamp(0.8, 1.0);
    double unitLines(double f) => unit.isEmpty
        ? 0
        : KitText.heightOf(unit, unitStyle, scaler, room - (capInline ? capW : 0) - numW * f - 5, 9) / scaler.scale(12 * 1.25);
    if (unitLines(fit) > 2.1) fit = (fit * 0.9).clamp(0.8, 1.0);
    if (unitLines(fit) > 2.1) {
      final f = numW <= room - (capInline ? capW : 0) ? 1.0 : ((room - (capInline ? capW : 0)) / numW).clamp(0.8, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!capInline && cap.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: capText),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (capInline && cap.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6, bottom: 5), child: capText),
              Flexible(child: Text(number, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: numStyle.copyWith(fontSize: 28 * f))),
            ],
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(unit, maxLines: 2, overflow: TextOverflow.ellipsis, style: unitStyle)),
        ],
      );
    }
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (capInline && cap.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6, bottom: 5), child: capText),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: numRoom > 40 ? numRoom : 40),
          child: Text(number, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: numStyle.copyWith(fontSize: 28 * fit)),
        ),
        if (unit.isNotEmpty)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 2),
              child: Text(unit, maxLines: 2, overflow: TextOverflow.ellipsis, style: unitStyle),
            ),
          ),
      ],
    );
    if (capInline || cap.isEmpty) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [Padding(padding: const EdgeInsets.only(bottom: 2), child: capText), row],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.actions, required this.tone, required this.width});

  final List<WideAction> actions;
  final ListingTone tone;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final cellW = (width - (actions.length - 1)) / actions.length;
    final room = cellW - _ActionCell.sidePad * 2 - 34;
    final style = Ink3D.text(14, FontWeight.w700, Colors.white);
    final stacked = actions.any((a) => KitText.widthOf(a.label, style, scaler) > room);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) Container(width: 1, color: Colors.white.withValues(alpha: 0.28)),
            Expanded(child: _ActionCell(action: actions[i], tone: tone, stacked: stacked)),
          ],
        ],
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.action, required this.tone, this.stacked = false});

  final WideAction action;
  final ListingTone tone;
  final bool stacked;

  static const double sidePad = 6;

  @override
  Widget build(BuildContext context) {
    final on = action.selected;
    final fg = on ? tone.button : Colors.white;
    final custom = action.child;
    final enabled = action.onTap != null && !action.busy;
    final faded = action.onTap == null && !on;
    final labelStyle = Ink3D.text(14, FontWeight.w700, fg);
    final icon = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? tone.button : Colors.white,
        boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(3, 4), blurRadius: 6)],
      ),
      child: SizedBox(
        width: 26,
        height: 26,
        child: action.busy
            ? Padding(
                padding: const EdgeInsets.all(6),
                child: CircularProgressIndicator(strokeWidth: 2, color: on ? Colors.white : Ink3D.body),
              )
            : Icon(action.icon, size: 14, color: on ? Colors.white : Ink3D.body),
      ),
    );
    final chip = custom == null
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(color: (on ? tone.button : Colors.white).withValues(alpha: on ? 0.14 : 0.3), borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.textScalerOf(context).scale(15)),
                child: custom,
              ),
            ),
          );
    final inner = stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
  icon,
  const SizedBox(height: 6),
  Text(action.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: labelStyle.copyWith(height: 1.25)),
  if (chip != null) Padding(padding: const EdgeInsets.only(top: 3), child: chip),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
  icon,
  const SizedBox(width: 8),
  Flexible(
    child: chip == null
        ? Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
              const SizedBox(height: 3),
              chip,
            ],
          ),
  ),
            ],
          );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: on,
      child: GestureDetector(
        key: action.itemKey,
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? action.onTap : () {},
        child: ColoredBox(
          color: on ? Colors.white : Colors.transparent,
          child: Opacity(
            opacity: faded ? 0.75 : 1,
            child: Padding(
  padding: EdgeInsets.symmetric(vertical: stacked ? 10 : 13, horizontal: sidePad),
  child: Center(child: inner),
            ),
          ),
        ),
      ),
    );
  }
}

class WideCardSkeleton extends StatelessWidget {
  const WideCardSkeleton({super.key, this.kind = WideKind.halo});

  final WideKind kind;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1);
    final scale = s < 1 ? 1.0 : s;
    final m = _WideMetrics.of(kind, MediaQuery.sizeOf(context).width);
    final slim = kind == WideKind.slim;
    final photoKind = kind == WideKind.photo;
    final lower = slim ? 0.0 : 12 + 26 * scale + 12 + 28 * scale + 14 + 26 + 26 * scale;
    final headHeight = slim || !photoKind ? m.headMin : m.headMin * scale;
    final card = Padding(
      padding: EdgeInsets.fromLTRB(_WideMetrics.side, m.top, _WideMetrics.side, _WideMetrics.gap),
      child: Container(
        height: (photoKind ? WideCard.bannerHeight : 0) + headHeight + lower,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: kMealsRadius, boxShadow: Ink3D.softShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photoKind) const TemplatePlaceholder(height: WideCard.bannerHeight, radius: 0),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(m.headPad.left, 16, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TemplatePlaceholder(height: 16, width: 130),
                    const SizedBox(height: 10),
                    const TemplatePlaceholder(height: 10, width: 90),
                    if (!slim) ...[
                      const Spacer(),
                      const TemplatePlaceholder(height: 22, width: 110),
                      const Spacer(),
                      const TemplatePlaceholder(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!photoKind) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          left: _WideMetrics.side + m.artAt.dx,
          top: m.top + m.artAt.dy,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: Ink3D.body.withValues(alpha: 0.16)),
            child: SizedBox(width: m.art, height: m.art),
          ),
        ),
      ],
    );
  }
}
