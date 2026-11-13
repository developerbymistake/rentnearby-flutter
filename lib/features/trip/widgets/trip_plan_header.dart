import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'trip_ui.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_easy_rules.dart';
import '../utils/trip_format.dart';
import 'trip_card.dart';
import 'trip_pace_sheet.dart';
import 'trip_status.dart';

enum TripPlanMenu {
  saveExit,
  editDays,
  editDates,
  rename,
  summary,
  map,
  mute,
  complete,
  delete,
  easy,
}

class TripPlanHeader extends StatelessWidget {
  final ValueChanged<TripPlanMenu> onMenu;

  const TripPlanHeader({super.key, required this.onMenu});

  static String subtitleOf(TripPlanController c) {
    final p = c.plan.value;
    if (p == null) return '';
    final s = c.settings;
    final today = c.todayDay;
    final todayDate = today == null ? null : c.dateOf(today);
    if (today != null && todayDate != null) {
      return TripStringsV2Plan.headerRunning(
        today,
        c.dayCount,
        TripFormat.shortDate(todayDate),
      );
    }
    final start = s.startDate;
    final end = s.endDate(c.dayCount);
    if (start == null || end == null) {
      return TripStringsV2Plan.headerSub(c.dayCount, c.spotCount, p.legCount);
    }
    return TripStringsV2Plan.headerDated(
      c.dayCount,
      TripFormat.dayMonthRange(start, end),
      s.peopleSummary,
    );
  }

  static TripBookingState stateOf(TripPlanController c) {
    final t = c.trip.value;
    if (c.isCompleted) return TripBookingState.completed;
    if (t == null) return TripBookingState.draft;
    final s = TripBookingState.parse(t.bookingState);
    return s == TripBookingState.planOnly ? TripBookingState.draft : s;
  }

