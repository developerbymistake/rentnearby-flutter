import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiLook {
  static const Color greyG1 = Color(0xFF9AA3B5);
  static const Color greyG2 = Color(0xFF6B7488);
  static const Color greyShadow = Color(0x66505A6E);
  static final ListingTone grey = const ListingTone(g1: greyG1, g2: greyG2, shadow: greyShadow, haloBase: greyG2, text: greyG2);
  static final ListingTone tealDeep = const ListingTone(
    g1: Color(0xFF1FA396),
    g2: Color(0xFF14756B),
    shadow: Color(0x8014756B),
    haloBase: Color(0xFF14756B),
    text: Color(0xFF14756B),
  );
  static const Color sunriseText = Color(0xFFB85A12);
  static const Color redText = Color(0xFFB83A40);
  static const Color redSoft = Color(0xFFFDE6E8);
  static const Color amberSoft = Color(0xFFFFF4E0);
  static const Color amberText = Color(0xFF8A5200);
  static const Color accentSoft = Color(0xFFFFF1EC);
  static const Color accentText = Color(0xFFB83A40);
  static const Color greenSoft = Color(0xFFE3F1E4);
  static const Color greenText = Color(0xFF17501B);
  static const Color tealSoft = Color(0xFFE6F6F3);
  static const Color rowLine = Color(0xFFEEF0F4);
  static const Color lockedRow = Color(0xFFF7F8FD);
  static const Color dangerLine = Color(0xFFF0B7BB);
  static const Color artTint = Color(0x24E0525C);
  static const Color artTintRed = Color(0x24E0525C);
  static const Color artTintAmber = Color(0x2EF2A93B);
  static const Color artTintTeal = Color(0x291FA396);

  static BorderRadius cardRadius(double topRight) => DS.br(topRight >= 36 ? CardRadius.hero : topRight >= 26 ? CardRadius.tile : CardRadius.card);
}

class TaxiHeroCard extends StatelessWidget {
  const TaxiHeroCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.pill,
    this.line,
    this.extra,
    this.margin,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? pill;
  final String? line;
  final Widget? extra;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Padding(
      padding: margin ?? DS.insets(l: 18, t: 20, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: TaxiLook.cardRadius(54), gradient: tone.gradient, boxShadow: tone.glow()),
        child: Padding(
          padding: DS.insets(l: 16, t: 16, r: 20, b: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(child: Art3D(asset: art, size: 66, halo: 84, haloColor: white.withValues(alpha: Alpha.v22))),
              Gap.h(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: DS.gh(8),
                      runSpacing: DS.gv(4),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(title, style: Ink3D.text(19, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
                        if (pill != null)
                          DecoratedBox(
                            decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), borderRadius: DS.circular(8)),
                            child: Padding(
                              padding: DS.sym(h: 8, v: 2),
                              child: Text(pill!, style: Ink3D.text(10, FontWeight.w700, white, letterSpacing: 0)),
                            ),
                          ),
                      ],
                    ),
                    if (line != null)
                      Padding(
                        padding: EdgeInsets.only(top: DS.gv(4)),
                        child: Text(line!, style: Ink3D.text(12.5, FontWeight.w500, white.withValues(alpha: Alpha.v92), height: 1.35, letterSpacing: 0)),
                      ),
                    if (extra != null) Padding(padding: EdgeInsets.only(top: DS.gv(8)), child: extra),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaxiWhitePill extends StatelessWidget {
  const TaxiWhitePill({super.key, required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(48)),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(22), boxShadow: DS.shadows(Ink3D.whiteBtn)),
                child: Padding(
                  padding: DS.sym(h: 18, v: 9),
                  child: Text(label, style: Ink3D.text(14, FontWeight.w700, color, letterSpacing: 0)),
                ),
              ),
            ),
          ),
        ),
      );
}

enum TaxiPillKind { teal, coral, white, outline, danger, off }

class TaxiPill extends StatelessWidget {
  const TaxiPill({super.key, required this.label, required this.kind, this.onTap, this.busy = false, this.expand = false});

