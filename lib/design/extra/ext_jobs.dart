import 'package:flutter/material.dart';

import '../design.dart';

abstract final class JobsLook {
  static final ListingTone page = ListingTone.indigo;
  static Color get pageColor => ListingPalette.indigo.page;
  static final List<ListingTone> _cards = [ListingTone.cB, ListingTone.cD, ListingTone.cC, ListingTone.cA];
  static ListingTone card(int i) => _cards[i % _cards.length];
  static const ListingTone closed = ListingTone(
    g1: Color(0xFFBFC3CE),
    g2: Color(0xFF8C91A0),
    shadow: Color(0x73787E8C),
    haloBase: Color(0xFF8C91A0),
    text: Color(0xFF5F6472),
  );
  static const Color muted = Color(0xFF8A8F99);
  static const Color about = Color(0xFF3D4A50);
  static const Color clearFill = Color(0xFFF2F3F8);
  static const Color bannerFill = Color(0xFFFFE9E7);
  static const Color bannerText = Color(0xFFC0392B);
  static const List<BoxShadow> card3 = [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)];
  static const List<BoxShadow> pill = [BoxShadow(color: Color(0x669E9E9E), offset: Offset(3, 5), blurRadius: 10)];
  static const List<BoxShadow> field = [BoxShadow(color: Color(0x599E9E9E), offset: Offset(3, 5), blurRadius: 12)];
  static List<BoxShadow> toneGlow(ListingTone t) => [BoxShadow(color: t.haloBase.withValues(alpha: 0.5), offset: const Offset(1.1, 5), blurRadius: 10)];
  static Color soft(ListingTone t) => t.haloBase.withValues(alpha: 0.14);
  static Color halo(ListingTone t) => t.haloBase.withValues(alpha: 0.16);
  static const BorderRadius tileRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
  static const BorderRadius infoRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
}

class JobsBackButton extends StatelessWidget {
  const JobsBackButton({super.key, required this.tone, required this.onTap, this.size = 46});

  final ListingTone tone;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return SizedBox(width: size, height: size);
    return Tooltip(
      message: 'Back',
      excludeFromSemantics: true,
      child: Tap3D(
        onTap: onTap,
        label: 'Back',
        exclude: true,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: JobsLook.pill),
          child: Icon(Icons.chevron_left_rounded, size: 28, color: tone.text),
        ),
      ),
    );
  }
}

class JobsHeader extends StatelessWidget {
  const JobsHeader({super.key, required this.tone, required this.title, required this.art, this.subtitle, this.onBack});

  final ListingTone tone;
  final String title;
  final String art;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final size = narrow ? 96.0 : 124.0;
    final clear = size + 16;
    final sub = subtitle;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 10,
          top: 6,
          child: ExcludeSemantics(child: Art3D(asset: art, size: size, halo: size + 6, haloColor: JobsLook.halo(tone))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size - 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sub == null) const SizedBox(height: 30),
                Padding(
                  padding: EdgeInsets.only(right: clear),
                  child: Row(
                    children: [
                      JobsBackButton(tone: tone, onTap: onBack),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: _JobsTitle(title, Ink3D.text(narrow ? 24 : 28, FontWeight.w700, Ink3D.title, height: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (sub != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 8, clear, 0),
                    child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, letterSpacing: 0, height: 1.35)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JobsTitle extends StatelessWidget {
  const _JobsTitle(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final p = TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context))..layout();
      final w = p.width;
      p.dispose();
      if (w > box.maxWidth && w <= box.maxWidth * 1.3) {
        return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text, maxLines: 1, softWrap: false, style: style));
      }
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
    });
  }
}

class JobsPlaceBar extends StatelessWidget {
  const JobsPlaceBar({
    super.key,
    required this.tone,
    required this.label,
    required this.onPlaceTap,
    required this.actionLabel,
    required this.onAction,
    this.onClear,
    this.cancel = false,
  });

