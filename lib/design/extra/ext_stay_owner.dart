import 'package:flutter/material.dart';

import '../design.dart';

abstract final class StayOwnerArt {
  static const String automobile = 'assets/images/design/travel3d/automobile.png';

  static const List<String> _typeCycle = [ListingArt.bed, ListingArt.hotel, ListingArt.beach, ListingArt.tent, ListingArt.mountain, ListingArt.backpack];

  static String stayType(String name, int index) {
    final n = name.toLowerCase();
    if (n.contains('home')) return ListingArt.bed;
    if (n.contains('hotel') || n.contains('villa')) return ListingArt.hotel;
    if (n.contains('resort')) return ListingArt.beach;
    if (n.contains('camp') || n.contains('tent')) return ListingArt.tent;
    if (n.contains('cottage') || n.contains('farm')) return ListingArt.mountain;
    if (n.contains('hostel') || n.contains('dorm')) return ListingArt.backpack;
    return _typeCycle[index % _typeCycle.length];
  }

  static const Map<String, String> vehicle = {'CarToGate': automobile, 'ShortWalk': ListingArt.backpack, 'LongWalk': ListingArt.mountain};
  static const Map<String, String> meals = {'RoomOnly': ListingArt.key, 'Breakfast': ListingArt.sunrise, 'AllMeals': ListingArt.star};
  static const Map<String, String> cancellation = {'Flexible': ListingArt.star, 'Moderate': ListingArt.calendar, 'Strict': ListingArt.clipboard};
}

abstract final class StayOwnerInk {
  static const Color sectionLabel = Color(0xFF5F6B76);
  static const Color mapBase = Color(0xFFE8EEDD);
  static const Color waitBase = Color(0xFFF2F3F8);
  static const Color danger = Color(0xFFE0525C);
  static const Color newBadge = Color(0xFFC0404A);
  static const Color live = Color(0xFF2E7D32);
  static const Color paused = Color(0xFF8A8F99);
  static const Color review = Color(0xFFE08A00);
  static const Color rejected = Color(0xFFD03A44);
  static const List<BoxShadow> tileShadow = [BoxShadow(color: Color(0x2E000000), offset: Offset(1.1, 3), blurRadius: 8)];
  static const List<BoxShadow> roundButton = [BoxShadow(color: Color(0x33000000), offset: Offset(2, 4), blurRadius: 6)];
  static const List<BoxShadow> pill = [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 8)];
}

const BorderRadius _card54 = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
const BorderRadius _card68 = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(68), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
const BorderRadius _tile24 = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

class SectionCaption3D extends StatelessWidget {
  const SectionCaption3D(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(22, 30, 22, 0)});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Semantics(
          header: true,
          child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, StayOwnerInk.sectionLabel, letterSpacing: 0.9)),
        ),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, required this.onTap, required this.tooltip});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Tap3D(
          onTap: onTap,
          label: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: StayOwnerInk.roundButton),
                child: Icon(icon, size: 16, color: color),
              ),
            ),
          ),
        ),
      );
}

class RoomCard3D extends StatelessWidget {
  const RoomCard3D({
    super.key,
    required this.tone,
    required this.eyebrow,
    required this.title,
    required this.line1,
    required this.line2,
    this.art = ListingArt.bed,
    this.onEdit,
    this.onRemove,
    this.editTooltip = 'Edit room',
    this.removeTooltip = 'Remove room',
  });

