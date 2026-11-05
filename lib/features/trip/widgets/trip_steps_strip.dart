import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_steps_a1.dart';
import '../trip_strings_steps_a2.dart';
import 'trip_step_dot.dart';

class TripStepsStrip extends StatelessWidget {
  final void Function(TripStepKind) onTap;
  final void Function(TripStepKind)? onLongPress;

  const TripStepsStrip({super.key, required this.onTap, this.onLongPress});

  static const double _chipMin = 72;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.plan.value;
      c.trip.value;
      c.enquiryList.length;
      c.offline.value;
      final items = [for (final k in TripStepKind.values) _item(c, k)];
      final readOnly = c.isReadOnly;
      final progress = TripStringsStepsA1.sortedOf(c.stepsSorted, TripStepKind.values.length);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, box) {
            final fits = box.maxWidth >= _chipMin * items.length + _gap * (items.length - 1);
            final chips = [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                fits
                    ? Expanded(child: _chip(items[i], readOnly))
                    : SizedBox(width: _chipMin + 8, child: _chip(items[i], readOnly)),
              ],
            ];
            final row = IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: chips),
            );
            if (fits) return row;
            return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
          }),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, box) {
            const hint = Text(
              TripStringsStepsA2.stepsHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
            );
            final count = Text(
              progress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMedium),
            );
            if (box.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [hint, const SizedBox(height: 2), count],
              );
            }
            return Row(
              children: [
                const Expanded(child: hint),
                const SizedBox(width: 8),
                count,
              ],
            );
          }),
        ],
      );
    });
  }

  _StripItem _item(TripPlanController c, TripStepKind k) {
    switch (k) {
      case TripStepKind.itinerary:
        final d = c.itineraryDisplay;
        return _StripItem(k, d, false, d == TripStepDisplay.chosen ? TripStringsStepsA1.planned : TripStringsStepsA1.stepLabel(d));
      case TripStepKind.gettingThere:
      case TripStepKind.comingBack:
        final role = k == TripStepKind.gettingThere ? TripStepRole.gettingThere : TripStepRole.comingBack;
        final d = c.stepDisplay(role);
        return _StripItem(k, d, c.stepNeedsAttention(role), TripStringsStepsA1.stepLabel(d));
      case TripStepKind.stay:
        final s = c.stayStep;
        final red = c.showStayOption && c.firstRedDay != null;
        return _StripItem(k, s.display, red, _countLabel(s.display, s.sorted, s.total), partial: _isPartial(s.sorted, s.total));
      case TripStepKind.localTaxi:
        final t = c.taxiStep;
        final red = c.showTaxiOption && c.firstRedTaxiDay != null;
        return _StripItem(k, t.display, red, _countLabel(t.display, t.sorted, t.total), partial: _isPartial(t.sorted, t.total));
    }
  }

  static bool _isPartial(int sorted, int total) => sorted > 0 && sorted < total;

  static String _countLabel(TripStepDisplay d, int sorted, int total) =>
      _isPartial(sorted, total) ? '$sorted/$total' : TripStringsStepsA1.stepLabel(d);

  Widget _chip(_StripItem it, bool readOnly) {
    final partial = it.partial;
    final look = TripStepLook.of(it.display, attention: it.attention);
    final name = TripStringsStepsA1.stepName(it.kind);
    final long = onLongPress != null &&
            !readOnly &&
            (it.kind == TripStepKind.stay || it.kind == TripStepKind.localTaxi)
        ? () => onLongPress!(it.kind)
        : null;
    return Semantics(
      button: true,
      label: '$name, ${it.status}',
      excludeSemantics: true,
      child: Material(
        color: look.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(it.kind),
          onLongPress: long,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TripStepDot(it.display, attention: it.attention),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: look.text,
                    ),
                  ),
                  if (partial)
                    Text(
                      it.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w600, color: look.text),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StripItem {
  final TripStepKind kind;
  final TripStepDisplay display;
  final bool attention;
  final String status;
  final bool partial;

  const _StripItem(this.kind, this.display, this.attention, this.status, {this.partial = false});
}