  final ListingTone tone;
  final String label;
  final VoidCallback? onPlaceTap;
  final VoidCallback? onClear;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool cancel;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final clear = onClear;
    final end = clear != null
        ? Tap3D(
            onTap: clear,
            label: 'Clear',
            child: SizedBox(
              width: 40,
              height: 44,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(color: JobsLook.clearFill, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 17, color: Ink3D.body),
                ),
              ),
            ),
          )
        : Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: JobsLook.clearFill, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_drop_down_rounded, size: 22, color: Ink3D.body),
          );
    final field = Tap3D(
      onTap: onPlaceTap,
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(38), boxShadow: JobsLook.field),
        child: Row(
          children: [
            ExcludeSemantics(child: Art3D(asset: ListingArt.roundPushpin, size: narrow ? 34 : 44, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25)),
            SizedBox(width: narrow ? 8 : 12),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w400, Ink3D.body, letterSpacing: 0))),
            const SizedBox(width: 6),
            end,
          ],
        ),
      ),
    );
    final ink = cancel ? tone.text : Colors.white;
    final action = Tap3D(
      onTap: onAction,
      label: actionLabel,
      exclude: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: EdgeInsets.symmetric(horizontal: narrow ? 14 : 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: cancel ? null : tone.gradient,
          color: cancel ? Colors.white : null,
          boxShadow: cancel ? JobsLook.pill : JobsLook.toneGlow(tone),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cancel) ...[Icon(Icons.close_rounded, size: 18, color: ink), const SizedBox(width: 6)],
            Text(actionLabel, maxLines: 1, style: Ink3D.text(15, FontWeight.w700, ink, letterSpacing: 0)),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(children: [Expanded(child: field), const SizedBox(width: 10), action]),
    );
  }
}

class JobsFilterTile extends StatelessWidget {
  const JobsFilterTile({super.key, required this.tone, required this.art, required this.label, required this.selected, required this.onTap});

  final ListingTone tone;
  final String art;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const double topRoom = 22;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: selected,
      exclude: true,
      child: Opacity(
        opacity: selected ? 1 : 0.62,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: topRoom),
              child: Container(
                constraints: const BoxConstraints(minHeight: 74),
                padding: const EdgeInsets.fromLTRB(10, 38, 8, 10),
                alignment: Alignment.bottomLeft,
                decoration: BoxDecoration(borderRadius: JobsLook.tileRadius, gradient: tone.gradient, boxShadow: selected ? tone.glow(blur: 8) : const []),
                child: _TileSize.of(context) == null
                    ? FitLine3D(text: label, stretch: 1.45, style: Ink3D.text(13, FontWeight.w700, Colors.white, letterSpacing: 0))
                    : Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: Ink3D.text(_TileSize.of(context)!, FontWeight.w700, Colors.white, letterSpacing: 0)),
              ),
            ),
            Positioned(left: 4, top: 0, child: ExcludeSemantics(child: Art3D(asset: art, size: 58, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28))),
            Positioned(
              right: 8,
              top: topRoom + 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), shape: BoxShape.circle),
                child: Icon(Icons.arrow_drop_down_rounded, size: 20, color: tone.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileSize extends InheritedWidget {
  const _TileSize({required this.size, required super.child});

  final double size;

  static double? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_TileSize>()?.size;

  @override
  bool updateShouldNotify(_TileSize old) => old.size != size;
}

class JobsFilterTiles extends StatelessWidget {
  const JobsFilterTiles({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: LayoutBuilder(
        builder: (context, box) {
          final room = (box.maxWidth - 10 * (children.length - 1)) / children.length - 18;
          var size = 13.0;
          for (final c in children.whereType<JobsFilterTile>()) {
            final w = KitText.widthOf(c.label, Ink3D.text(13, FontWeight.w700, Colors.white, letterSpacing: 0), scaler);
            if (w > room) size = size < 13 * room / w ? size : 13 * room / w;
          }
          return _TileSize(
            size: size.clamp(9.0, 13.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: children[i])],
              ],
            ),
          );
        },
      ),
    );
  }
}

