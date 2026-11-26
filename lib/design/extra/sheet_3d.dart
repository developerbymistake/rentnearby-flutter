import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/design_colors.dart';
import 'art_3d.dart';
import 'dock_inset.dart';
import 'pill_buttons_3d.dart';
import 'sheet_close_button.dart';
import '../tokens/design_scale.dart';
import '../tokens/card_tokens.dart';

enum SheetSize { hug, short, confirm, list, form }

class Sheet3D extends StatelessWidget {
  const Sheet3D({
    super.key,
    required this.tone,
    required this.child,
    this.art,
    this.title,
    this.subtitle,
    this.centerTitle = true,
    this.onBack,
    this.headerAction,
    this.onHeaderAction,
    this.size = SheetSize.hug,
    this.footer,
    this.footnote,
    this.scrollable = true,
    this.padding,
    this.fitTitle = false,
    this.artRight = false,
    this.showClose = true,
    this.closeEnabled = true,
  });

  final ListingTone tone;
  final Widget child;
  final String? art;
  final String? title;
  final String? subtitle;
  final bool centerTitle;
  final VoidCallback? onBack;
  final String? headerAction;
  final VoidCallback? onHeaderAction;
  final SheetSize size;
  final Widget? footer;
  final String? footnote;
  final bool scrollable;
  final EdgeInsets? padding;
  final bool fitTitle;
  final bool artRight;
  final bool showClose;
  final bool closeEnabled;

