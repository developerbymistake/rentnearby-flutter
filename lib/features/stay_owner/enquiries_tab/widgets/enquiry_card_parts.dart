import 'package:flutter/material.dart';

import '../../../../design/design.dart';

enum EnquiryChipTone { green, amber, indigo, red, grey }

extension EnquiryChipToneColor on EnquiryChipTone {
  Color get color => switch (this) {
        EnquiryChipTone.green => StatusTone3D.both.pillText,
        EnquiryChipTone.amber => StatusTone3D.waiting.pillText,
        EnquiryChipTone.indigo => StatusTone3D.you.pillText,
        EnquiryChipTone.red => StatusTone3D.red.pillText,
        EnquiryChipTone.grey => StatusTone3D.closed.pillText,
      };
}

class EnquiryChip {
  const EnquiryChip(this.label, this.tone);
  final String label;
  final EnquiryChipTone tone;
}

enum EnquiryButtonKind { primary, plain, danger, dangerFilled }

class EnquiryButton {
  const EnquiryButton(this.label, this.kind, this.onTap);
  final String label;
  final EnquiryButtonKind kind;
  final VoidCallback? onTap;
}

const double _btnFont = 12.5;
const double _wideFont = 14;

class EnquiryKv {
  const EnquiryKv(this.label, this.value, {this.old, this.valueColor, this.pill, this.onTap});
  final VoidCallback? onTap;
  final String label;
  final String value;
  final String? old;
  final Color? valueColor;
  final EnquiryChipTone? pill;
}

class EnquiryCardFrame extends StatelessWidget {
  const EnquiryCardFrame({super.key, required this.children, this.semantics});

  final List<Widget> children;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semantics,
      child: Container(
        margin: DS.gapInsets(l: 14, t: 12, r: 14),
        padding: DS.insets(l: 14, t: 16, r: 14, b: 14),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(CardRadius.tile),
          boxShadow: DS.shadows(Ink3D.softShadow),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class EnquiryHead extends StatelessWidget {
  const EnquiryHead({super.key, required this.name, required this.lines, this.chip, this.onMenu, this.menuKey, this.menuLabel});

  final String name;
  final List<String> lines;
  final EnquiryChip? chip;
  final VoidCallback? onMenu;
  final GlobalKey? menuKey;
  final String? menuLabel;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final chip = this.chip;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Container(
            width: DS.s(40),
            height: DS.s(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: ListingTone.forest.gradient, boxShadow: ListingTone.forest.glow(blur: 6, dy: 3)),
            child: Text(initial, style: Ink3D.text(14, FontWeight.w700, DesignColors.onPrimary)),
          ),
        ),
        Gap.h(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              for (final l in lines)
                if (l.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: DS.gv(2)),
                    child: Text(l, style: Ink3D.text(11, FontWeight.w400, Ink3D.grey, height: 1.3, letterSpacing: 0)),
                  ),
            ],
          ),
        ),
        if (chip != null) ...[
          Gap.h(8),
          StatusPill3D(label: chip.label, color: chip.tone.color, onGradient: false),
        ],
        if (onMenu != null)
          Semantics(
            button: true,
            label: menuLabel,
            child: InkWell(
              key: menuKey,
              onTap: onMenu,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: DS.s(40),
                height: DS.s(48),
                child: Icon(Icons.more_vert_rounded, size: DS.s(22), color: Ink3D.grey),
              ),
            ),
          ),
      ],
    );
  }
}

class EnquiryHeadParts extends StatelessWidget {
  const EnquiryHeadParts({super.key, required this.eyebrow, required this.left, required this.leftShort, required this.title, required this.priceLine});

  final String eyebrow;
  final String? left;
  final bool leftShort;
  final String title;
  final String? priceLine;

  @override
  Widget build(BuildContext context) {
    final left = this.left;
    final price = priceLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(eyebrow, style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.6))),
            if (left != null) StatusPill3D(label: left, color: (leftShort ? EnquiryChipTone.red : EnquiryChipTone.grey).color, onGradient: false),
          ],
        ),
        Gap.v(6),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
        if (price != null)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(2)),
            child: Text(price, style: Ink3D.text(11, FontWeight.w400, Ink3D.grey, height: 1.3, letterSpacing: 0)),
          ),
      ],
    );
  }
}

class EnquiryRows extends StatelessWidget {
  const EnquiryRows({super.key, required this.rows});

  final List<EnquiryKv> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(10)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) _row(rows[i], i > 0),
        ],
      ),
    );
  }

  Widget _row(EnquiryKv r, bool divider) {
    final label = Text(r.label, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0));
    final strong = Ink3D.text(12.5, FontWeight.w700, r.valueColor ?? Ink3D.title, letterSpacing: 0);
    final pill = r.pill;
    final Widget value = pill != null
        ? StatusPill3D(label: r.value, color: pill.color, onGradient: false)
        : Text.rich(
            TextSpan(children: [
              if (r.old != null) ...[
                TextSpan(
                  text: r.old,
                  style: Ink3D.text(12.5, FontWeight.w400, Ink3D.hint, letterSpacing: 0).copyWith(decoration: TextDecoration.lineThrough),
                ),
                const TextSpan(text: '  '),
              ],
              TextSpan(text: r.value, style: strong),
            ]),
            textAlign: TextAlign.end,
          );
    final row = Container(
      decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: Ink3D.line))) : null,
      constraints: r.onTap == null ? null : BoxConstraints(minHeight: DS.s(48)),
      padding: DS.sym(v: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          label,
          Gap.h(12),
          Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
    if (r.onTap == null) return row;
    return Semantics(
      button: true,
      label: '${r.label} ${r.value}',
      excludeSemantics: true,
      child: InkWell(onTap: r.onTap, child: row),
    );
  }
}