  final String label;
  final TaxiPillKind kind;
  final VoidCallback? onTap;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final filled = kind == TaxiPillKind.teal || kind == TaxiPillKind.coral;
    final gradient = switch (kind) {
      TaxiPillKind.teal => TaxiLook.tealDeep.gradient,
      TaxiPillKind.coral => ListingTone.coral.gradient,
      _ => null,
    };
    final fg = switch (kind) {
      TaxiPillKind.teal || TaxiPillKind.coral => Colors.white,
      TaxiPillKind.danger => TaxiLook.redText,
      TaxiPillKind.off => Ink3D.grey,
      _ => TaxiLook.accentText,
    };
    final border = switch (kind) {
      TaxiPillKind.outline => Border.all(color: TaxiLook.accentText, width: DS.s(1.5)),
      TaxiPillKind.danger => Border.all(color: TaxiLook.dangerLine, width: DS.s(1.5)),
      _ => null,
    };
    return Semantics(
      button: true,
      enabled: onTap != null && !busy,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(48), minWidth: DS.s(48)),
          child: Center(
            widthFactor: expand ? null : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient,
                color: gradient == null ? (kind == TaxiPillKind.off ? TaxiLook.rowLine : Colors.white) : null,
                borderRadius: DS.circular(20),
                border: border,
                boxShadow: kind == TaxiPillKind.white || filled ? DS.shadows(Ink3D.whiteBtn) : null,
              ),
              child: Padding(
                padding: DS.sym(h: 14, v: 8),
                child: expand
                    ? SizedBox(width: double.infinity, child: Text(label, maxLines: 1, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w700, fg, letterSpacing: 0)))
                    : Text(label, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, fg, letterSpacing: 0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TaxiRowData {
  const TaxiRowData({required this.art, required this.title, this.sub, this.trailing, this.onTap, this.tint = TaxiLook.artTint, this.locked = false, this.semantics, this.titleColor});

  final String art;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color tint;
  final bool locked;
  final String? semantics;
  final Color? titleColor;
}

class TaxiRowsCard extends StatelessWidget {
  const TaxiRowsCard({super.key, required this.rows, this.margin, this.fill = Colors.white});

  final List<TaxiRowData> rows;
  final EdgeInsets? margin;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: margin ?? DS.insets(l: 18, t: 14, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: DS.br(CardRadius.tile), boxShadow: fill == Colors.white ? DS.shadows(Ink3D.softShadow) : null),
        child: ClipRRect(
          borderRadius: DS.br(CardRadius.tile),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: TaxiLook.rowLine),
                TaxiRowTile(data: rows[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TaxiRowTile extends StatelessWidget {
  const TaxiRowTile({super.key, required this.data});

  final TaxiRowData data;

  @override
  Widget build(BuildContext context) {
    final tile = ColoredBox(
      color: data.locked ? TaxiLook.lockedRow : Colors.transparent,
      child: Padding(
        padding: DS.sym(h: 14, v: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(56)),
          child: Row(
            children: [
              SizedBox(
                width: DS.s(56),
                height: DS.s(56),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: data.tint, borderRadius: DS.circular(16)),
                  child: Center(child: ExcludeSemantics(child: Art3D(asset: data.art, size: 42, shadowBlur: 4, shadowOffset: const Offset(3, 4)))),
                ),
              ),
              Gap.h(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(data.title, style: Ink3D.text(15, FontWeight.w500, data.titleColor ?? Ink3D.title, height: 1.3, letterSpacing: 0)),
                    if (data.sub != null)
                      Padding(
                        padding: EdgeInsets.only(top: DS.gv(3)),
                        child: Text(data.sub!, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, height: 1.35, letterSpacing: 0)),
                      ),
                  ],
                ),
              ),
              if (data.trailing != null) ...[Gap.h(8), data.trailing!],
            ],
          ),
        ),
      ),
    );
    if (data.onTap == null) return tile;
    return InkWell(onTap: data.onTap, child: Semantics(container: true, label: data.semantics, child: tile));
  }
}

class TaxiSectionTitle extends StatelessWidget {
  const TaxiSectionTitle({super.key, required this.title, this.meter, this.trailing});

  final String title;
  final String? meter;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final head = Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: Text(title, style: Ink3D.text(19, FontWeight.w600, Ink3D.body, letterSpacing: 0))),
          if (meter != null) ...[
            Gap.h(10),
            Flexible(child: Text(meter!, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy, letterSpacing: 0))),
          ],
        ],
      ),
    );
    return Padding(
      padding: DS.insets(l: 18, t: 22, r: 18),
      child: trailing == null ? head : Row(children: [Expanded(child: head), Gap.h(8), trailing!]),
    );
  }
}

