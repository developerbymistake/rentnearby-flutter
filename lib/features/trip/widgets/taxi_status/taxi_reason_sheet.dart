import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

class TaxiReasonSheet<T> extends StatefulWidget {
  const TaxiReasonSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.reasons = const [],
    this.initial,
    this.labelOf,
    this.chipKeyOf,
    required this.confirmLabel,
    required this.confirmKey,
    required this.onConfirm,
  });

  final String title;
  final String? subtitle;
  final List<T> reasons;
  final T? initial;
  final String Function(T reason)? labelOf;
  final Key Function(T reason)? chipKeyOf;
  final String confirmLabel;
  final Key confirmKey;
  final void Function(BuildContext context, T? reason) onConfirm;

  static Future<R?> show<R>(BuildContext context, Widget sheet) =>
      SheetFrame.show<R>(context, builder: (_) => sheet, constraints: const BoxConstraints());

  @override
  State<TaxiReasonSheet<T>> createState() => _TaxiReasonSheetState<T>();
}

class _TaxiReasonSheetState<T> extends State<TaxiReasonSheet<T>> {
  late T? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final sub = widget.subtitle;
    final labelOf = widget.labelOf;
    final panel = Container(
      width: double.infinity,
      padding: DS.insets(l: 18, t: 66, r: 18).copyWith(bottom: DS.s(20) + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(TaxiStatusLook.sheetRadius),
        boxShadow: DS.shadows(TaxiStatusLook.sheetShadow),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0)),
          if (sub != null && sub.isNotEmpty) ...[
            Gap.v(2),
            Text(sub, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, height: 1.5, letterSpacing: 0)),
          ],
          if (widget.reasons.isNotEmpty && labelOf != null) ...[
            Gap.v(16),
            Wrap(
              spacing: DS.gh(10),
              runSpacing: DS.gv(10),
              children: [
                for (final r in widget.reasons)
                  _ReasonChip(
                    key: widget.chipKeyOf?.call(r),
                    label: labelOf(r),
                    selected: r == _picked,
                    onTap: () => setState(() => _picked = r),
                  ),
              ],
            ),
          ],
          Gap.v(18),
          GradientPillButton(
            key: widget.confirmKey,
            tone: ListingTone.coral,
            label: widget.confirmLabel,
            shadows: TaxiStatusLook.redPill,
            onTap: () => widget.onConfirm(context, _picked),
          ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        panel,
        Positioned(
          top: DS.s(-58),
          left: 0,
          right: 0,
          child: const Center(
            child: Art3D(asset: ListingArt.warning, size: 110, shadowBlur: 8, shadowOffset: Offset(8, 12), shadowAlpha: 0.22),
          ),
        ),
        Positioned(right: DS.s(12), top: DS.s(12), child: const SheetCloseButton()),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      child: Container(
        height: DS.s(44),
        padding: DS.sym(h: 18),
        decoration: BoxDecoration(
          color: selected ? null : DesignColors.surface,
          gradient: selected ? ListingTone.indigo.gradient : null,
          borderRadius: DS.br(TaxiStatusLook.chipRadius),
          boxShadow: DS.shadows(TaxiStatusLook.chipShadow),
        ),
        child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, selected ? DesignColors.textInverse : Ink3D.sub, letterSpacing: 0))),
      ),
    );
  }
}