class EnquiryInlinePill extends StatelessWidget {
  const EnquiryInlinePill({super.key, required this.label, required this.value, required this.tone, this.semantics});

  final String label;
  final String value;
  final EnquiryChipTone tone;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: semantics != null,
      child: Padding(
        padding: EdgeInsets.only(top: DS.gv(10)),
        child: Row(
          children: [
            Flexible(child: Text(label, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0))),
            Gap.h(8),
            StatusPill3D(label: value, color: tone.color, onGradient: false),
          ],
        ),
      ),
    );
  }
}

class EnquiryNote extends StatelessWidget {
  const EnquiryNote({super.key, required this.text, this.art, this.tone = EnquiryChipTone.green, this.action, this.onAction, this.sub});

  final String text;
  final String? sub;
  final String? art;
  final EnquiryChipTone tone;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = tone.color;
    final action = this.action;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: EdgeInsets.only(top: DS.gv(10)),
        padding: DS.sym(h: 12, v: 10),
        decoration: BoxDecoration(color: c.withValues(alpha: Alpha.faint), borderRadius: DS.circular(12)),
        child: Row(
          children: [
            if (art != null) ...[
              Art3D(asset: art!, size: 20),
              Gap.h(10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: Ink3D.text(12, FontWeight.w600, c, height: 1.35, letterSpacing: 0)),
                  if (sub != null)
                    Padding(
                      padding: EdgeInsets.only(top: DS.gv(2)),
                      child: Text(sub!, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.35, letterSpacing: 0)),
                    ),
                ],
              ),
            ),
            if (action != null) ...[
              Gap.h(8),
              Semantics(
                button: true,
                label: action,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onAction,
                  borderRadius: DS.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: DS.s(40), minWidth: DS.s(48)),
                    child: Center(widthFactor: 1, child: Padding(padding: DS.sym(h: 8), child: Text(action, style: Ink3D.text(12.5, FontWeight.w700, c)))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EnquiryButtons extends StatelessWidget {
  const EnquiryButtons({super.key, required this.buttons, this.busy = false});

  final List<EnquiryButton> buttons;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(12)),
      child: LayoutBuilder(builder: (context, c) {
        final perRow = buttons.length == 3 && c.maxWidth < DS.s(300) ? 2 : buttons.length;
        final rows = <List<EnquiryButton>>[];
        for (var i = 0; i < buttons.length; i += perRow) {
          rows.add(buttons.sublist(i, (i + perRow).clamp(0, buttons.length)));
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) Gap.v(8),
              Row(
                children: [
                  for (var i = 0; i < rows[r].length; i++) ...[
                    if (i > 0) Gap.h(8),
                    Expanded(child: _button(rows[r][i])),
                  ],
                ],
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _button(EnquiryButton b) {
    final onTap = busy ? null : b.onTap;
    return switch (b.kind) {
      EnquiryButtonKind.primary =>
        GradientPillButton(tone: ListingTone.forest, label: b.label, height: 42, fontSize: _btnFont, loading: busy, onTap: onTap, enabled: onTap != null),
      EnquiryButtonKind.dangerFilled =>
        GradientPillButton(tone: ListingTone.forest, label: b.label, height: 46, fontSize: _wideFont, danger: true, loading: busy, onTap: onTap, enabled: onTap != null),
      EnquiryButtonKind.plain => WhitePillButton(tone: ListingTone.indigo, label: b.label, height: 42, fontSize: _btnFont, onTap: onTap, enabled: onTap != null),
      EnquiryButtonKind.danger => WhitePillButton(tone: ListingTone.indigo, label: b.label, height: 42, fontSize: _btnFont, danger: true, onTap: onTap, enabled: onTap != null),
    };
  }
}

class BucketPill extends StatelessWidget {
  const BucketPill({super.key, this.art, required this.label, this.count, required this.selected, required this.onTap, this.semantics});

  final String? art;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.forest;
    return Semantics(
      button: true,
      selected: selected,
      label: semantics ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(40)),
          padding: DS.sym(h: 8, v: 6),
          decoration: BoxDecoration(
            gradient: selected ? tone.gradient : null,
            color: selected ? null : DesignColors.surface,
            borderRadius: DS.br(CardRadius.tile),
            boxShadow: selected ? tone.glow(blur: 8, dy: 4) : DS.shadows(Ink3D.softShadow),
          ),
          child: count != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$count', maxLines: 1, style: Ink3D.text(20, FontWeight.w700, selected ? DesignColors.onPrimary : Ink3D.title, letterSpacing: 0)),
                    Text(label, maxLines: 1, style: Ink3D.text(11.5, FontWeight.w500, selected ? DesignColors.onPrimary : Ink3D.grey, letterSpacing: 0)),
                  ],
                )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (art case final art?) ...[
                ExcludeSemantics(child: Art3D(asset: art, size: 22)),
                Gap.h(8),
              ],
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, selected ? DesignColors.onPrimary : Ink3D.body, letterSpacing: 0)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
