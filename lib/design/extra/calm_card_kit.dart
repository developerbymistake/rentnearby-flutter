import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/design_scale.dart';
import '../tokens/listing_palette.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'art_3d.dart';
import 'motion_kit.dart';
import 'whatsapp_glyph.dart';

enum CalmChipKind { tag, fact, solid, muted }

abstract final class CalmText {
  static Color get secondary => DesignColors.textPrimary.withValues(alpha: Alpha.high);
  static Color get struck => DesignColors.textPrimary.withValues(alpha: Alpha.strong);
}

abstract final class CalmCard {
  static BoxDecoration box(ListingPalette p, {BorderRadius? radius}) => BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DesignColors.surface, p.tint]),
        borderRadius: radius ?? DS.circular(16),
        boxShadow: DS.shadows(ShadowTokens.tight(p.shadow)),
      );

  static ListingPalette stayAt(int index) => index.isEven ? ListingPalette.forest : ListingPalette.indigo;
}

class CalmChip extends StatelessWidget {
  const CalmChip(
    this.label, {
    super.key,
    required this.palette,
    this.kind = CalmChipKind.fact,
    this.fg,
    this.leading,
    this.textSize = 10,
    this.padding,
  });

  final String label;
  final ListingPalette palette;
  final CalmChipKind kind;
  final Color? fg;
  final Widget? leading;
  final double textSize;
  final EdgeInsets? padding;

  Color get background => switch (kind) {
        CalmChipKind.tag || CalmChipKind.fact => DesignColors.tint(palette.g2, Alpha.tint),
        CalmChipKind.solid => palette.g2,
        CalmChipKind.muted => DesignColors.chipBackground,
      };

  Color get foreground => switch (kind) {
        CalmChipKind.tag => fg ?? palette.g2,
        CalmChipKind.fact => fg ?? palette.text,
        CalmChipKind.solid => DesignColors.onPrimary,
        CalmChipKind.muted => DesignColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final spaced = kind == CalmChipKind.tag || kind == CalmChipKind.solid;
    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TypeTokens.style(textSize, FontWeight.w700, color: foreground, chip: true, letterSpacing: spaced ? 0.4 : null),
    );
    return Container(
      padding: padding ?? DS.sym(h: spaced ? 8 : 6, v: 3),
      decoration: BoxDecoration(color: background, borderRadius: DS.br(CardRadius.chip)),
      child: leading == null
          ? text
          : Row(mainAxisSize: MainAxisSize.min, children: [leading!, Gap.h(4), Flexible(child: text)]),
    );
  }
}

class CalmPriceBlock extends StatelessWidget {
  const CalmPriceBlock({
    super.key,
    required this.palette,
    required this.value,
    this.caption,
    this.unit = '',
    this.was,
    this.offTag,
    this.valueColor,
    this.minWidth = 84,
    this.unitAlign = TextAlign.right,
    this.oneLine = false,
  });

  final ListingPalette palette;
  final String value;
  final String? caption;
  final String unit;
  final String? was;
  final String? offTag;
  final Color? valueColor;
  final double minWidth;
  final TextAlign unitAlign;
  final bool oneLine;

  static final RegExp _digit = RegExp(r'\d');

  static bool isNumeric(String v) => _digit.hasMatch(v);

