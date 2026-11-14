import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/design_colors.dart';
import 'art_3d.dart';
import 'dock_inset.dart';
import 'pill_buttons_3d.dart';
import 'sheet_close_button.dart';

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
    this.padding = const EdgeInsets.fromLTRB(22, 0, 22, 0),
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
  final EdgeInsets padding;
  final bool fitTitle;
  final bool artRight;
  final bool showClose;
  final bool closeEnabled;

  static const double artRoom = 70;
  static const double closeRoom = 44;
  static const double artRightInset = 70;
  static const BorderRadius radius = BorderRadius.vertical(top: Radius.circular(32));

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
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (c) => DockLift(child: builder(c)),
  );

  // Height of the white panel (the art room above it is extra).
  static double heightFor(SheetSize size, BuildContext context) {
    final mq = MediaQuery.of(context);
    final cap = math.max(240.0, mq.size.height - mq.viewPadding.top - 60 - SheetInsets.lift(context));
    final base = switch (size) {
      SheetSize.hug => cap,
      SheetSize.short => 350.0,
      SheetSize.confirm => 566.0,
      SheetSize.list => 650.0,
      SheetSize.form => 742.0,
    };
    return math.min(size == SheetSize.hug ? base : base + mq.viewPadding.bottom, cap);
  }

  Widget _header(BuildContext context) {
    final sideRoom = showClose && art == null ? closeRoom : 0.0;
    if (centerTitle) {
      return Padding(
        padding: EdgeInsets.fromLTRB(22 + sideRoom, 0, 22 + sideRoom, 14),
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
                padding: const EdgeInsets.only(top: 6),
                child: Text(subtitle!, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy, height: 1.45)),
              ),
          ],
        ),
      );
    }
    final action = headerAction;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18 + (showClose && !(artRight && art != null) ? closeRoom : 0), 6),
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
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x669E9E9E), offset: Offset(3, 5), blurRadius: 10)]),
                  child: Icon(Icons.chevron_left_rounded, size: 26, color: tone.text),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: EdgeInsets.only(right: artRight && art != null ? 128 + artRightInset - 18 : 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      header: true,
                      child: Text(title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.2)),
                    ),
                  ),
                ),
                if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub)),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Tap3D(
                onTap: onHeaderAction,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: tone.gradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(1.1, 3), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(action, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, Colors.white)),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
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
    final a = art;
    final hug = size == SheetSize.hug;
    final h = heightFor(size, context);
    final hasHeader = title != null || subtitle != null || onBack != null || headerAction != null;
    final body = scrollable
        ? SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: padding, child: child)
        : Padding(padding: padding, child: child);
    final note = footnote;
    final panel = Container(
      width: double.infinity,
      height: hug ? null : h,
      constraints: hug ? BoxConstraints(maxHeight: h) : null,
      padding: EdgeInsets.only(top: artRight ? 34 : a != null ? (centerTitle ? 80 : 70) : 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [BoxShadow(color: Color(0x33000000), offset: Offset(0, -4), blurRadius: 24)],
      ),
      child: Column(
        mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) _header(context),
          if (hug) Flexible(child: body) else Expanded(child: body),
          if (footer != null) Padding(padding: EdgeInsets.fromLTRB(22, 12, 22, note == null ? 26 + mq.viewPadding.bottom : 0), child: footer),
          if (note != null)
            Container(
              constraints: BoxConstraints(minHeight: (size == SheetSize.confirm ? 52 : 40) + mq.viewPadding.bottom),
              padding: EdgeInsets.fromLTRB(28, 10, 28, 8 + mq.viewPadding.bottom),
              alignment: Alignment.topCenter,
              child: Text(note, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.35)),
            ),
          if (footer == null && note == null) SizedBox(height: 18 + mq.viewPadding.bottom),
        ],
      ),
    );
    return Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a != null) const SizedBox(height: artRoom),
            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  panel,
                  if (artRight)
                    Positioned(
                      top: 10,
                      child: IgnorePointer(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Ink3D.line, borderRadius: BorderRadius.circular(2)))),
                    ),
                  if (a != null)
                    Positioned(
                      top: -66,
                      right: artRight ? artRightInset : null,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: Art3D(asset: a, size: 128, halo: 136, haloColor: tone.haloBase.withValues(alpha: 0.18), shadowBlur: 7, shadowOffset: const Offset(5, 9), shadowAlpha: 0.3),
                        ),
                      ),
                    ),
                  if (showClose)
                    Positioned(top: 12, right: 12, child: SheetCloseButton(enabled: closeEnabled)),
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
    this.margin = const EdgeInsets.fromLTRB(18, 14, 18, 8),
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
  final EdgeInsets margin;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      constraints: const BoxConstraints(minHeight: 56),
      padding: trailingArt != null ? const EdgeInsets.fromLTRB(20, 6, 6, 6) : const EdgeInsets.fromLTRB(12, 7, 18, 7),
      decoration: BoxDecoration(
        color: flat ? Form3D.fill : Colors.white,
        borderRadius: BorderRadius.circular(38),
        boxShadow: flat ? null : const [BoxShadow(color: Color(0x599E9E9E), offset: Offset(3, 5), blurRadius: 12)],
      ),
      child: Row(
        children: [
          if (leadingArt != null) ...[
            ExcludeSemantics(child: Art3D(asset: leadingArt!, size: 36, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25)),
            const SizedBox(width: 10),
          ] else if (trailingArt == null)
            const SizedBox(width: 8),
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
            const SizedBox(width: 10),
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: tone.gradient,
                  boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(3, 6), blurRadius: 10)],
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
      constraints: BoxConstraints(minHeight: compact ? 48 : 76),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(border: divider && !roundArt ? const Border(top: BorderSide(color: Ink3D.line)) : null),
      child: Row(
        children: [
          if (art != null) ...[
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: roundArt && selected ? tone.g1 : tone.haloBase.withValues(alpha: 0.14),
                        shape: roundArt ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: roundArt ? null : BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  Positioned(left: -4, top: -10, child: Art3D(asset: art!, size: 60, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, selected ? FontWeight.w700 : FontWeight.w500, Ink3D.body)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              Container(
                width: 28,
                height: 28,
                decoration: selected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: tone.gradient,
                        boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(1.1, 3), blurRadius: 6)],
                      )
                    : null,
                child: selected ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null,
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
        child: roundArt && divider ? Column(mainAxisSize: MainAxisSize.min, children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Ink3D.line)), row]) : row,
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

  static const double topRoom = 22;
  static const BorderRadius radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(32), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: const EdgeInsets.only(top: topRoom),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(100, 12, 16, 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              gradient: danger ? Form3D.dangerGradient : tone.gradient,
              borderRadius: radius,
              boxShadow: onTap == null ? null : [BoxShadow(color: danger ? const Color(0x80FA7D82) : tone.shadow.withValues(alpha: 0.5), offset: const Offset(1.1, 4), blurRadius: 8)],
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
            left: 12,
            top: -18,
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: Ink3D.line)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ink3D.text(14, FontWeight.w400, Ink3D.grey)),
          const SizedBox(width: 14),
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
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: value ? null : Colors.white,
                  gradient: value ? tone.gradient : null,
                  borderRadius: BorderRadius.circular(8),
                  border: value ? null : Border.all(color: const Color(0xFFCBD0DA), width: 1.5),
                  boxShadow: value ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: const Offset(1.1, 3), blurRadius: 6)] : null,
                ),
                child: value ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
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
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: const Offset(1.1, 4), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Ink3D.text(13, FontWeight.w600, Colors.white))),
          const SizedBox(width: 12),
          Text(value, style: Ink3D.text(22, FontWeight.w700, Colors.white, height: 1.2)),
        ],
      ),
    );
  }
}