  final ListingTone tone;
  final String eyebrow;
  final String title;
  final String line1;
  final String line2;
  final String art;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final String editTooltip;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 88.0 : 104.0;
    final left = narrow ? 100.0 : 120.0;
    final line = Ink3D.text(12.5, FontWeight.w400, Colors.white.withValues(alpha: 0.95), height: 1.38, letterSpacing: 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 108),
            padding: EdgeInsets.fromLTRB(left, 12, 8, 14),
            decoration: BoxDecoration(borderRadius: _card54, gradient: tone.gradient, boxShadow: [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 4), blurRadius: 10)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(eyebrow.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, Colors.white.withValues(alpha: 0.92), letterSpacing: 0.7)),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: FitLine3D(text: title, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.3)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _RoundIcon(icon: Icons.edit_rounded, color: tone.button, onTap: onEdit, tooltip: editTooltip),
                    _RoundIcon(icon: Icons.close_rounded, color: StayOwnerInk.danger, onTap: onRemove, tooltip: removeTooltip),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(line1, maxLines: 1, overflow: TextOverflow.ellipsis, style: line),
                      Text(line2, maxLines: 2, overflow: TextOverflow.ellipsis, style: line),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 8, top: -26 - ArtLift.of(art, artSize), child: IgnorePointer(child: Container(width: artSize - 4, height: artSize - 4, decoration: BoxDecoration(shape: BoxShape.circle, color: tone.halo)))),
          Positioned(left: 8, top: -30 - ArtLift.of(art, artSize), child: IgnorePointer(child: Art3D(asset: art, size: artSize))),
        ],
      ),
    );
  }
}

class OwnerAction {
  const OwnerAction({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
}

class OwnerStayCard3D extends StatelessWidget {
  const OwnerStayCard3D({
    super.key,
    required this.tone,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    this.subtitle = '',
    this.photo,
    this.sticker = ListingArt.hotel,
    this.chips = const [],
    this.localityLabel,
    this.locality,
    this.children = const [],
    this.actions = const [],
  });

  final ListingTone tone;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final Widget? photo;
  final String sticker;
  final List<String> chips;
  final String? localityLabel;
  final String? locality;
  final List<Widget> children;
  final List<OwnerAction> actions;

  static const double bannerHeight = 164;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final stickerSize = narrow ? 76.0 : 96.0;
    final headLeft = narrow ? 100.0 : 124.0;
    const white = Colors.white;

    final banner = SizedBox(
      height: bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo ??
              DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [white.withValues(alpha: 0.30), white.withValues(alpha: 0.10)])),
                child: Align(alignment: const Alignment(0.7, -0.2), child: Opacity(opacity: 0.55, child: Art3D(asset: ListingArt.sunrise, size: 96, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.2))),
              ),
          Positioned(
            left: 14,
            top: 12,
            right: 60,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(color: white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(14), boxShadow: StayOwnerInk.pill),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                      const SizedBox(width: 6),
                      Flexible(child: Text(statusLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.title))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final head = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 62),
      child: Padding(
        padding: EdgeInsets.fromLTRB(headLeft, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(narrow ? 18 : 20, FontWeight.w700, white, height: 1.2)),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, white.withValues(alpha: 0.92), height: 1.5)),
              ),
          ],
        ),
      ),
    );

    final chipRow = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.textScalerOf(context).scale(26)),
        child: Align(
          alignment: Alignment.topLeft,
          child: Wrap(
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
          ),
        ),
      ),
    );

    final loc = locality;
    final strip = loc == null
        ? null
        : Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            color: Colors.black.withValues(alpha: 0.11),
            child: Row(
              children: [
                Transform.translate(offset: const Offset(-4, 0), child: const Art3D(asset: ListingArt.roundPushpin, size: 20, shadowBlur: 2, shadowOffset: Offset(1, 2), shadowAlpha: 0.3)),
                const SizedBox(width: 4),
                if (localityLabel != null) ...[
                  Text(localityLabel!, style: Ink3D.text(10.5, FontWeight.w700, white, letterSpacing: 0.6)),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text(loc, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, white, height: 1.35))),
              ],
            ),
          );

    final bar = actions.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(color: white.withValues(alpha: 0.2)),
              child: LayoutBuilder(builder: (context, box) {
                final cellW = (box.maxWidth - (actions.length - 1)) / actions.length;
                final scaler = MediaQuery.textScalerOf(context);
                var widest = 0.0;
                for (final a in actions) {
                  final p = TextPainter(text: TextSpan(text: a.label, style: _OwnerActionCell.labelStyle), maxLines: 1, textDirection: TextDirection.ltr, textScaler: scaler)..layout();
                  if (p.width > widest) widest = p.width;
                  p.dispose();
                }
                final stacked = 12 + 26 + 8 + widest > cellW;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) Container(width: 1, color: white.withValues(alpha: 0.28)),
                        Expanded(child: _OwnerActionCell(action: actions[i], stacked: stacked)),
                      ],
                    ],
                  ),
                );
              }),
            ),
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        banner,
        head,
        chipRow,
        ?strip,
        for (final c in children) Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: c),
        bar ?? const SizedBox(height: 16),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 28, 14, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: kMealsRadius, gradient: tone.gradient, boxShadow: tone.glow()),
            child: ClipRRect(borderRadius: kMealsRadius, child: content),
          ),
        ),
        Positioned(
          left: 14 + (narrow ? 12 : 14),
          top: 28 + (narrow ? 126 : 112),
          child: IgnorePointer(child: Art3D(asset: sticker, size: stickerSize, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.3)),
        ),
      ],
    );
  }
}