class JobsFilterButton extends StatelessWidget {
  const JobsFilterButton({super.key, required this.tone, required this.active, required this.onTap, this.label = 'Filter'});

  final ListingTone tone;
  final bool active;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = active ? Colors.white : tone.text;
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: active ? tone.gradient : null,
          color: active ? null : Colors.white,
          boxShadow: active ? JobsLook.toneGlow(tone) : JobsLook.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, maxLines: 1, style: Ink3D.text(14, FontWeight.w700, ink, letterSpacing: 0)),
            const SizedBox(width: 6),
            Icon(Icons.menu_rounded, size: 16, color: ink),
          ],
        ),
      ),
    );
  }
}

class JobsStateBlock extends StatelessWidget {
  const JobsStateBlock({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionEnabled = true,
    this.hint,
    this.linkLabel,
    this.onLink,
    this.padding = const EdgeInsets.fromLTRB(30, 34, 30, 16),
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionEnabled;
  final String? hint;
  final String? linkLabel;
  final VoidCallback? onLink;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final msg = message;
    final h = hint;
    final link = linkLabel;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Art3D(asset: art, size: narrow ? 140 : 168, halo: narrow ? 156 : 184, haloColor: tone.haloBase.withValues(alpha: 0.15), shadowBlur: 10, shadowOffset: const Offset(8, 12), shadowAlpha: 0.25),
          ),
          const SizedBox(height: 14),
          Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.3))),
          if (msg != null && msg.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, Ink3D.copy, height: 1.45))),
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: SizedBox(width: 220, child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, enabled: actionEnabled && onAction != null, height: 52)),
            ),
          if (h != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(h, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, height: 1.4))),
          if (link != null)
            Tap3D(
              onTap: onLink,
              label: link,
              exclude: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(link, style: Ink3D.text(14, FontWeight.w700, tone.text)),
              ),
            ),
        ],
      ),
    );
  }
}

class JobsOptionRow extends StatelessWidget {
  const JobsOptionRow({super.key, required this.tone, required this.label, required this.selected, required this.onTap, this.divider = true});

  final ListingTone tone;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: selected,
      exclude: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: Ink3D.line)) : null),
        child: Row(
          children: [
            Expanded(
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, selected ? FontWeight.w700 : FontWeight.w400, selected ? tone.text : Ink3D.body, letterSpacing: 0)),
            ),
            if (selected)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: tone.gradient, boxShadow: [BoxShadow(color: tone.haloBase.withValues(alpha: 0.45), offset: const Offset(1, 3), blurRadius: 6)]),
                child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class JobsSheetLabel extends StatelessWidget {
  const JobsSheetLabel(this.text, {super.key, this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? 2 : 12, bottom: 8),
    child: Text(text, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
  );
}

class JobsSheetMessage extends StatelessWidget {
  const JobsSheetMessage({super.key, required this.tone, required this.art, this.title, this.body, this.actionLabel, this.onAction, this.loading = false});

  final ListingTone tone;
  final String art;
  final String? title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Art3D(asset: art, size: 168, halo: 190, haloColor: tone.haloBase.withValues(alpha: 0.15), shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.25)),
            const SizedBox(height: 12),
            if (loading)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: tone.g2)),
              ),
            if (title != null) Text(title!, textAlign: TextAlign.center, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
            if (body != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(body!, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.grey, height: 1.4))),
            if (actionLabel != null && onAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 44, expand: false, fontSize: 15),
              ),
          ],
        ),
      ),
    );
  }
}

class JobsDetailHero extends StatelessWidget {
  const JobsDetailHero({super.key, required this.tone, required this.height, this.photo, this.onTap});

  final ListingTone tone;
  final double height;
  final Widget? photo;
  final VoidCallback? onTap;

  static const double seam = 26;