  Widget _oneLine(Color color, TextStyle small) {
    final numeric = isNumeric(value);
    final big = TypeTokens.style(18, FontWeight.w800, color: color, height: 1.15);
    final Widget shown = !numeric
        ? Flexible(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.style(12, FontWeight.w700, color: color, height: 1.2)))
        : unit.isEmpty
            ? Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, maxLines: 1, softWrap: false, style: big),
                ),
              )
            : Text(value, maxLines: 1, softWrap: false, style: big);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.line))),
      padding: EdgeInsets.only(top: DS.s(6)),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: DS.s(minWidth)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              shown,
              if (unit.isNotEmpty) ...[
                Gap.h(6),
                Flexible(child: Text(unit, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: small)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? palette.g2;
    final small = TypeTokens.style(11, FontWeight.w500, color: CalmText.secondary);
    if (oneLine) return _oneLine(color, small);
    final cap = caption;
    final struck = was;
    final tag = offTag;
    final numeric = isNumeric(value);
    return Container(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: palette.line))),
      padding: EdgeInsets.only(left: DS.s(12)),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: DS.s(minWidth)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cap != null && cap.isNotEmpty) Text(cap, maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
              if (numeric)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, maxLines: 1, softWrap: false, style: TypeTokens.style(18, FontWeight.w800, color: color, height: 1.15)),
                )
              else
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.style(12, FontWeight.w700, color: color, height: 1.2)),
              if (struck != null && struck.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        struck,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(11, FontWeight.w500, color: CalmText.struck).copyWith(decoration: TextDecoration.lineThrough),
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      Gap.h(5),
                      Text(unit, maxLines: 1, softWrap: false, style: small),
                    ],
                  ],
                )
              else if (unit.isNotEmpty)
                Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: unitAlign, style: small),
              if (tag != null && tag.isNotEmpty) ...[
                Gap.v(5),
                Align(alignment: Alignment.centerLeft, child: CalmChip(tag, palette: palette, kind: CalmChipKind.solid)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum CalmActionKind { call, whatsApp, primary, plain, disabled }

class CalmAction {
  const CalmAction({
    required this.kind,
    required this.label,
    this.onTap,
    this.busy = false,
    this.selected = false,
    this.icon,
    this.itemKey,
    this.child,
  });

  final CalmActionKind kind;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final bool selected;
  final IconData? icon;
  final Key? itemKey;
  final Widget? child;

  bool get enabled => kind != CalmActionKind.disabled && !busy && onTap != null;
}

class CalmPillButton extends StatelessWidget {
  const CalmPillButton({super.key, required this.action, required this.palette, this.callShadow = false});

  final CalmAction action;
  final ListingPalette palette;
  final bool callShadow;

  static const double height = 32;
  static const double minTouch = 44;

  static double hitPad() => math.max(0.0, (minTouch - DS.s(height)) / 2);

  bool get _filled =>
      action.kind == CalmActionKind.whatsApp || (action.kind == CalmActionKind.primary && action.selected);

  Color get _fg {
    if (action.kind == CalmActionKind.disabled) return DesignColors.textDisabled;
    return _filled ? DesignColors.onPrimary : palette.text;
  }

  Widget _spinner(double size, Color color) => SizedBox.square(
        dimension: DS.s(size),
        child: CircularProgressIndicator(strokeWidth: DS.s(2), color: color),
      );

  Widget? _leading() {
    final fg = _fg;
    switch (action.kind) {
      case CalmActionKind.call:
        return Container(
          width: DS.s(22),
          height: DS.s(22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.surface,
            boxShadow: callShadow
                ? DS.shadows([BoxShadow(color: Colors.black.withValues(alpha: Alpha.soft), offset: const Offset(0, 2), blurRadius: 4)])
                : null,
          ),
          child: action.busy ? _spinner(13, Ink3D.title) : Icon(Icons.call_rounded, size: DS.s(13), color: Ink3D.title),
        );
      case CalmActionKind.whatsApp:
        return action.busy ? _spinner(16, fg) : WhatsAppGlyph(size: 16, color: DesignColors.onPrimary, onColor: palette.g2);
      case CalmActionKind.primary:
        final icon = action.icon ?? (action.selected ? Icons.check_rounded : Icons.add_rounded);
        return action.busy ? _spinner(13, fg) : Icon(icon, size: DS.s(13), color: fg);
      case CalmActionKind.plain:
        if (action.busy) return _spinner(13, fg);
        return action.icon == null ? null : Icon(action.icon, size: DS.s(13), color: fg);
      case CalmActionKind.disabled:
        return null;
    }
  }

  EdgeInsets get _padding => switch (action.kind) {
        CalmActionKind.call => EdgeInsets.only(left: DS.s(5), right: DS.s(9)),
        CalmActionKind.whatsApp => DS.sym(h: 11),
        _ => DS.sym(h: 12),
      };

  double get _gap => action.kind == CalmActionKind.whatsApp ? 6 : 4;

  @override
  Widget build(BuildContext context) {
    final fg = _fg;
    final lead = _leading();
    final extra = action.child;
    final pill = Container(
      height: DS.s(height),
      padding: _padding,
      decoration: BoxDecoration(
        color: _filled ? null : (action.kind == CalmActionKind.disabled ? DesignColors.chipBackground : palette.button),
        gradient: _filled ? palette.gradient : null,
        borderRadius: DS.circular(18),
        boxShadow: _filled ? DS.shadows(ShadowTokens.tight(palette.shadow)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lead != null) ...[lead, Gap.h(_gap)],
          Text(action.label, maxLines: 1, softWrap: false, style: TypeTokens.style(11.5, FontWeight.w700, color: fg)),
          if (extra != null) ...[Gap.h(4), extra],
        ],
      ),
    );
    final enabled = action.enabled;
    return Semantics(
      key: action.itemKey,
      button: true,
      enabled: enabled,
      selected: action.selected,
      child: PressScale(
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? action.onTap : null,
          child: Padding(padding: EdgeInsets.symmetric(vertical: hitPad()), child: pill),
        ),
      ),
    );
  }
}