class _OwnerActionCell extends StatelessWidget {
  const _OwnerActionCell({required this.action, this.stacked = false});

  final OwnerAction action;
  final bool stacked;

  static final TextStyle labelStyle = Ink3D.text(14, FontWeight.w700, Colors.white);

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Color(0x40000000), offset: Offset(3, 4), blurRadius: 6)]),
      child: Icon(action.icon, size: 14, color: action.danger ? StayOwnerInk.danger : Ink3D.body),
    );
    final label = Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: stacked ? TextAlign.center : null, style: labelStyle);
    final cell = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: stacked
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(height: 6), label])
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [icon, const SizedBox(width: 8), Flexible(child: label)],
              ),
      ),
    );
    return Opacity(opacity: action.onTap == null ? 0.45 : 1, child: Tap3D(onTap: action.onTap, label: action.label, child: cell));
  }
}

class OwnerRoomsBox extends StatelessWidget {
  const OwnerRoomsBox({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
              rows[i],
            ],
          ],
        ),
      );
}

class OwnerRoomLine extends StatelessWidget {
  const OwnerRoomLine({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(child: FitOrWrap3D(text: text, style: Ink3D.text(13, FontWeight.w600, Colors.white))),
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      );
}

class OwnerStatusRow extends StatelessWidget {
  const OwnerStatusRow({super.key, required this.art, required this.text, this.trailing, this.onTap, this.light = false, this.ink, this.wideTrailing = false});

  final String art;
  final String text;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool light;
  final Color? ink;
  final bool wideTrailing;

  @override
  Widget build(BuildContext context) {
    final color = ink ?? (light ? StayOwnerInk.newBadge : Colors.white);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final label = Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, color, height: 1.3));
    final icon = Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: Image.asset(art, fit: BoxFit.contain),
    );
    final row = Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: light ? 0.92 : 0.18), borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(builder: (context, c) {
        final stack = wideTrailing && trailing != null && c.maxWidth < 250 * scale;
        if (stack) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [icon, const SizedBox(width: 10), Expanded(child: label)]),
            Padding(padding: const EdgeInsets.only(top: 8, left: 42), child: trailing!),
          ]);
        }
        return Row(
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(child: label),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        );
      }),
    );
    if (onTap == null) return row;
    return Tap3D(onTap: onTap, label: text, child: row);
  }
}

class OnCardBadge3D extends StatelessWidget {
  const OnCardBadge3D(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 58, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Text(text, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, StayOwnerInk.newBadge)),
      );
}

