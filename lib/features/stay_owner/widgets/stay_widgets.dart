import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class StayLook {
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
  static const Color indigoSoft = Color(0xFFE9ECFB);
  static const Color indigoText = DesignColors.brandNavy;
  static const Color greenSoft = Color(0xFFE3F1E4);
  static const Color greenText = Color(0xFF17501B);
  static const Color tealSoft = Color(0xFFE6F6F3);
  static const Color rowLine = Color(0xFFEEF0F4);
  static const Color lockedRow = Color(0xFFF7F8FD);
  static const Color dangerLine = Color(0xFFF0B7BB);
  static const Color artTint = DesignColors.brandRoyal14;
  static const Color artTintRed = Color(0x24E0525C);
  static const Color artTintAmber = Color(0x2EF2A93B);
  static const Color artTintTeal = Color(0x291FA396);

  static BorderRadius cardRadius(double topRight) => DS.br(topRight >= 36 ? CardRadius.hero : topRight >= 26 ? CardRadius.tile : CardRadius.card);
}

class StayHeroCard extends StatelessWidget {
  const StayHeroCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.pill,
    this.line,
    this.extra,
    this.margin,
    this.trailing,
    this.body,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? pill;
  final String? line;
  final Widget? extra;
  final EdgeInsets? margin;
  final Widget? trailing;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final radius = StayLook.cardRadius(54);
    final band = Padding(
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
          if (trailing != null) ...[Gap.h(8), trailing!],
        ],
      ),
    );
    if (body == null) {
      return Padding(
        padding: margin ?? DS.insets(l: 18, t: 20, r: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, gradient: tone.gradient, boxShadow: tone.glow()),
          child: band,
        ),
      );
    }
    return Padding(
      padding: margin ?? DS.insets(l: 18, t: 20, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: white, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: tone.gradient), child: band),
              body!,
            ],
          ),
        ),
      ),
    );
  }
}

class StayWhitePill extends StatelessWidget {
  const StayWhitePill({super.key, required this.label, required this.color, this.onTap});

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

enum StayPillKind { teal, indigo, forest, white, outline, danger, off }

class StayPill extends StatelessWidget {
  const StayPill({super.key, required this.label, required this.kind, this.onTap, this.busy = false, this.expand = false});

