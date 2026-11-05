import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../config/module_palette.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_steps_a1.dart';
import '../trip_strings_steps_a2.dart';
import 'trip_journey_compact.dart';
import 'trip_step_dot.dart';
import 'trip_step_skip_sheet.dart';

class TripStepCard extends StatelessWidget {
  final TripStepRole role;
  final GlobalKey? anchorKey;

  const TripStepCard({super.key, required this.role, this.anchorKey});

  static TripStepKind kindOf(TripStepRole r) =>
      r == TripStepRole.gettingThere ? TripStepKind.gettingThere : TripStepKind.comingBack;

  static Future<void> pickStart(BuildContext context) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return;
    final p = await LocationSwitchSheet.pick(context, palette: ModulePalette.trip, title: TripStringsStepsA2.pickCity);
    if (p == null) return;
    final moved = await c.setStartFrom(TripStartFrom(name: p.name, lat: p.latitude, lon: p.longitude));
    if (moved && context.mounted) await askSearchAgain(context);
  }

  static Future<void> askSearchAgain(BuildContext context) async {
    final c = TripPlanController.to;
    final city = c.startFrom?.name ?? '';
    final again = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          TripStringsStepsA2.startChanged,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          TripStringsStepsA2.searchFromAgain(city),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsStepsA2.later,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              TripStringsStepsA2.searchAgain,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark),
            ),
          ),
        ],
      ),
    );
    if (again != true) return;
    final first = TripStepRole.values.firstWhere(
      (r) => c.journeyFor(r)?.startChanged == true,
      orElse: () => TripStepRole.gettingThere,
    );
    TripNavigation.openWays(first);
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return KeyedSubtree(
      key: anchorKey,
      child: Obx(() {
        c.plan.value;
        c.trip.value;
        c.offline.value;
        if (c.plan.value == null) return const SizedBox.shrink();
        final display = c.stepDisplay(role);
        final journey = c.journeyFor(role);
        final readOnly = c.isReadOnly;
        final hasJourney = journey != null &&
            (display == TripStepDisplay.chosen || display == TripStepDisplay.asked || display == TripStepDisplay.booked);
        if (hasJourney) return _journeyCard(context, c, display, journey, readOnly);
        return switch (display) {
          TripStepDisplay.own => _statusCard(
              context,
              c,
              display,
              TripStringsStepsA2.arrangedByYou(c.stepOf(role).note),
              actions: readOnly ? const [] : [_textAction(TripStringsStepsA2.undo, () => c.resetStep(role))],
            ),
          TripStepDisplay.skipped => _statusCard(
              context,
              c,
              display,
              TripStringsStepsA2.skippedLine,
              actions: readOnly
                  ? const []
                  : [
                      _textAction(TripStringsStepsA2.seeWays, () => TripNavigation.openWays(role)),
                      _textAction(TripStringsStepsA2.undo, () => c.resetStep(role)),
                    ],
            ),
          TripStepDisplay.notNeeded =>
            _statusCard(context, c, display, TripStringsStepsA2.notNeededLine(c.startFrom?.name ?? '')),
          _ => readOnly ? _readOnlyEmpty(c) : _emptyCard(context, c),
        };
      }),
    );
  }

  Widget _frame({required List<Widget> children, bool amber = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber ? TripStatusColors.waiting : AppColors.divider, width: amber ? 1.5 : 1),
        boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.08, blur: 12, offset: const Offset(0, 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _title(String text) => Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
      );

  Widget _body(String text, {Color color = AppColors.textLight, int maxLines = 3}) => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: color, height: 1.35),
      );

  Widget _titleRow(String title, TripStepDisplay display, {bool attention = false}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _title(title)),
          const SizedBox(width: 8),
          Flexible(child: TripStepChip(display, attention: attention)),
        ],
      );

  Widget _readOnlyEmpty(TripPlanController c) => _frame(children: [
        _title(TripStringsStepsA1.stepName(kindOf(role))),
        const SizedBox(height: 4),
        _body(TripStringsStepsA2.notArranged, color: AppColors.textHint),
      ]);

  Widget _statusCard(
    BuildContext context,
    TripPlanController c,
    TripStepDisplay display,
    String line, {
    List<Widget> actions = const [],
  }) {
    return _frame(children: [
      _titleRow(TripStringsStepsA1.stepName(kindOf(role)), display),
      const SizedBox(height: 4),
      _body(line),
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 0, children: actions),
      ],
    ]);
  }

  Widget _emptyCard(BuildContext context, TripPlanController c) {
    final start = c.startFrom;
    final city = role == TripStepRole.comingBack ? c.lastCityName : c.cityName;
    final back = role == TripStepRole.comingBack;
    final people = c.settings.peopleCount;
    return _frame(children: [
      _title(back ? TripStringsStepsA2.howComeBack(city) : TripStringsStepsA2.howGetTo(city)),
      const SizedBox(height: 10),
      if (start == null) ...[
        _noStart(context),
        const SizedBox(height: 12),
        GradientButton(
          label: TripStringsStepsA2.pickCity,
          height: 48,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: () => pickStart(context),
        ),
      ] else ...[
        _startTile(context, back ? TripStringsStepsA2.backTo : TripStringsStepsA2.startingFrom, start.name),
        const SizedBox(height: 10),
        _body(TripStringsStepsA2.feedHint(c.stepDate(role), people)),
        const SizedBox(height: 12),
        GradientButton(
          label: TripStringsStepsA2.seeWays,
          height: 48,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: () => TripNavigation.openWays(role),
        ),
      ],
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: () => TripStepSkipSheet.show(context, step: kindOf(role)),
          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text(
            TripStringsStepsA2.arrangeMyself,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.neutralChipText),
          ),
        ),
      ),
    ]);
  }

  Widget _noStart(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Iconsax.location, size: 18, color: TripColors.accentDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    TripStringsStepsA2.whereStart,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  _body(TripStringsStepsA2.whereStartBody, maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _startTile(BuildContext context, String label, String name) => Material(
        color: TripColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => pickStart(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  const Icon(Iconsax.location, size: 18, color: TripColors.accentDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.warningText,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          TripStringsStepsA2.change,
                          maxLines: 1,
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _journeyCard(
    BuildContext context,
    TripPlanController c,
    TripStepDisplay display,
    TripJourney j,
    bool readOnly,
  ) {
    final back = role == TripStepRole.comingBack;
    final booked = display == TripStepDisplay.booked;
    final checkOut = c.checkOutDate;
    final onCheckOut = back && checkOut != null && _sameDay(j.date, checkOut);
    final changed = j.dateChanged || j.startChanged;
    final main = _frame(
      amber: j.needsAttention,
      children: [
        _titleRow(TripStringsStepsA2.fromTo(j.fromName, j.toName), display, attention: j.needsAttention),
        const SizedBox(height: 2),
        _body(
          TripStringsStepsA2.journeyMeta(cars: j.cars, total: j.listedTotal, date: j.date, checkOut: onCheckOut),
          maxLines: 2,
        ),
        if (changed) ...[
          const SizedBox(height: 10),
          _changedLine(j.dateChanged ? TripStringsStepsA2.dateChanged : TripStringsStepsA2.startChanged, readOnly),
        ],
        const SizedBox(height: 10),
        TripJourneyCompact(journey: j, tone: booked ? TripStatusColors.booked : null),
        if (!readOnly) ...[
          if (!booked) ...[
            const SizedBox(height: 12),
            _pair(
              _outlined(TripStringsStepsA2.change, () => TripNavigation.openWays(role)),
              _filled(TripStringsStepsA2.askDrivers(j.legs.length), () => TripNavigation.openJourney(j.id)),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              booked
                  ? _textAction(TripStringsStepsA2.notBookedYet, () => c.unmarkStepBooked(role))
                  : _textAction(TripStringsStepsA2.iBookedIt, () => c.markStepBooked(role)),
              _textAction(TripStringsStepsA2.openJourney, () => TripNavigation.openJourney(j.id)),
            ],
          ),
        ],
      ],
    );
    if (!back || readOnly || !booked) return main;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        const SizedBox(height: 8),
        _frame(children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _body(TripStringsStepsA2.differentWayBack, maxLines: 2),
              _textAction(TripStringsStepsA2.seeWays, () => TripNavigation.openWays(role)),
            ],
          ),
        ]),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _changedLine(String text, bool readOnly) => Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Iconsax.warning_2, size: 15, color: AppColors.warningText),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
                ),
              ),
            ),
            if (!readOnly)
              TextButton(
                onPressed: () => TripNavigation.openWays(role),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text(
                  TripStringsStepsA2.searchAgain,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningText),
                ),
              ),
          ],
        ),
      );

  Widget _pair(Widget a, Widget b) => LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, const SizedBox(height: 8), b],
          );
        }
        return Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]);
      });

  Widget _outlined(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: AppColors.divider, width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
        ),
      );

  Widget _filled(String label, VoidCallback onTap) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 44),
          elevation: 0,
          backgroundColor: TaxiColors.accentDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      );

  Widget _textAction(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark),
        ),
      );
}

class TripStepChip extends StatelessWidget {
  final TripStepDisplay display;
  final bool attention;

  const TripStepChip(this.display, {super.key, this.attention = false});

  @override
  Widget build(BuildContext context) {
    final look = TripStepLook.of(display, attention: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: look.surface, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attention) ...[
            const Icon(Iconsax.warning_2, size: 12, color: AppColors.warningText),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              TripStringsStepsA1.stepLabel(display),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w800, color: look.text),
            ),
          ),
        ],
      ),
    );
  }
}
