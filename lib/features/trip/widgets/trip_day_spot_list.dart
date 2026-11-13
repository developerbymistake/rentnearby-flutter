import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'trip_update_ask_sheet.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_spot_category.dart';
import '../screens/trip_edit_spot_sheet.dart';
import '../trip_strings_v2_plan.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_day_load.dart';
import '../utils/trip_day_timeline.dart';
import '../utils/trip_days_rules.dart';
import '../utils/trip_format.dart';
import 'trip_leg_menu_sheet.dart';

const List<String> _dayArts = [ListingArt.sunrise, ListingArt.mountain, ListingArt.tent, ListingArt.beach, ListingArt.camping];

class TripDaySpotList extends StatelessWidget {
  final int day;

  const TripDaySpotList(this.day, {super.key});

  static Future<void> replace(TripPlanController c, String spotId, int day) async {
    final legIndex = c.plan.value?.legIndexOf(day) ?? 1;
    await TripLegMenuSheet.addPlaces(legIndex, pickDay: day, replaceSpotId: spotId);
  }

  static const BorderRadius _radius = kMealsRadius;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final color = TripLook.dayColor(day);
    final tone = ListingTone.indigo;
    return Obx(() {
      final plan = c.plan.value;
      c.result.value;
      c.trip.value;
      final d = plan?.dayAt(day);
      if (plan == null || d == null) return const SizedBox.shrink();
      final locked = c.isReadOnly || c.needsUpdate.value || c.isDayPast(day);
      final editing = c.editMode.value && !locked;
      final closed = [
        for (final w in c.warningsFor(day))
          if (w.code == TripWarningCodes.closedDay) _closedText(plan, w),
      ];
      final full = !TripDaysRules.canAddOnDay(plan, day);
      final narrow = MediaQuery.sizeOf(context).width < 340;
      final artSize = narrow ? 88.0 : 104.0;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: locked || c.editMode.value ? null : () => c.editMode.value = true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 40, 18, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: _radius,
                  boxShadow: [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 6), blurRadius: 14)],
                ),
                child: ClipRRect(
                  borderRadius: _radius,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _header(c, plan, d, color, editing, narrow ? 104.0 : 120.0),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (d.spots.isEmpty)
                              _emptyBody(d)
                            else
                              _spots(context, c, plan, d, color, locked, editing),
                            for (final text in closed)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Art3D(asset: ListingArt.clipboard, size: 20, shadowBlur: 2, shadowOffset: Offset(1, 2)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(text, style: Ink3D.text(12, FontWeight.w600, TripLook.warningText)),
                                    ),
                                  ],
                                ),
                              ),
                            if (editing) _editFooter(context, c, plan, d, full),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              top: 0,
              child: IgnorePointer(
                child: Art3D(asset: _dayArts[(day - 1) % _dayArts.length], size: artSize, halo: artSize + 4, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22)),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _emptyBody(TripDay d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Art3D(asset: d.restDay ? ListingArt.bed : ListingArt.compass, size: 72),
            const SizedBox(height: 6),
            Text(
              d.restDay ? TripStringsV2Plan.restDay : TripStringsV2Plan.noPlacesThisDay,
              textAlign: TextAlign.center,
              style: Ink3D.text(13.5, FontWeight.w600, Ink3D.grey),
            ),
          ],
        ),
      );

  Widget _header(TripPlanController c, TripPlan plan, TripDay d, Color color, bool editing, double artRoom) {
    final date = c.dateOf(day);
    final dateText = date == null ? null : TripFormat.shortDate(date);
    final load = c.dayLoadMinutes(day);
    final over = d.spots.isNotEmpty && TripDayLoad.isOver(load, c.settings.dayLimitMinutes);
    final title = TripStringsV2Plan.dayHeaderEmpty(day, dateText);
    const white = DesignColors.surface;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: EdgeInsets.fromLTRB(artRoom, 14, 12, 12),
      decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: white, width: 2.5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(17, FontWeight.w700, white, height: 1.25),
                ),
              ),
            ],
          ),
          if (d.spots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(TripFormat.duration(load), style: Ink3D.text(12.5, FontWeight.w600, white)),
                  if (over) _pill(TripStringsV2Plan.longDay, fill: TripLook.warningSurface, ink: TripLook.warningText),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(TripStringsV2Plan.placesCount(d.spots.length)),
              if (plan.isMultiCity) _pill(c.cityNameOf(day)),
              if (editing && plan.legDayCount(d.leg) > 1)
                Tap3D(
                  onTap: () => _removeDay(c),
                  label: TripStringsV2Plan.removeDay,
                  child: _pill(TripStringsV2Plan.removeDay, fill: white, ink: TripLook.errorText),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {Color? fill, Color? ink}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: fill ?? DesignColors.tint(DesignColors.surface, Alpha.v26), borderRadius: BorderRadius.circular(10)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, ink ?? DesignColors.surface)),
      );

  Widget _spots(
    BuildContext context,
    TripPlanController c,
    TripPlan plan,
    TripDay d,
    Color color,
    bool locked,
    bool editing,
  ) {
    final roads = <int?>[
      for (var i = 0; i < d.spots.length; i++) i == d.spots.length - 1 ? null : c.legFrom(day, d.spots[i].id)?.minutes,
    ];
    final reserved = c.dayReservedMinutes(day);
    final starts = TripDayTimeline.starts(
      visits: [for (final s in d.spots) s.visitMinutes],
      roads: roads,
      reserved: reserved,
    );
    final travel = reserved > 0 && plan.legIndexOf(day) >= 2 && plan.legStart(plan.legIndexOf(day)) == day;
    final k = plan.legIndexOf(day);
    final prev = travel ? plan.legAt(k - 1)?.cityName : null;
    Widget item(int i) {
      final s = d.spots[i];
      return _StopItem(
        key: ValueKey(s.id),
        index: i,
        spot: s,
        color: color,
        time: TripDayTimeline.clock(starts[i]),
        driveMinutes: roads[i],
        showDrive: i != d.spots.length - 1,
        editing: editing,
        onRemove: () => _remove(context, c, d, i),
        onTap: editing ? () => _spotMenu(context, c, s) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (travel && prev != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Art3D(asset: ListingArt.taxi, size: 22, shadowBlur: 2, shadowOffset: Offset(1, 2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    TripStringsV2Plan.travelRow(prev, plan.legAt(k)?.cityName ?? '', TripFormat.duration(reserved)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12, FontWeight.w600, Ink3D.title),
                  ),
                ),
              ],
            ),
          ),
        if (editing)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: d.spots.length,
            onReorder: (o, n) => c.reorder(day, o, n),
            itemBuilder: (_, i) => item(i),
          )
        else
          for (var i = 0; i < d.spots.length; i++) item(i),
      ],
    );
  }

  void _remove(BuildContext context, TripPlanController c, TripDay d, int index) {
    final spot = d.spots[index];
    c.removeSpot(spot.id, keepEmptyDays: true);
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(
        content: const Text(TripStringsV2Plan.placeRemoved, style: TextStyle(fontFamily: FitnessAppTheme.fontName)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: TripStringsV2Plan.undo, onPressed: () => c.insertSpotAt(spot, day, index)),
      ),
    );
  }

  Widget _editFooter(BuildContext context, TripPlanController c, TripPlan plan, TripDay d, bool full) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Ink3D.line)),
        Row(
          children: [
            Expanded(
              child: _action(
                ListingArt.roundPushpin,
                TripStringsV2Plan.addPlace,
                full ? null : () => TripLegMenuSheet.addPlaces(d.leg, pickDay: day),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _action(
                ListingArt.bed,
                d.restDay ? TripStringsV2Plan.undoRestDay : TripStringsV2Plan.makeRestDay,
                d.spots.isEmpty ? () => c.setRestDay(day, !d.restDay) : null,
              ),
            ),
          ],
        ),
        if (full)
          Banner3D(
            kind: BannerKind.warn,
            art: ListingArt.calendar,
            title: TripStringsV2Plan.dayFull,
            actionLabel: TripStringsV2Plan.addDay,
            onAction: c.canAddDay
                ? () {
                    c.addDay(afterDay: day);
                    TripUpdateAskSheet.afterDaysEdit();
                  }
                : null,
            margin: const EdgeInsets.only(top: 10),
          ),
      ],
    );
  }

  void _removeDay(TripPlanController c) {
    final r = c.removeDay(day);
    final text = switch (r) {
      TripDayRemoveBlock.none => null,
      TripDayRemoveBlock.placesDontFit => TripStringsV2Plan.removePlacesFirst,
      TripDayRemoveBlock.lastDay => TripStringsV2Plan.lastDay,
      TripDayRemoveBlock.readOnly => TripStringsV2Plan.readOnlyDay,
    };
    if (text != null) {
      _toast(text);
    } else {
      TripUpdateAskSheet.afterDaysEdit();
    }
  }

  void _toast(String text) {
    final m = Get.context == null ? null : ScaffoldMessenger.maybeOf(Get.context!);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontFamily: FitnessAppTheme.fontName))));
  }

  Widget _action(String art, String label, VoidCallback? onTap) {
    final tone = ListingTone.indigo;
    return Opacity(
      opacity: onTap == null ? Alpha.v45 : 1,
      child: Tap3D(
        onTap: onTap,
        label: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(color: tone.tint, borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Art3D(asset: art, size: 20, shadowBlur: 2, shadowOffset: const Offset(1, 2)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w600, tone.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _spotMenu(BuildContext context, TripPlanController c, TripSpotRef s) async {
    final tone = ListingTone.indigo;
    final choice = await SheetFrame.show<String>(
      context,
      builder: (sheetCtx) => SheetFrame(
        title: s.name,
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetOptionCard(tone: tone, art: ListingArt.roundPushpin, title: TripStringsWizard.replacePlace, onTap: () => Navigator.pop(sheetCtx, 'replace')),
            SheetOptionCard(tone: tone, art: ListingArt.calendar, title: TripStringsWizard.moveToDay, onTap: () => Navigator.pop(sheetCtx, 'move')),
            SheetOptionCard(tone: tone, art: ListingArt.clipboard, title: TripStringsWizard.removePlace, onTap: () => Navigator.pop(sheetCtx, 'remove')),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'replace':
        await replace(c, s.id, day);
      case 'move':
        await TripEditSpotSheet.show(context, s.id);
      case 'remove':
        final i = c.plan.value?.dayAt(day)?.spots.indexWhere((x) => x.id == s.id) ?? -1;
        if (i >= 0) _remove(context, c, c.plan.value!.dayAt(day)!, i);
    }
  }

  String _closedText(TripPlan plan, TripWarning w) {
    final id = w.spotId;
    final name = id == null ? null : plan.spotById(id)?.name;
    return name == null ? w.message : TripStringsWizard.closedThatDay(name);
  }
}

class _StopItem extends StatelessWidget {
  final int index;
  final TripSpotRef spot;
  final Color color;
  final String time;
  final int? driveMinutes;
  final bool showDrive;
  final bool editing;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _StopItem({
    super.key,
    required this.index,
    required this.spot,
    required this.color,
    required this.time,
    required this.driveMinutes,
    required this.showDrive,
    required this.editing,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final drive = driveMinutes;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final timeW = MediaQuery.textScalerOf(context).scale(narrow ? 52 : 60);
    return Material(
      color: DesignColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (editing)
                      ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.drag_indicator_rounded, size: 20, color: TripLook.textHint),
                        ),
                      ),
                    SizedBox(
                      width: timeW,
                      child: Text(time, maxLines: 1, style: Ink3D.text(11.5, FontWeight.w600, Ink3D.sub)),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Text('${index + 1}', style: Ink3D.text(11.5, FontWeight.w700, DesignColors.surface)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title)),
                          Text(
                            '${TripSpotCategory.label(spot.category)} · ${TripFormat.visit(spot.visitMinutes)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey),
                          ),
                        ],
                      ),
                    ),
                    if (editing)
                      IconButton(
                        onPressed: onRemove,
                        tooltip: TripStringsV2Plan.removePlace,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: TripLook.errorSurface, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18, color: TripLook.error),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Art3D(asset: TripSpotLook.assetOf(spot.category), size: 34, shadowBlur: 2, shadowOffset: const Offset(1, 3)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showDrive)
            Padding(
              padding: EdgeInsets.only(left: (editing ? 24 : 0) + timeW + 12),
              child: Container(
                padding: const EdgeInsets.only(left: 19, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: color.withValues(alpha: Alpha.scrim), width: 2)),
                ),
                child: drive == null
                    ? const SizedBox(height: 14)
                    : Row(
                        children: [
                          const Art3D(asset: ListingArt.taxi, size: 16, shadowBlur: 0),
                          const SizedBox(width: 6),
                          Text(TripFormat.duration(drive), style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey)),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