  final String label;
  final StayPillKind kind;
  final VoidCallback? onTap;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final filled = kind == StayPillKind.teal || kind == StayPillKind.indigo || kind == StayPillKind.forest;
    final gradient = switch (kind) {
      StayPillKind.teal => StayLook.tealDeep.gradient,
      StayPillKind.indigo => ListingTone.indigo.gradient,
      StayPillKind.forest => ListingTone.forest.gradient,
      _ => null,
    };
    final fg = switch (kind) {
      StayPillKind.teal || StayPillKind.indigo || StayPillKind.forest => Colors.white,
      StayPillKind.danger => StayLook.redText,
      StayPillKind.off => Ink3D.grey,
      _ => StayLook.indigoText,
    };
    final border = switch (kind) {
      StayPillKind.outline => Border.all(color: DesignColors.primary, width: DS.s(1.5)),
      StayPillKind.danger => Border.all(color: StayLook.dangerLine, width: DS.s(1.5)),
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
                color: gradient == null ? (kind == StayPillKind.off ? StayLook.rowLine : Colors.white) : null,
                borderRadius: DS.circular(20),
                border: border,
                boxShadow: kind == StayPillKind.white || filled ? DS.shadows(Ink3D.whiteBtn) : null,
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

class StayRowData {
  const StayRowData({required this.art, required this.title, this.sub, this.trailing, this.onTap, this.tint = StayLook.artTint, this.locked = false, this.semantics, this.titleColor});

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

class StayRowsCard extends StatelessWidget {
  const StayRowsCard({super.key, required this.rows, this.margin});

  final List<StayRowData> rows;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: margin ?? DS.insets(l: 18, t: 14, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: DS.br(CardRadius.tile), boxShadow: DS.shadows(Ink3D.softShadow)),
        child: ClipRRect(
          borderRadius: DS.br(CardRadius.tile),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: StayLook.rowLine),
                StayRowTile(data: rows[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StayRowTile extends StatelessWidget {
  const StayRowTile({super.key, required this.data});

  final StayRowData data;

  @override
  Widget build(BuildContext context) {
    final tile = ColoredBox(
      color: data.locked ? StayLook.lockedRow : Colors.transparent,
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

class StaySectionTitle extends StatelessWidget {
  const StaySectionTitle({super.key, required this.title, this.meter, this.trailing});

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

class StayStrip extends StatelessWidget {
  const StayStrip({super.key, required this.art, required this.text, required this.fill, required this.ink, this.action, this.onAction, this.margin, this.actionKind = StayPillKind.white});

  final StayPillKind actionKind;
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
                  if (action != null) ...[Gap.h(8), StayPill(label: action!, kind: actionKind, onTap: onAction)],
                ],
              ),
            ),
          ),
        ),
      );
}

class StayInstagramCard extends StatelessWidget {
  const StayInstagramCard({super.key, required this.eyebrow, required this.title, required this.cta, required this.onTap});

  final String eyebrow;
  final String title;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Padding(
      padding: DS.insets(l: 18, t: 30, r: 18),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: StayLook.cardRadius(68), gradient: tone.gradient, boxShadow: tone.glow()),
          child: Padding(
            padding: DS.insets(l: 22, t: 20, r: 22, b: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: Ink3D.text(13, FontWeight.w500, Colors.white.withValues(alpha: Alpha.high), letterSpacing: 0)),
                Text(title, style: Ink3D.text(22, FontWeight.w700, Colors.white, height: 1.15, letterSpacing: 0)),
                Gap.v(10),
                StayWhitePill(label: cta, color: StayLook.indigoText, onTap: onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StayRail extends StatelessWidget {
  const StayRail({super.key, required this.tiles});

  final List<StayRailTile> tiles;

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

class StayRailTile {
  const StayRailTile({required this.tone, required this.art, required this.title, required this.sub, required this.onTap, this.add = false});

  final ListingTone tone;
  final String art;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool add;
}

class StayErrorCard extends StatelessWidget {
  const StayErrorCard({super.key, required this.art, required this.title, this.message, this.action, this.onAction, this.margin});

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
          decoration: BoxDecoration(color: Colors.white, borderRadius: StayLook.cardRadius(68), boxShadow: DS.shadows(Ink3D.softShadow)),
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
                  GradientPillButton(tone: ListingTone.forest, label: action!, onTap: onAction),
                ],
              ],
            ),
          ),
        ),
      );
}

class StayLockedAddRow extends StatelessWidget {
  const StayLockedAddRow({super.key, required this.label, required this.onTap, this.margin});

  final String label;
  final VoidCallback onTap;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return const SizedBox.shrink();
    return Padding(
      padding: margin ?? DS.insets(l: 18, t: 20, r: 18),
      child: Semantics(
        button: true,
        label: '$label, needs Plus',
        excludeSemantics: true,
        child: InkWell(
          key: GateKeys.softRow,
          onTap: onTap,
          borderRadius: DS.circular(26),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(48)),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(26), border: Border.all(color: DesignColors.primary, width: DS.s(1.5))),
              child: Center(
                child: Padding(
                  padding: DS.sym(h: 16, v: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Art3D(asset: ListingArt.locked, size: 22),
                      Gap.h(8),
                      Flexible(child: Text(label, style: Ink3D.text(14, FontWeight.w700, StayLook.indigoText, letterSpacing: 0))),
                      Gap.h(8),
                      const PlusChip(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StayPlusBanner extends StatelessWidget {
  const StayPlusBanner({super.key, required this.text, required this.onTap, this.margin});

  final String text;
  final VoidCallback onTap;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return const SizedBox.shrink();
    return KeyedSubtree(
      key: GateKeys.softCard,
      child: StayStrip(
        art: ListingArt.locked,
        text: text,
        fill: StayLook.indigoSoft,
        ink: StayLook.indigoText,
        action: OwnerSharedStrings.seePlus,
        actionKind: StayPillKind.indigo,
        onAction: onTap,
        margin: margin ?? DS.insets(l: 18, t: 12, r: 18),
      ),
    );
  }
}

class StayDeleteRow extends StatelessWidget {
  const StayDeleteRow({super.key, required this.title, required this.sub, required this.busy, required this.onDelete});

  final String title;
  final String sub;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => StayRowsCard(rows: [
        StayRowData(
          art: ListingArt.warning,
          tint: StayLook.artTintRed,
          title: title,
          titleColor: StayLook.redText,
          sub: sub,
          trailing: StayPill(label: OwnerSharedStrings.delete, kind: StayPillKind.danger, busy: busy, onTap: onDelete),
          onTap: busy ? null : onDelete,
        ),
      ]);
}