class TaxiStrip extends StatelessWidget {
  const TaxiStrip({super.key, required this.art, required this.text, required this.fill, required this.ink, this.action, this.onAction, this.margin, this.actionKind = TaxiPillKind.white});

  final TaxiPillKind actionKind;
  final String art;
  final String text;
  final Color fill;
  final Color ink;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin ?? DS.insets(l: 18, t: 14, r: 18),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, borderRadius: DS.circular(14)),
            child: Padding(
              padding: DS.sym(h: 14, v: 10),
              child: Row(
                children: [
                  ExcludeSemantics(child: Art3D(asset: art, size: 32, shadowBlur: 3, shadowOffset: const Offset(2, 3))),
                  Gap.h(12),
                  Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, ink, height: 1.35, letterSpacing: 0))),
                  if (action != null) ...[Gap.h(8), TaxiPill(label: action!, kind: actionKind, onTap: onAction)],
                ],
              ),
            ),
          ),
        ),
      );
}

class TaxiRail extends StatelessWidget {
  const TaxiRail({super.key, required this.tiles});

  final List<TaxiRailTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      child: MealsRail(
        physics: const BouncingScrollPhysics(),
        children: [
          for (final t in tiles)
            MealsCardV(
              tone: t.tone,
              art: t.art,
              title: t.title,
              description: t.sub,
              goIcon: t.add ? Icons.add : Icons.arrow_forward,
              onTap: t.onTap,
              semanticsLabel: t.title,
              titleLines: 2,
            ),
        ],
      ),
    );
  }
}

class TaxiRailTile {
  const TaxiRailTile({required this.tone, required this.art, required this.title, required this.sub, required this.onTap, this.add = false});

  final ListingTone tone;
  final String art;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool add;
}

class TaxiErrorCard extends StatelessWidget {
  const TaxiErrorCard({super.key, required this.art, required this.title, this.message, this.action, this.onAction, this.margin});

  final String art;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin ?? DS.insets(l: 18, t: 20, r: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: TaxiLook.cardRadius(68), boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Padding(
            padding: DS.insets(l: 18, t: 28, r: 18, b: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: ExcludeSemantics(child: Art3D(asset: art, size: 76))),
                Gap.v(10),
                Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(18, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
                if (message != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.gv(6)),
                    child: Text(message!, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, height: 1.4, letterSpacing: 0)),
                  ),
                if (action != null && onAction != null) ...[
                  Gap.v(18),
                  GradientPillButton(tone: ListingTone.coral, label: action!, onTap: onAction),
                ],
              ],
            ),
          ),
        ),
      );
}


class TaxiStatusRow {
  const TaxiStatusRow({required this.label, required this.value});

  final String label;
  final String value;
}

class TaxiStatusCard extends StatelessWidget {
  const TaxiStatusCard({super.key, required this.tone, required this.art, required this.title, required this.line, this.trailing, this.rows = const [], this.note, this.margin, this.body, this.photoUrl});

  final ListingTone tone;
  final String art;
  static const photoKey = ValueKey('taxi-status-photo');