class CalmBottomRow extends StatelessWidget {
  const CalmBottomRow({
    super.key,
    required this.palette,
    this.address,
    this.note,
    required this.actions,
    this.padding,
    this.callShadow = false,
  });

  final ListingPalette palette;
  final String? address;
  final String? note;
  final List<CalmAction> actions;
  final EdgeInsets? padding;
  final bool callShadow;

  @override
  Widget build(BuildContext context) {
    final a = address;
    final n = note;
    final hasAddress = a != null && a.trim().isNotEmpty;
    if (actions.isEmpty && !hasAddress) return const SizedBox.shrink();
    final base = padding ?? DS.insets(l: 12, t: 8, r: 12, b: 10);
    final pad = actions.isEmpty ? 0.0 : CalmPillButton.hitPad();
    final style = TypeTokens.style(10, FontWeight.w500, color: CalmText.secondary);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.line))),
      padding: EdgeInsets.fromLTRB(base.left, math.max(0.0, base.top - pad), base.right, math.max(0.0, base.bottom - pad)),
      child: LayoutBuilder(builder: (context, box) => _row(context, a, n, hasAddress, style, box.maxWidth)),
    );
  }

  double _buttonsMax(BuildContext context, String? a, bool hasAddress, TextStyle style, double width) {
    if (!width.isFinite) return double.infinity;
    final cap = width * maxButtonsShare;
    if (!hasAddress) return cap;
    final painter = TextPainter(
      text: TextSpan(text: a!.trim(), style: DefaultTextStyle.of(context).style.merge(style)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final reserve = painter.width + DS.s(16) + DS.gh(6) + DS.gh(5);
    painter.dispose();
    return math.max(width * minButtonsShare, math.min(cap, width - reserve));
  }

  Widget _row(BuildContext context, String? a, String? n, bool hasAddress, TextStyle style, double width) {
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions) ...[
          Gap.h(5),
          CalmPillButton(action: action, palette: palette, callShadow: callShadow),
        ],
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasAddress) ...[
          const Art3D(asset: ListingArt.roundPushpin, size: 16, shadowBlur: 2, shadowOffset: Offset(1, 2), shadowAlpha: 0.3),
          Gap.h(6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a!.trim(), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style),
                if (n != null && n.trim().isNotEmpty)
                  Text(n.trim(), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style.copyWith(color: CalmText.struck)),
              ],
            ),
          ),
        ] else
          const Spacer(),
        if (actions.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _buttonsMax(context, a, hasAddress, style, width)),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: buttons),
          ),
      ],
    );
  }

  static const double maxButtonsShare = 0.72;
  static const double minButtonsShare = 0.38;
}