  @override
  Widget build(BuildContext context) {
    final p = photo;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: p ??
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: tone.gradient),
                    child: Align(
                      alignment: const Alignment(0, 0.04),
                      child: ExcludeSemantics(
                        child: Art3D(asset: ListingArt.backpack, size: 132, halo: 150, haloColor: Colors.white.withValues(alpha: 0.22), shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.3),
                      ),
                    ),
                  ),
            ),
          ),
          if (p != null)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 120,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73000000), Color(0x00000000)])),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: seam,
            child: DecoratedBox(
              decoration: BoxDecoration(color: JobsLook.pageColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(seam))),
            ),
          ),
          if (p != null)
            Positioned(
              right: 16,
              bottom: -18,
              child: IgnorePointer(
                child: ExcludeSemantics(child: Art3D(asset: ListingArt.hotel, size: narrow ? 88 : 104, halo: narrow ? 96 : 112, haloColor: tone.haloBase.withValues(alpha: 0.18), shadowBlur: 6, shadowOffset: const Offset(5, 8), shadowAlpha: 0.3)),
              ),
            ),
        ],
      ),
    );
  }
}

class JobsTagPill extends StatelessWidget {
  const JobsTagPill({super.key, required this.tone, required this.label, this.solid = false});

  final ListingTone tone;
  final String label;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: solid ? tone.gradient : null,
        color: solid ? null : JobsLook.soft(tone),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, solid ? Colors.white : tone.text, letterSpacing: 0.4)),
    );
  }
}

class JobsInfoCard extends StatelessWidget {
  const JobsInfoCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: JobsLook.infoRadius, boxShadow: JobsLook.card3),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class JobsInfoRow extends StatelessWidget {
  const JobsInfoRow({super.key, required this.tone, required this.art, required this.label, required this.value, this.onTap, this.divider = true});

  final ListingTone tone;
  final String art;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: Ink3D.line)) : null),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: JobsLook.soft(tone), borderRadius: BorderRadius.circular(14)))),
                Positioned(left: -3, top: -8, child: ExcludeSemantics(child: Art3D(asset: art, size: 50, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25))),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, JobsLook.muted, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '-' : value, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              ],
            ),
          ),
          if (onTap != null) ...[const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, size: 26, color: tone.text)],
        ],
      ),
    );
    if (onTap == null) return row;
    return Tap3D(onTap: onTap, label: '$label $value', child: row);
  }
}

class JobsNoteCard extends StatelessWidget {
  const JobsNoteCard({super.key, required this.art, required this.text});

  final String art;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: JobsLook.tileRadius, boxShadow: JobsLook.card3),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 36, shadowBlur: 3, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Ink3D.text(15, FontWeight.w700, Ink3D.sub, letterSpacing: 0))),
        ],
      ),
    );
  }
}

class JobsArtLine extends StatelessWidget {
  const JobsArtLine({super.key, required this.art, required this.text});

  final String art;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(child: Art3D(asset: art, size: 30, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, JobsLook.muted, letterSpacing: 0))),
      ],
    );
  }
}

class JobsLimitBanner extends StatelessWidget {
  const JobsLimitBanner({super.key, required this.tone, required this.message, this.linkLabel, this.onLink});

  final ListingTone tone;
  final String message;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final link = linkLabel;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: const BoxDecoration(color: JobsLook.bannerFill, borderRadius: JobsLook.tileRadius),
      child: Row(
        children: [
          const ExcludeSemantics(child: Art3D(asset: ListingArt.moneyBag, size: 34, shadowBlur: 3, shadowOffset: Offset(2, 3), shadowAlpha: 0.25)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: Ink3D.text(13, FontWeight.w600, JobsLook.bannerText, letterSpacing: 0, height: 1.4))),
          if (link != null)
            Tap3D(
              onTap: onLink,
              label: link,
              exclude: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(link, style: Ink3D.text(14, FontWeight.w700, tone.text, letterSpacing: 0)),
              ),
            ),
        ],
      ),
    );
  }
}