  static String? hintOf(TripPlanController c, List<TripEasyRowInfo> rows) {
    if (c.offline.value || c.saveFailed.value)
      return TripStringsV2Plan.hintSavedOnPhone;
    final changed = c.settingsChangedAt.value;
    if (changed != null && DateTime.now().difference(changed).inMinutes < 10)
      return TripStringsV2Plan.hintDatesChanged;
    if (rows.isEmpty) return null;
    final bad = rows
        .where((r) => r.state == TripRowState.attention)
        .firstOrNull;
    if (bad != null) return TripStringsV2Plan.hintAttention;
    final offer = rows.where((r) => r.state == TripRowState.offer).firstOrNull;
    if (offer != null) return TripStringsV2Plan.hintOffer;
    final asked = TripEasyRules.firstInProgress(rows);
    if (asked != null) {
      return switch (asked.key.kind) {
        TripEasyRowKind.stay => TripStringsV2Plan.hintStayWaiting,
        TripEasyRowKind.taxi => TripStringsV2Plan.hintTaxiWaiting,
        _ => TripStringsV2Plan.hintWaiting,
      };
    }
    final progress = c.easyProgress;
    if (progress.total > 0 && progress.done >= progress.total)
      return TripStringsV2Plan.hintAllSet;
    return TripStringsV2Plan.hintMakeItEasy;
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final plan = c.plan.value;
      c.trip.value;
      c.needsUpdate.value;
      c.result.value;
      c.enquiryList.length;
      c.offline.value;
      c.saveFailed.value;
      c.settingsChangedAt.value;
      c.isOpening.value;
      final off = c.plannerOff.value;
      final ready = plan != null && !off;
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ModuleHeader(
          title: plan == null ? TripStringsV2Plan.trip : c.title,
          subtitle: ready ? subtitleOf(c) : null,
          tone: KitTone.brand,
          gradient: ListingTone.indigo.gradient,
          onBack: () => Get.back(),
          trailing: [
            if (ready) ...[
              if (c.editMode.value)
                TripHeaderAction(
                  label: TripStringsV2Plan.done,
                  solid: true,
                  onTap: () => c.editMode.value = false,
                )
              else
                Padding(padding: const EdgeInsets.only(left: 8), child: _MapAction(onTap: () => onMenu(TripPlanMenu.map))),
              _menu(c),
            ],
          ],
          bottom: ready && (c.guideState.on.value || c.editMode.value) ? _statusRow(context, c) : null,
          autoHeight: true,
        ),
      );
    });
  }

  Widget _statusRow(BuildContext context, TripPlanController c) {
    final rows = c.easyRows;
    final progress = c.stepProgress;
    final step = c.isCompleted ? 2 : c.planStep.value;
    final hint = hintOf(c, rows);
    final editable = !c.isReadOnly && !c.needsUpdate.value;
    if (c.guideState.on.value) return _guidedRow(context, c, hint, editable);
    return PressScale(
      scale: 0.98,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onMenu(TripPlanMenu.easy),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: progress.percent.clamp(0, 100).toDouble(),
                ),
                duration: KitMotion.reduce(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.fastOutSlowIn,
                builder: (_, v, _) => TripProgressRing(
                  percent: v.round(),
                  size: 44,
                  stroke: 4,
                  color: DesignColors.surface,
                  track: DesignColors.tint(DesignColors.surface, Alpha.scrim),
                  textColor: DesignColors.surface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      step == 1
                          ? TripStringsV2Plan.stepAddPlaces()
                          : '${TripStringsV2Plan.stepLabel(2)} · ${progress.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsV2Plan.arranged(progress.done, progress.total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(
                        13,
                        FontWeight.w700,
                        color: DesignColors.textInverse,
                      ),
                    ),
                    if (hint != null && step == 2)
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(
                          11,
                          FontWeight.w500,
                          color: DesignColors.whiteHigh,
                        ),
                      ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.percent.clamp(0, 100) / 100,
                        minHeight: 4,
                        color: DesignColors.surface,
                        backgroundColor: DesignColors.tint(
                          DesignColors.surface,
                          Alpha.scrim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: _paceChip(context, c, editable),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guidedRow(
    BuildContext context,
    TripPlanController c,
    String? hint,
    bool editable,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
    child: Row(
      children: [
        Expanded(
          child: hint == null
              ? const SizedBox.shrink()
              : Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(
                    12,
                    FontWeight.w500,
                    color: DesignColors.whiteHigh,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: _paceChip(context, c, editable),
        ),
      ],
    ),
  );

  Widget _paceChip(BuildContext context, TripPlanController c, bool editable) {
    final label = c.settings.isRelaxed
        ? TripStringsV2Plan.paceRelaxed
        : TripStringsV2Plan.paceNormal;
    return PressScale(
      enabled: editable,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: editable
            ? () async {
                final picked = await TripPaceSheet.show(context);
                if (picked != null) await c.setPace(picked);
              }
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DesignColors.whiteSoft,
              borderRadius: CardRadius.pill,
              border: Border.all(
                color: DesignColors.tint(DesignColors.surface, Alpha.half),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(
                      12,
                      FontWeight.w700,
                      color: DesignColors.textInverse,
                    ),
                  ),
                ),
                if (editable)
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: DesignColors.surface,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(TripPlanController c) {
    return PopupMenuButton<TripPlanMenu>(
      icon: const Icon(Icons.more_vert_rounded, color: DesignColors.surface),
      iconSize: 24,
      padding: const EdgeInsets.all(8),
      color: DesignColors.surface,
      elevation: 12,
      shadowColor: DesignColors.tint(DesignColors.shadowBase, Alpha.soft),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      offset: const Offset(0, 56),
      onSelected: onMenu,
      itemBuilder: (_) {
        final saved = c.trip.value != null;
        final editable = !c.isReadOnly && !c.needsUpdate.value;
        return [
          if (editable)
            _item(
              TripPlanMenu.saveExit,
              TravelIcon.luggage,
              TripStringsV2Plan.menuSaveExit,
            ),
          if (editable)
            _item(
              TripPlanMenu.editDays,
              TravelIcon.calendar,
              TripStringsV2Plan.menuEditDays,
            ),
          if (editable)
            _item(
              TripPlanMenu.editDates,
              ListingArt.calendar,
              TripStringsV2Plan.menuEditDates,
            ),
          if (editable)
            _item(
              TripPlanMenu.rename,
              TravelIcon.pin,
              TripStringsV2Plan.menuRename,
            ),
          if (saved)
            _item(
              TripPlanMenu.summary,
              TravelIcon.note,
              TripStringsV2Plan.menuSummary,
            ),
          _item(TripPlanMenu.map, TravelIcon.map, TripStringsV2Plan.menuMap),
          if (saved) _muteItem(c),
          if (saved && c.canComplete)
            _item(
              TripPlanMenu.complete,
              TravelIcon.star,
              TripStringsV2Plan.menuComplete,
            ),
          if (saved)
            _item(
              TripPlanMenu.delete,
              Icons.close_rounded,
              TripStringsV2Plan.menuDelete,
              color: DesignColors.error,
            ),
        ];
      },
    );
  }

  static Widget _tile(Object icon, {bool danger = false}) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: danger ? TripLook.errorSurface : ListingTone.indigo.tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: icon is String
              ? Art3D(asset: icon, size: 40, shadowBlur: 3, shadowOffset: const Offset(2, 3))
              : Icon(icon as IconData, size: 24, color: TripLook.error),
        ),
      );

  PopupMenuItem<TripPlanMenu> _item(
    TripPlanMenu value,
    Object icon,
    String label, {
    Color color = Ink3D.title,
  }) => PopupMenuItem(
    value: value,
    height: 62,
    child: Row(
      children: [
        _tile(icon, danger: icon is! String),
        const SizedBox(width: 14),
        Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, icon is String ? FontWeight.w500 : FontWeight.w600, color))),
      ],
    ),
  );

  PopupMenuItem<TripPlanMenu> _muteItem(TripPlanController c) {
    final muted = c.trip.value?.isMuted ?? false;
    return PopupMenuItem(
      value: TripPlanMenu.mute,
      height: 62,
      child: Row(
        children: [
          _tile(ListingArt.speechBalloon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(TripStringsV2Plan.menuMute, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w500, Ink3D.title)),
                Text(TripStringsV2Plan.menuMuteSub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey)),
              ],
            ),
          ),
          IgnorePointer(child: Switch3D(tone: ListingTone.indigo, value: muted, onChanged: (_) {})),
        ],
      ),
    );
  }
}