class OnCardChevron3D extends StatelessWidget {
  const OnCardChevron3D({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(Icons.chevron_right_rounded, size: 22, color: color ?? Colors.white.withValues(alpha: 0.85));
}

class PlanStrip3D extends StatelessWidget {
  const PlanStrip3D({super.key, required this.tone, required this.title, this.subtitle, this.subtitleColor, this.art = ListingArt.star, this.actionLabel, this.onAction, this.badge, this.margin = const EdgeInsets.fromLTRB(18, 26, 18, 0)});

  final ListingTone tone;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final String art;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? badge;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final tile = narrow ? 54.0 : 62.0;
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = Ink3D.text(16, FontWeight.w700, Ink3D.title);
    final subStyle = Ink3D.text(13, FontWeight.w400, subtitleColor ?? Ink3D.grey);
    final action = actionLabel == null
        ? null
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: narrow ? 104 : 128),
            child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 40, fontSize: 14, expand: false),
          );
    double lineW(String s, TextStyle st) {
      final p = TextPainter(text: TextSpan(text: s, style: st), maxLines: 1, textDirection: TextDirection.ltr, textScaler: scaler)..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 22, vertical: 18),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: _card68, boxShadow: Form3D.cardShadow),
      child: LayoutBuilder(builder: (context, box) {
        final sub = subtitle;
        final pillW = action == null ? 0.0 : (lineW(actionLabel!, Ink3D.text(14, FontWeight.w700, Ink3D.title)) + 36).clamp(0.0, narrow ? 104.0 : 128.0);
        final textW = box.maxWidth - tile - (narrow ? 12 : 16) - (action == null ? 0 : 8 + pillW);
        final longestTitleWord = title.split(' ').fold<double>(0, (m, w) => w.isEmpty ? m : (lineW(w, titleStyle) > m ? lineW(w, titleStyle) : m));
        final under = action != null && ((sub != null && sub.isNotEmpty && lineW(sub, subStyle) > textW) || longestTitleWord > textW);
        final row = _row(tile, narrow, titleStyle, subStyle, under ? null : action);
        if (!under) return row;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [row, const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: action)],
        );
      }),
    );
  }

  Widget _row(double tile, bool narrow, TextStyle titleStyle, TextStyle subStyle, Widget? action) {
    return Row(
        children: [
          SizedBox(
            width: tile,
            height: tile,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(decoration: BoxDecoration(color: Form3D.wash(tone, 0.14), borderRadius: BorderRadius.circular(18))),
                Positioned(left: -2, top: -12, child: Art3D(asset: art, size: tile + 10, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
              ],
            ),
          ),
          SizedBox(width: narrow ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: subStyle),
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 6), badge!],
          if (action != null) ...[const SizedBox(width: 8), action],
        ],
      );
  }
}

class PhotoTile3D extends StatelessWidget {
  const PhotoTile3D({super.key, required this.image, this.coverLabel, this.onRemove, this.removeTooltip = 'Remove photo'});

  final Widget image;
  final String? coverLabel;
  final VoidCallback? onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(borderRadius: _tile24, boxShadow: StayOwnerInk.tileShadow),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: _tile24, child: image),
            if (coverLabel != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.55)]),
                  ),
                  child: Text(coverLabel!, textAlign: TextAlign.center, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, Colors.white)),
                ),
              ),
            Positioned(
              top: -5,
              right: -5,
              child: Tooltip(
                message: removeTooltip,
                excludeFromSemantics: true,
                child: Tap3D(
                  onTap: onRemove,
                  label: removeTooltip,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Form3D.dangerGradient),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class PhotoAddTile3D extends StatelessWidget {
  const PhotoAddTile3D({super.key, required this.tone, required this.label, required this.onTap, this.art = ListingArt.camera});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final String art;

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        label: label,
        child: Container(
          decoration: BoxDecoration(color: Form3D.wash(tone, 0.12), borderRadius: _tile24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Art3D(asset: art, size: 46, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, tone.text)),
            ],
          ),
        ),
      );
}

class PhotoDropZone3D extends StatelessWidget {
  const PhotoDropZone3D({super.key, required this.tone, required this.title, required this.subtitle, required this.onTap, this.art = ListingArt.camera});