  static double get artRoom => DS.s(70);
  static double get closeRoom => DS.s(44);
  static double get artRightInset => DS.s(70);
  static BorderRadius get radius => DS.br(const BorderRadius.vertical(top: Radius.circular(32)));

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: false,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: DesignColors.scrim,
    elevation: 0,
    clipBehavior: Clip.none,
    constraints: BoxConstraints(maxWidth: 560),
    builder: (c) => DockLift(child: builder(c)),
  );

  static bool keyboardOpen(BuildContext context) => SheetInsets.lift(context) > SheetInsets.dock(context);

  // Room above the dock or keyboard for the whole sheet, art included.
  static double roomFor(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.viewPadding.top - DS.s(60) - SheetInsets.lift(context);
  }

  static double get minBody => DS.s(140);

  // FX-07: when the body would get less than [minBody], the sheet drops art and subtitle and scrolls its footer with the body.
  bool compactFor(BuildContext context) {
    if (art == null && subtitle == null && footer == null) return false;
    final header = (title != null || onBack != null || headerAction != null ? DS.s(56) : 0) + (subtitle != null ? DS.s(26) : 0);
    final top = art != null ? artRoom + DS.s(centerTitle ? 80 : 70) : DS.s(26);
    final bottom = footer != null ? DS.s(90) : DS.s(18);
    return roomFor(context) - top - header - bottom < minBody;
  }

  // Height of the white panel; the art room above it is taken out of the same cap.
  static double heightFor(SheetSize size, BuildContext context, {bool withArt = false}) {
    final mq = MediaQuery.of(context);
    final room = roomFor(context) - (withArt ? artRoom : 0);
    final cap = keyboardOpen(context) ? math.max(0.0, room) : math.max(DS.s(240), room);
    final base = switch (size) {
      SheetSize.hug => cap,
      SheetSize.short => DS.s(350),
      SheetSize.confirm => DS.s(566),
      SheetSize.list => DS.s(650),
      SheetSize.form => DS.s(742),
    };
    return math.min(size == SheetSize.hug ? base : base + mq.viewPadding.bottom, cap);
  }

  Widget _header(BuildContext context, {bool compact = false}) {
    final subtitle = compact ? null : this.subtitle;
    final art = compact ? null : this.art;
    final sideRoom = showClose && art == null ? closeRoom : 0.0;
    if (centerTitle) {
      return Padding(
        padding: EdgeInsets.fromLTRB(DS.s(22) + sideRoom, 0, DS.s(22) + sideRoom, DS.s(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Semantics(
                header: true,
                child: fitTitle
                    ? FittedBox(fit: BoxFit.scaleDown, child: Text(title!, textAlign: TextAlign.center, maxLines: 1, softWrap: false, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.25, letterSpacing: 0)))
                    : Text(title!, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.25)),
              ),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(top: DS.s(6)),
                child: Text(subtitle, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy, height: 1.45)),
              ),
          ],
        ),
      );
    }
    final action = headerAction;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), 0, DS.s(18) + (showClose && !(artRight && art != null) ? closeRoom : 0), DS.s(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            Tooltip(
              message: 'Back',
              child: Tap3D(
                onTap: onBack,
                label: 'Back',
                child: Container(
                  width: DS.s(40),
                  height: DS.s(40),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x669E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(10))]),
                  child: Icon(Icons.chevron_left_rounded, size: DS.s(26), color: tone.text),
                ),
              ),
            ),
            SizedBox(width: DS.s(12)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(minHeight: DS.s(40)),
                  padding: EdgeInsets.only(right: artRight && art != null ? DS.s(128) + artRightInset - DS.s(18) : 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      header: true,
                      child: Text(title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.2)),
                    ),
                  ),
                ),
                if (subtitle != null) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub)),
              ],
            ),
          ),
          if (action != null) ...[
            SizedBox(width: DS.s(12)),
            Padding(
              padding: EdgeInsets.only(top: DS.s(4)),
              child: Tap3D(
                onTap: onHeaderAction,
                child: Container(
                  constraints: BoxConstraints(minHeight: DS.s(32)),
                  padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(6)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: tone.gradient,
                    borderRadius: DS.circular(18),
                    boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(1.1, 3)), blurRadius: DS.shadowBlur(8))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(action, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, Colors.white)),
                      Icon(Icons.chevron_right_rounded, size: DS.s(16), color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DockLift(child: Builder(builder: _panel));

  Widget _panel(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = compactFor(context);
    final a = compact ? null : art;
    final hug = size == SheetSize.hug;
    final h = heightFor(size, context, withArt: a != null);
    final hasHeader = title != null || subtitle != null || onBack != null || headerAction != null;
    final pad = padding ?? DS.insets(l: 22, r: 22);
    final scrollFooter = compact && scrollable && footer != null;
    final footerBox = footer == null
        ? null
        : Padding(padding: EdgeInsets.fromLTRB(DS.s(22), DS.s(12), DS.s(22), footnote == null ? DS.s(26) + mq.viewPadding.bottom : 0), child: footer);
    final body = scrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: scrollFooter ? null : pad,
            child: scrollFooter
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [Padding(padding: pad, child: child), footerBox!])
                : child,
          )
        : Padding(padding: pad, child: child);
    final note = footnote;
    final panel = Container(
      width: double.infinity,
      height: hug ? null : h,
      constraints: hug ? BoxConstraints(maxHeight: h) : null,
      padding: EdgeInsets.only(top: DS.s(artRight && a != null ? 34 : a != null ? (centerTitle ? 80 : 70) : 26)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [BoxShadow(color: Color(0x33000000), offset: DS.shadowOffset(const Offset(0, -4)), blurRadius: DS.shadowBlur(24))],
      ),
      child: Column(
        mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) _header(context, compact: compact),
          if (hug) Flexible(child: body) else Expanded(child: body),
          if (footerBox != null && !scrollFooter) footerBox,
          if (note != null)
            Container(
              constraints: BoxConstraints(minHeight: DS.s(size == SheetSize.confirm ? 52 : 40) + mq.viewPadding.bottom),
              padding: EdgeInsets.fromLTRB(DS.s(28), DS.s(10), DS.s(28), DS.s(8) + mq.viewPadding.bottom),
              alignment: Alignment.topCenter,
              child: Text(note, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.35)),
            ),
          if (footer == null && note == null) SizedBox(height: DS.s(18) + mq.viewPadding.bottom),
        ],
      ),
    );
    return Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a != null) SizedBox(height: artRoom),
            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  panel,
                  if (artRight)
                    Positioned(
                      top: DS.s(10),
                      child: IgnorePointer(child: Container(width: DS.s(40), height: DS.s(4), decoration: BoxDecoration(color: Ink3D.line, borderRadius: DS.circular(2)))),
                    ),
                  if (a != null)
                    Positioned(
                      top: DS.s(-66),
                      right: artRight ? artRightInset : null,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: Art3D(asset: a, size: 128, halo: 136, haloColor: tone.haloBase.withValues(alpha: 0.18), shadowBlur: 7, shadowOffset: const Offset(5, 9), shadowAlpha: 0.3),
                        ),
                      ),
                    ),
                  if (showClose)
                    Positioned(top: DS.s(12), right: DS.s(12), child: SheetCloseButton(enabled: closeEnabled)),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class SheetSearchField extends StatelessWidget {
  const SheetSearchField({
    super.key,
    required this.tone,
    required this.controller,
    this.hint,
    this.leadingArt,
    this.trailingArt,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textInputAction = TextInputAction.search,
    this.margin,
    this.flat = false,
  });

  final ListingTone tone;
  final TextEditingController controller;
  final String? hint;
  final String? leadingArt;
  final String? trailingArt;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final EdgeInsets? margin;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? DS.gapInsets(l: 18, t: 14, r: 18, b: 8),
      constraints: BoxConstraints(minHeight: DS.s(56)),
      padding: trailingArt != null ? EdgeInsets.fromLTRB(DS.s(20), DS.s(6), DS.s(6), DS.s(6)) : EdgeInsets.fromLTRB(DS.s(12), DS.s(7), DS.s(18), DS.s(7)),
      decoration: BoxDecoration(
        color: flat ? Form3D.fill : Colors.white,
        borderRadius: DS.circular(38),
        boxShadow: flat ? null : [BoxShadow(color: Color(0x599E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(12))],
      ),
      child: Row(
        children: [
          if (leadingArt != null) ...[
            ExcludeSemantics(child: Art3D(asset: leadingArt!, size: 36, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25)),
            SizedBox(width: DS.s(10)),
          ] else if (trailingArt == null)
            SizedBox(width: DS.s(8)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              inputFormatters: inputFormatters,
              textInputAction: textInputAction,
              cursorColor: tone.g2,
              style: Ink3D.text(15, FontWeight.w500, Ink3D.body),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: Ink3D.text(15, FontWeight.w400, const Color(0xFF9FA3AB)),
              ),
            ),
          ),
          if (trailingArt != null) ...[
            SizedBox(width: DS.s(10)),
            ExcludeSemantics(
              child: Container(
                width: DS.s(44),
                height: DS.s(44),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: tone.gradient,
                  boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(3, 6)), blurRadius: DS.shadowBlur(10))],
                ),
                child: Art3D(asset: trailingArt!, size: 30, shadowBlur: 2, shadowOffset: const Offset(1, 2), shadowAlpha: 0.2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SheetListRow extends StatelessWidget {
  const SheetListRow({
    super.key,
    required this.tone,
    required this.title,
    this.art,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.trailing,
    this.divider = true,
    this.compact = false,
    this.roundArt = false,
  });

  final bool compact;
  final bool roundArt;
  final ListingTone tone;
  final String title;
  final String? art;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: DS.s(compact ? 48 : 76)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(20), vertical: DS.s(compact ? 8 : 12)),
      decoration: BoxDecoration(border: divider && !roundArt ? const Border(top: BorderSide(color: Ink3D.line)) : null),
      child: Row(
        children: [
          if (art != null) ...[
            SizedBox(
              width: DS.s(52),
              height: DS.s(52),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: roundArt && selected ? tone.g1 : tone.haloBase.withValues(alpha: 0.14),
                        shape: roundArt ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: roundArt ? null : DS.circular(16),
                      ),
                    ),
                  ),
                  Positioned(left: DS.s(-4), top: DS.s(-10), child: Art3D(asset: art!, size: 60, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
                ],
              ),
            ),
            SizedBox(width: DS.s(14)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, selected ? FontWeight.w700 : FontWeight.w500, Ink3D.body)),
                if (subtitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(2)),
                    child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey)),
                  ),
              ],
            ),
          ),
          SizedBox(width: DS.s(10)),
          trailing ??
              Container(
                width: DS.s(28),
                height: DS.s(28),
                decoration: selected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: tone.gradient,
                        boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(1.1, 3)), blurRadius: DS.shadowBlur(6))],
                      )
                    : null,
                child: selected ? Icon(Icons.check_rounded, size: DS.s(17), color: Colors.white) : null,
              ),
        ],
      ),
    );
    final live = enabled && onTap != null;
    return Tap3D(
      onTap: live ? onTap : null,
      selected: selected,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: roundArt && divider ? Column(mainAxisSize: MainAxisSize.min, children: [Padding(padding: EdgeInsets.symmetric(horizontal: DS.s(20)), child: Divider(height: 1, color: Ink3D.line)), row]) : row,
      ),
    );
  }
}