class _MapAction extends StatelessWidget {
  const _MapAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: TripStringsV2Plan.map,
      child: Tooltip(
        message: TripStringsV2Plan.map,
        excludeFromSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: Ink3D.whiteBtn),
              child: const Center(child: Art3D(asset: ListingArt.worldMap, size: 30, shadowBlur: 2, shadowOffset: Offset(1, 2))),
            ),
          ),
        ),
      ),
    );
  }
}

class TripPlanStepCard extends StatelessWidget {
  final ValueChanged<TripPlanMenu> onMenu;

  const TripPlanStepCard({super.key, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final plan = c.plan.value;
      c.trip.value;
      c.result.value;
      c.enquiryList.length;
      c.offline.value;
      c.saveFailed.value;
      c.settingsChangedAt.value;
      if (plan == null || c.plannerOff.value || c.guideState.on.value) return const SizedBox.shrink();
      final tone = ListingTone.indigo;
      const white = DesignColors.surface;
      final rows = c.easyRows;
      final progress = c.stepProgress;
      final step = c.isCompleted ? 2 : c.planStep.value;
      final hint = TripPlanHeader.hintOf(c, rows);
      final editable = !c.isReadOnly && !c.needsUpdate.value;
      final pct = progress.percent.clamp(0, 100).toDouble();
      final title = step == 1
          ? TripStringsV2Plan.stepAddPlaces().split(' · ').last
          : (progress.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsV2Plan.arranged(progress.done, progress.total));
      final narrow = MediaQuery.sizeOf(context).width < 340;
      final art = narrow ? 92.0 : 112.0;
      return Tap3D(
        onTap: () => onMenu(TripPlanMenu.easy),
        label: '${TripStringsV2Plan.stepLabel(step)}, $title',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 36, 18, 6),
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 22, 16, 16),
                decoration: BoxDecoration(
                  gradient: tone.gradient,
                  borderRadius: kMealsRadius,
                  boxShadow: [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 6), blurRadius: 14)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: art - 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(TripStringsV2Plan.stepLabel(step), maxLines: 1, style: Ink3D.text(12.5, FontWeight.w600, DesignColors.tint(white, Alpha.v90))),
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(21, FontWeight.w700, white, height: 1.25)),
                          if (hint != null && step == 2)
                            Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, DesignColors.tint(white, Alpha.v90))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  minHeight: 4,
                                  color: white,
                                  backgroundColor: DesignColors.tint(white, Alpha.scrim),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _pace(context, c, editable, tone),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: pct),
                          duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 600),
                          curve: Curves.fastOutSlowIn,
                          builder: (_, v, _) => RingBadge(progress: v / 100, fill: tone.g2, size: 58),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 26,
              top: 0,
              child: IgnorePointer(
                child: Art3D(asset: ListingArt.luggage, size: art, halo: art + 8, haloColor: DesignColors.tint(white, Alpha.v22)),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _pace(BuildContext context, TripPlanController c, bool editable, ListingTone tone) {
    final label = c.settings.isRelaxed ? TripStringsV2Plan.paceRelaxed : TripStringsV2Plan.paceNormal;
    return Tap3D(
      onTap: editable
          ? () async {
              final picked = await TripPaceSheet.show(context);
              if (picked != null) await c.setPace(picked);
            }
          : null,
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.pill, boxShadow: Ink3D.whiteBtn),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, tone.text))),
            if (editable) Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: tone.text),
            const SizedBox(width: 2),
            Text(TripStringsV2Plan.paceTitle.toLowerCase(), maxLines: 1, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey)),
          ],
        ),
      ),
    );
  }
}