  final ListingTone tone;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String art;

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        label: '$title, $subtitle',
        exclude: true,
        child: CustomPaint(
          painter: _DashedRect(color: Form3D.wash(tone, 0.5), fill: Form3D.wash(tone, 0.06)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 170),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Art3D(asset: art, size: 84, shadowBlur: 5, shadowOffset: const Offset(3, 6), shadowAlpha: 0.25),
                  const SizedBox(height: 2),
                  Text(title, maxLines: 2, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w700, tone.text)),
                  Text(subtitle, maxLines: 2, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _DashedRect extends CustomPainter {
  _DashedRect({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndCorners(Offset.zero & size, topLeft: const Radius.circular(8), topRight: const Radius.circular(30), bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = fill);
    final path = Path()..addRRect(rrect.deflate(1));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRect old) => old.color != color || old.fill != fill;
}

class HintLine3D extends StatelessWidget {
  const HintLine3D({super.key, required this.text, this.art = ListingArt.pushpin, this.busy = false, this.tone});

  final String text;
  final String art;
  final bool busy;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(art, width: 22, height: 22, fit: BoxFit.contain),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, height: 1.4))),
            if (busy) ...[
              const SizedBox(width: 6),
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: (tone ?? ListingTone.forest).g2)),
            ],
          ],
        ),
      );
}

class MapFrame3D extends StatelessWidget {
  const MapFrame3D({super.key, required this.child, this.onMyLocation, this.height = 340, this.myLocationTooltip = 'My location'});

  final Widget child;
  final VoidCallback? onMyLocation;
  final double height;
  final String myLocationTooltip;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: StayOwnerInk.mapBase, child: child)),
              Positioned(
                right: 10,
                bottom: 10,
                child: Tooltip(
                  message: myLocationTooltip,
                  excludeFromSemantics: true,
                  child: Tap3D(
                    onTap: onMyLocation,
                    label: myLocationTooltip,
                    child: Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: StayOwnerInk.roundButton),
                      child: Image.asset(ListingArt.compass, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class MapWait3D extends StatelessWidget {
  const MapWait3D({super.key, required this.tone, required this.text, this.height = 340});

  final ListingTone tone;
  final String text;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: height,
          color: StayOwnerInk.waitBase,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Art3D(asset: ListingArt.compass, size: 96, shadowBlur: 6, shadowOffset: Offset(4, 7)),
              const SizedBox(height: 14),
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: tone.g2)),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w500, StayOwnerInk.sectionLabel)),
            ],
          ),
        ),
      );
}

class CoordsLine3D extends StatelessWidget {
  const CoordsLine3D({super.key, required this.tone, required this.text, required this.credit});

  final ListingTone tone;
  final String text;
  final String credit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tone.g2),
              child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, tone.g2))),
            const SizedBox(width: 8),
            Expanded(child: Text(credit, maxLines: 1, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w400, Ink3D.grey))),
          ],
        ),
      );
}

class GpsDot3D extends StatelessWidget {
  const GpsDot3D({super.key, required this.tone});

  final ListingTone tone;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Form3D.wash(tone, 0.2)),
        child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: tone.g2)),
      );
}

class LinkLine3D extends StatelessWidget {
  const LinkLine3D({super.key, required this.text, required this.onTap, required this.color, this.center = false, this.padding = const EdgeInsets.fromLTRB(8, 4, 8, 0)});

  final String text;
  final VoidCallback? onTap;
  final Color color;
  final bool center;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Align(
          alignment: center ? Alignment.center : Alignment.centerLeft,
          child: Tap3D(
            onTap: onTap,
            label: text,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Align(
                widthFactor: 1,
                alignment: center ? Alignment.center : Alignment.centerLeft,
                child: Text(text, textAlign: center ? TextAlign.center : TextAlign.start, style: Ink3D.text(13, FontWeight.w700, color)),
              ),
            ),
          ),
        ),
      );
}

abstract final class StayOwnerShapes {
  static const BorderRadius card54 = _card54;
  static const BorderRadius card68 = _card68;
}