class SheetOptionCard extends StatelessWidget {
  const SheetOptionCard({super.key, required this.tone, required this.art, required this.title, this.subtitle, this.onTap, this.danger = false});

  final ListingTone tone;
  final String art;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  static double get topRoom => DS.s(22);
  static BorderRadius get radius => DS.br(CardRadius.card);

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: EdgeInsets.only(top: topRoom),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: DS.s(64)),
            padding: EdgeInsets.fromLTRB(DS.s(100), DS.s(12), DS.s(16), DS.s(12)),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              gradient: danger ? Form3D.dangerGradient : tone.gradient,
              borderRadius: radius,
              boxShadow: onTap == null ? null : [BoxShadow(color: danger ? const Color(0x80FA7D82) : tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Colors.white, height: 1.25)),
                if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, Colors.white.withValues(alpha: 0.92), height: 1.3)),
              ],
            ),
          ),
          Positioned(
            left: DS.s(12),
            top: DS.s(-18),
            child: ExcludeSemantics(child: Art3D(asset: art, size: 74, halo: 80, shadowBlur: 5, shadowOffset: const Offset(4, 6), shadowAlpha: 0.25)),
          ),
        ],
      ),
    );
    return Tap3D(onTap: onTap, child: Opacity(opacity: onTap == null ? 0.6 : 1, child: card));
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value, this.big = false, this.divider = true});

  final String label;
  final String value;
  final bool big;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DS.s(4), vertical: DS.s(10)),
      decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: Ink3D.line)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ink3D.text(14, FontWeight.w400, Ink3D.grey)),
          SizedBox(width: DS.s(14)),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: big ? Ink3D.text(20, FontWeight.w700, Ink3D.title, height: 1.2) : Ink3D.text(14, FontWeight.w600, Ink3D.title)),
          ),
        ],
      ),
    );
  }
}

