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
import '../utils/trip_day_timeline.dart';
import '../utils/trip_days_rules.dart';
import '../utils/trip_format.dart';
import 'trip_leg_header.dart';
import 'trip_leg_actions.dart';


class TripDaySpotList extends StatelessWidget {
  final int day;
  final bool inSection;

  const TripDaySpotList(this.day, {super.key, this.inSection = false});

  static const Key headerKey = ValueKey('day-header');
  static const Key chipsKey = ValueKey('day-chips');

  static Future<void> replace(TripPlanController c, String spotId, int day) async {
    final legIndex = c.plan.value?.legIndexOf(day) ?? 1;
    await TripLegActions.addPlaces(legIndex, pickDay: day, replaceSpotId: spotId);
  }

  static BorderRadius get _radius => DS.br(kMealsRadius);

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final plan = c.plan.value;
      c.result.value;
      c.trip.value;
      final d = plan?.dayAt(day);
      if (plan == null || d == null) return const SizedBox.shrink();
      final color = TripLook.dayColor(day - plan.legStart(plan.legIndexOf(day)) + 1);
      final locked = !c.canEditStructure || c.isDayPast(day);
      final editing = c.editMode.value && !locked;
      final closed = [
        for (final w in c.warningsFor(day))
          if (w.code == TripWarningCodes.closedDay) _closedText(plan, w),
      ];
      final full = !TripDaysRules.canAddOnDay(plan, day);
      final narrow = MediaQuery.sizeOf(context).width < 340;
      final artSize = narrow ? 56.0 : 63.0;
      final side = inSection ? 0.0 : DS.s(18);
      final top = DS.s(inSection ? TripLegSectionHeader.dayCardTop : 40);
      final bottomPad = inSection ? 0.0 : DS.gv(16);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: locked || c.editMode.value ? null : () => c.editMode.value = true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, top, side, bottomPad),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: _radius,
                  boxShadow: DS.shadows(TripLook.dayCardShadow),
                ),
                child: ClipRRect(
                  borderRadius: _radius,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _header(c, plan, d, color, editing, DS.s(narrow ? 78.0 : 88.0)),
                      Padding(
                        padding: EdgeInsets.only(bottom: DS.s(8)),
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
                                padding: EdgeInsets.fromLTRB(DS.s(12), DS.gv(8), DS.s(12), 0),
                                child: Row(
                                  children: [
                                    const Art3D(asset: ListingArt.clipboard, size: 20, shadowBlur: 2, shadowOffset: Offset(1, 2)),
                                    Gap.h(8),
                                    Expanded(
                                      child: Text(text, style: Ink3D.text(12, FontWeight.w600, TripLook.warningText)),
                                    ),
                                  ],
                                ),
                              ),
                            if (editing) Padding(padding: DS.sym(h: 12), child: _editFooter(context, c, plan, d, full)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: side + DS.s(10),
              top: top - DS.s(13),
              child: IgnorePointer(
                child: Art3D(asset: ListingArt.calendar, size: artSize, halo: artSize - 1, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22)),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _emptyBody(TripDay d) => Padding(
        padding: DS.sym(v: 14),
        child: Column(
          children: [
            Art3D(asset: d.restDay ? ListingArt.bed : ListingArt.compass, size: 72),
            Gap.v(6),
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
    final title = TripStringsV2Plan.dayHeaderEmpty(day, dateText);
    const white = DesignColors.surface;
    return Container(
      key: headerKey,
      constraints: BoxConstraints(minHeight: DS.s(80)),
      padding: EdgeInsets.fromLTRB(artRoom, DS.s(14), DS.s(14), DS.s(14)),
      decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(height: DS.s(40)),
              Container(
                width: DS.s(14),
                height: DS.s(14),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: white, width: DS.s(2.5))),
              ),
              Gap.h(8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(17, FontWeight.w700, white, height: 1.3, letterSpacing: 0),
                ),
              ),
            ],
          ),
          Gap.v(2),
          Wrap(
            key: chipsKey,
            spacing: DS.gh(10),
            runSpacing: DS.gv(8),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (d.spots.isNotEmpty) Text(TripFormat.hm(load), style: Ink3D.text(13, FontWeight.w600, white, letterSpacing: 0)),
              _pill(TripStringsV2Plan.placesCount(d.spots.length)),
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
        height: DS.s(28),
        padding: DS.sym(h: 10),
        decoration: BoxDecoration(color: fill ?? DesignColors.tint(DesignColors.surface, Alpha.v26), borderRadius: DS.circular(10)),
        child: Center(widthFactor: 1, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, ink ?? DesignColors.surface, letterSpacing: 0))),
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
            margin: EdgeInsets.fromLTRB(DS.s(12), DS.s(8), DS.s(12), DS.gv(6)),
            padding: DS.sym(h: 10, v: 8),
            decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: DS.circular(12)),
            child: Row(
              children: [
                const Art3D(asset: ListingArt.taxi, size: 22, shadowBlur: 2, shadowOffset: Offset(1, 2)),
                Gap.h(8),
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
        Padding(padding: DS.sym(v: 8), child: const Divider(height: 1, color: Ink3D.line)),
        Row(
          children: [
            Expanded(
              child: _action(
                ListingArt.roundPushpin,
                TripStringsV2Plan.addPlace,
                full ? null : () => TripLegActions.addPlaces(d.leg, pickDay: day),
              ),
            ),
            Gap.h(10),
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
            margin: EdgeInsets.only(top: DS.gv(10)),
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
          constraints: BoxConstraints(minHeight: DS.s(44)),
          padding: DS.sym(h: 6, v: 6),
          decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Art3D(asset: art, size: 20, shadowBlur: 2, shadowOffset: const Offset(1, 2)),
              Gap.h(5),
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
    final timeW = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(DS.s(66));
    return Material(
      color: DesignColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: DS.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(60)),
              child: Padding(
                padding: DS.insets(l: 12, t: 8, r: 8, b: 8),
                child: Row(
                  children: [
                    if (editing)
                      ReorderableDelayedDragStartListener(
                        index: index,
                        child: Padding(
                          padding: EdgeInsets.only(right: DS.s(4)),
                          child: Icon(Icons.drag_indicator_rounded, size: DS.s(20), color: TripLook.textHint),
                        ),
                      ),
                    SizedBox(
                      width: timeW,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(time, maxLines: 1, softWrap: false, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
                      ),
                    ),
                    Container(
                      width: DS.s(26),
                      height: DS.s(26),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Text('${index + 1}', style: Ink3D.text(12.5, FontWeight.w700, DesignColors.surface, letterSpacing: 0)),
                    ),
                    Gap.h(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                          Text(
                            '${TripSpotCategory.label(spot.category)} · ${TripFormat.hm(spot.visitMinutes)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
                          ),
                        ],
                      ),
                    ),
                    if (editing)
                      IconButton(
                        onPressed: onRemove,
                        tooltip: TripStringsV2Plan.removePlace,
                        constraints: BoxConstraints(minWidth: DS.s(44), minHeight: DS.s(44)),
                        icon: Container(
                          width: DS.s(32),
                          height: DS.s(32),
                          decoration: BoxDecoration(color: TripLook.errorSurface, shape: BoxShape.circle),
                          child: Icon(Icons.close_rounded, size: DS.s(18), color: TripLook.error),
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.only(left: DS.s(10)),
                        child: Art3D(asset: TripSpotLook.assetOf(spot.category), size: 30, shadowBlur: 2, shadowOffset: const Offset(1, 3)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showDrive)
            Padding(
              padding: EdgeInsets.only(left: DS.s(editing ? 24 : 0) + timeW + DS.s(20)),
              child: Container(
                padding: EdgeInsets.only(left: DS.s(18), top: DS.s(3), bottom: DS.s(3)),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: ListingTone.indigo.g2.withValues(alpha: Alpha.v30), width: DS.s(2))),
                ),
                child: drive == null
                    ? SizedBox(height: DS.s(14))
                    : Row(
                        children: [
                          const Art3D(asset: ListingArt.taxi, size: 16, shadowBlur: 0, shadowAlpha: 0),
                          Gap.h(8),
                          Text(TripFormat.duration(drive), style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