  final String? photoUrl;
  final String title;
  final String line;
  final Widget? trailing;
  final List<TaxiStatusRow> rows;
  final String? note;
  final EdgeInsets? margin;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final radius = TaxiLook.cardRadius(54);
    return Padding(
      padding: margin ?? DS.insets(l: 18, t: 20, r: 18),
      child: Semantics(
        container: true,
        label: '$title, $line',
        child: DecoratedBox(
          decoration: BoxDecoration(color: white, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(gradient: tone.gradient),
                  child: Padding(
                    padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: photoUrl == null
                              ? Art3D(asset: art, size: 46, halo: 56, haloColor: white.withValues(alpha: Alpha.v22))
                              : KitPhoto(
                                  key: TaxiStatusCard.photoKey,
                                  url: photoUrl,
                                  width: DS.s(46),
                                  height: DS.s(46),
                                  radius: KitMetrics.tileSmall,
                                  tone: KitTone.taxiDriver,
                                  asset: art,
                                  iconSize: 20,
                                ),
                        ),
                        Gap.h(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
                              Padding(
                                padding: EdgeInsets.only(top: DS.gv(2)),
                                child: Text(line, style: Ink3D.text(11.5, FontWeight.w500, white.withValues(alpha: Alpha.v92), height: 1.3, letterSpacing: 0)),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null) ...[Gap.h(8), trailing!],
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: DS.s(16), endIndent: DS.s(16), color: TaxiLook.rowLine),
                  Padding(
                    padding: DS.sym(h: 16, v: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(rows[i].label, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0))),
                        Gap.h(8),
                        Text(rows[i].value, style: Ink3D.text(12.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                      ],
                    ),
                  ),
                ],
                ?body,
                if (note != null)
                  Padding(
                    padding: DS.insets(l: 16, t: 0, r: 16, b: 10),
                    child: Text(note!, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.35, letterSpacing: 0)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaxiCarRow extends StatelessWidget {
  const TaxiCarRow({super.key, required this.art, required this.name, this.sub});

  final String art;
  final String name;
  final String? sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 16, t: 10, r: 16, b: 10),
        child: Row(
          children: [
            ExcludeSemantics(child: Art3D(asset: art, size: 32, shadowBlur: 3, shadowOffset: const Offset(2, 3))),
            Gap.h(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  if (sub != null)
                    Padding(
                      padding: EdgeInsets.only(top: DS.gv(2)),
                      child: Text(sub!, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.35, letterSpacing: 0)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class TaxiRingStripView extends StatelessWidget {
  const TaxiRingStripView({
    super.key,
    required this.title,
    required this.body,
    required this.fill,
    required this.ink,
    this.greyArt = false,
    this.action,
    this.onAction,
  });

  final String title;
  final String body;
  final Color fill;
  final Color ink;
  final bool greyArt;
  final String? action;
  final VoidCallback? onAction;

  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.7, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final art = Art3D(asset: ListingArt.bell, size: 32, shadowBlur: 3, shadowOffset: const Offset(2, 3));
    return Padding(
      padding: DS.insets(l: 16, t: 4, r: 16, b: 14),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill, borderRadius: DS.circular(14)),
          child: Padding(
            padding: DS.sym(h: 14, v: 10),
            child: Row(
              children: [
                ExcludeSemantics(child: greyArt ? ColorFiltered(colorFilter: _grey, child: art) : art),
                Gap.h(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: Ink3D.text(12.5, FontWeight.w600, ink, height: 1.35, letterSpacing: 0)),
                      Text(body, style: Ink3D.text(11.5, FontWeight.w400, ink, height: 1.35, letterSpacing: 0)),
                    ],
                  ),
                ),
                if (action != null) ...[Gap.h(8), TaxiPill(label: action!, kind: TaxiPillKind.coral, onTap: onAction)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaxiLabel extends StatelessWidget {
  const TaxiLabel({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 18, t: 22, r: 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(text, style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.6)),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

class TaxiPageHeader extends StatelessWidget {
  const TaxiPageHeader({super.key, required this.title, this.subtitle, this.onBack, this.asset = ListingArt.bell, this.trailing});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final String asset;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: PageHeader3D(
          tone: ListingTone.coral,
          title: title,
          subtitle: subtitle,
          art: asset,
          artSize: 65,
          onBack: onBack ?? () => Navigator.maybePop(context),
          trailing: trailing,
        ),
      );
}

abstract final class TaxiConfirm {
  static Future<bool> ask(BuildContext context, {required String title, required String body, required String confirm, required String cancel}) async {
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (c) => Dialog3D(
        tone: ListingTone.coral,
        art: ListingArt.warning,
        title: title,
        body: body,
        familyCorner: true,
        tight: true,
        titleSize: 18,
        actions: [
          TaxiPill(label: confirm, kind: TaxiPillKind.danger, expand: true, onTap: () => Navigator.of(c).pop(true)),
          Gap.v(8),
          TaxiPill(label: cancel, kind: TaxiPillKind.white, expand: true, onTap: () => Navigator.of(c).pop(false)),
        ],
      ),
    );
    return ok == true;
  }
}

class TaxiDeleteRow extends StatelessWidget {
  const TaxiDeleteRow({super.key, required this.title, required this.sub, required this.busy, required this.onDelete});

  final String title;
  final String sub;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => TaxiRowsCard(rows: [
        TaxiRowData(
          art: ListingArt.warning,
          tint: TaxiLook.artTintRed,
          title: title,
          titleColor: TaxiLook.redText,
          sub: sub,
          trailing: TaxiPill(label: OwnerSharedStrings.delete, kind: TaxiPillKind.danger, busy: busy, onTap: onDelete),
          onTap: busy ? null : onDelete,
        ),
      ]);
}