class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.tone, required this.value, required this.onChanged, required this.label});

  final ListingTone tone;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Tap3D(
      onTap: change == null ? null : () => change(!value),
      toggled: value,
      label: label,
      exclude: true,
      child: Opacity(
        opacity: change == null ? 0.5 : 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(48)),
          child: Row(
            children: [
              Container(
                width: DS.s(26),
                height: DS.s(26),
                decoration: BoxDecoration(
                  color: value ? null : Colors.white,
                  gradient: value ? tone.gradient : null,
                  borderRadius: DS.circular(8),
                  border: value ? null : Border.all(color: const Color(0xFFCBD0DA), width: 1.5),
                  boxShadow: value ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: DS.shadowOffset(const Offset(1.1, 3)), blurRadius: DS.shadowBlur(6))] : null,
                ),
                child: value ? Icon(Icons.check_rounded, size: DS.s(18), color: Colors.white) : null,
              ),
              SizedBox(width: DS.s(12)),
              Expanded(child: Text(label, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, height: 1.3))),
            ],
          ),
        ),
      ),
    );
  }
}

class SummaryBar3D extends StatelessWidget {
  const SummaryBar3D({super.key, required this.tone, required this.label, required this.value});

  final ListingTone tone;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: DS.gv(14)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(18), vertical: DS.s(12)),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: DS.br(CardRadius.card),
        boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(10))],
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Ink3D.text(13, FontWeight.w600, Colors.white))),
          SizedBox(width: DS.s(12)),
          Text(value, style: Ink3D.text(22, FontWeight.w700, Colors.white, height: 1.2)),
        ],
      ),
    );
  }
}
