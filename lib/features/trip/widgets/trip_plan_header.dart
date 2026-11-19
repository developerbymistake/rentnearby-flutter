import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'trip_ui.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../utils/trip_guide_rules.dart';
import '../trip_strings_dayplan.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_easy_rules.dart';
import '../utils/trip_format.dart';
import 'guide/trip_guide_header_text.dart';
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
  static double get _guideSide => DS.s(16);
  // Left room kept free for the question circle, less the header side padding.
  static double get _circleRoom => DS.s(GuideSheetScaffold.circleLeft + GuideSheetScaffold.circleSize) - _guideSide;

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
      TripFormat.fullRange(start, end),
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
      c.guideState.on.value;
      c.guideState.index.value;
      c.guideState.total.value;
      final off = c.plannerOff.value;
      final ready = plan != null && !off;
      final question = ready && c.guideState.on.value ? c.guideState.stepNow : null;
      if (question != null && plan != null) {
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: _guideHeader(context, c, plan, question),
        );
      }
      final header = TripFlowHeader(
        title: plan == null ? TripStringsV2Plan.trip : c.title,
        subtitle: ready ? subtitleOf(c) : null,
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
              ...[Gap.h(12), _MapAction(onTap: () => onMenu(TripPlanMenu.map))],
            Gap.h(12),
            _menu(c),
          ],
        ],
      );
      final bottom = ready && (c.guideState.on.value || c.editMode.value) ? _statusRow(context, c) : null;
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: bottom == null
            ? header
            : ModuleHeader(
                title: plan == null ? TripStringsV2Plan.trip : c.title,
                subtitle: ready ? subtitleOf(c) : null,
                tone: KitTone.brand,
                gradient: ListingTone.indigo.gradient,
                onBack: () => Get.back(),
                trailing: [
                  if (ready) ...[
                    if (c.editMode.value)
                      TripHeaderAction(label: TripStringsV2Plan.done, solid: true, onTap: () => c.editMode.value = false)
                    else
                      ...[Gap.h(12), _MapAction(onTap: () => onMenu(TripPlanMenu.map))],
                    Gap.h(12),
                    _menu(c),
                  ],
                ],
                bottom: bottom,
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
    final editable = c.canEditStructure;
    if (c.guideState.on.value) return _guidedRow(context, c, hint, editable);
    return PressScale(
      scale: 0.98,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onMenu(TripPlanMenu.easy),
        child: Padding(
          padding: DS.insets(l: 12, t: 8),
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
              Gap.h(12),
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
                    Gap.v(6),
                    ClipRRect(
                      borderRadius: DS.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.percent.clamp(0, 100) / 100,
                        minHeight: DS.s(4),
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
              Gap.h(8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: DS.s(120)),
                child: _paceChip(context, c, editable),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideHeader(BuildContext context, TripPlanController c, TripPlan plan, TripGuideStep step) {
    final text = TripGuideHeaderText.of(plan, step.row);
    final shown = _shownHint(hintOf(c, c.easyRows));
    final editable = c.canEditStructure;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ListingTone.indigo.gradient,
        borderRadius: DS.br(CardRadius.header),
        boxShadow: DS.shadows(ShadowTokens.glow(KitTone.brand.glow)),
      ),
      padding: EdgeInsets.fromLTRB(_guideSide, MediaQuery.paddingOf(context).top + DS.s(8), _guideSide, DS.s(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _BackCircle(onTap: () => Get.back()),
              Gap.h(10),
              Expanded(child: _GuideTitle(title: text.title, subtitle: text.subtitle)),
              Gap.h(12),
              _MapAction(onTap: () => onMenu(TripPlanMenu.map)),
              Gap.h(12),
              _menu(c),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: DS.s(6), left: _circleRoom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (shown != null) Flexible(child: _statusPill(shown)),
                if (shown != null) Gap.h(8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: DS.s(120)),
                  child: _paceChip(context, c, editable),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _shownHint(String? hint) => hint == TripStringsV2Plan.hintMakeItEasy ? null : hint;

  Widget _statusPill(String text) => Container(
        key: const ValueKey('guide_status_pill'),
        padding: DS.sym(h: 11, v: 5),
        decoration: BoxDecoration(color: DesignColors.whiteSoft, borderRadius: DS.circular(16)),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textInverse),
        ),
      );

  Widget _guidedRow(
    BuildContext context,
    TripPlanController c,
    String? hint,
    bool editable,
  ) {
    final shown = _shownHint(hint);
    return Padding(
      padding: DS.insets(l: 12, t: 8),
      child: Row(
        children: [
          Expanded(
            child: shown == null
                ? const SizedBox.shrink()
                : Text(
                    shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(12, FontWeight.w500, color: DesignColors.whiteHigh),
                  ),
          ),
          Gap.h(8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: DS.s(120)),
            child: _paceChip(context, c, editable),
          ),
        ],
      ),
    );
  }

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
          constraints: BoxConstraints(minHeight: DS.s(36)),
          child: Container(
            alignment: Alignment.center,
            padding: DS.sym(h: 12, v: 6),
            decoration: BoxDecoration(
              color: DesignColors.whiteSoft,
              borderRadius: DS.br(CardRadius.pill),
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
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: DS.s(16),
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
      padding: EdgeInsets.zero,
      color: DesignColors.surface,
      elevation: DS.s(12),
      shadowColor: DesignColors.tint(DesignColors.shadowBase, Alpha.soft),
      shape: RoundedRectangleBorder(borderRadius: DS.circular(20)),
      offset: Offset(0, DS.s(56)),
      onSelected: onMenu,
      itemBuilder: (_) {
        final saved = c.trip.value != null;
        final editable = c.canEditStructure;
        final canSave = !c.isReadOnly && !c.needsUpdate.value;
        return [
          if (canSave)
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
          if (canSave)
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
      child: TripMenuDots.box(),
    );
  }

  static Widget _tile(Object icon, {bool danger = false}) => Container(
        width: DS.s(44),
        height: DS.s(44),
        decoration: BoxDecoration(
          color: danger ? TripLook.errorSurface : ListingTone.indigo.tint,
          borderRadius: DS.circular(12),
        ),
        child: Center(
          child: icon is String
              ? Art3D(asset: icon, size: 40, shadowBlur: 3, shadowOffset: const Offset(2, 3))
              : Icon(icon as IconData, size: DS.s(24), color: TripLook.error),
        ),
      );

  PopupMenuItem<TripPlanMenu> _item(
    TripPlanMenu value,
    Object icon,
    String label, {
    Color color = Ink3D.title,
  }) => PopupMenuItem(
    value: value,
    height: DS.s(62),
    child: Row(
      children: [
        _tile(icon, danger: icon is! String),
        Gap.h(14),
        Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, icon is String ? FontWeight.w500 : FontWeight.w600, color))),
      ],
    ),
  );

  PopupMenuItem<TripPlanMenu> _muteItem(TripPlanController c) {
    final muted = c.trip.value?.isMuted ?? false;
    return PopupMenuItem(
      value: TripPlanMenu.mute,
      height: DS.s(62),
      child: Row(
        children: [
          _tile(ListingArt.speechBalloon),
          Gap.h(14),
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

class TripFlowHeader extends StatelessWidget {
  const TripFlowHeader({super.key, required this.title, this.subtitle, this.onBack, this.trailing = const []});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    const white = DesignColors.surface;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ModuleHeader.lightIcons,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: ListingTone.indigo.gradient,
          borderRadius: DS.br(CardRadius.header),
          boxShadow: DS.shadows(TripLook.headerShadow),
        ),
        padding: EdgeInsets.fromLTRB(DS.s(14), MediaQuery.paddingOf(context).top, DS.s(14), DS.s(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(44)),
          child: Row(
            children: [
              if (onBack != null) ...[_BackCircle(onTap: onBack!), Gap.h(12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(20, FontWeight.w700, white, height: 1.25, letterSpacing: 0)),
                    if (sub != null && sub.isNotEmpty)
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, DesignColors.tint(white, Alpha.v93), letterSpacing: 0)),
                  ],
                ),
              ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class TripMenuDots {
  TripMenuDots._();

  static const Key boxKey = ValueKey('trip-menu-dots');

  static Widget box() => SizedBox(
        key: boxKey,
        width: DS.s(40),
        height: DS.s(40),
        child: Center(child: glyph(DesignColors.surface)),
      );

  static Widget glyph(Color color, {double size = 22}) => CustomPaint(size: Size(DS.s(size * 0.115), DS.s(size * 0.625)), painter: _DotsPainter(color));
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final pitch = (size.height - size.width) / 2;
    final paint = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(r, r + pitch * i), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: SizedBox(
        width: DS.s(KitMetrics.touch),
        height: DS.s(KitMetrics.touch),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: DesignColors.whiteSoft,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Center(
            child: Container(
              width: DS.s(44),
              height: DS.s(44),
              decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surface, Alpha.v22), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('‹', textScaler: TextScaler.noScaling, style: Ink3D.text(24, FontWeight.w400, DesignColors.textInverse, height: 1, letterSpacing: 0)),
            ),
          ),
        ),
      ),
    );
  }
}

// One line at 17, else two lines, else smaller; never an ellipsis.
class _GuideTitle extends StatelessWidget {
  const _GuideTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  static const List<double> _sizes = [17, 16, 15, 14, 13, 12, 11];

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(48)),
      child: LayoutBuilder(
        builder: (context, box) {
          TextStyle styleOf(double size) => TypeTokens.style(size, FontWeight.w700, color: DesignColors.textInverse, letterSpacing: 0.3);
          bool fits(double size, int lines) {
            final tp = TextPainter(text: TextSpan(text: title, style: styleOf(size).copyWith(height: 1.15)), textDirection: dir, textScaler: scaler, maxLines: lines)
              ..layout(maxWidth: box.maxWidth);
            return !tp.didExceedMaxLines;
          }

          var size = _sizes.last;
          var lines = 2;
          for (final s in _sizes) {
            if (fits(s, 1)) {
              size = s;
              lines = 1;
              break;
            }
            if (s <= 15 && fits(s, 2)) {
              size = s;
              break;
            }
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, key: const ValueKey('guide_title'), maxLines: lines, overflow: TextOverflow.clip, style: styleOf(size).copyWith(height: 1.15)),
              if (subtitle.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(subtitle, key: const ValueKey('guide_subtitle'), maxLines: 1, style: TypeTokens.style(11.5, FontWeight.w500, color: DesignColors.whiteHigh)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MapAction extends StatelessWidget {
  const _MapAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: TripStringsV2Plan.map,
      exclude: true,
      child: Container(
        height: DS.s(40),
        padding: DS.sym(h: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surface, Alpha.v25), borderRadius: DS.circular(20)),
        child: Text(TripStringsV2Plan.map, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, DesignColors.surface, letterSpacing: 0)),
      ),
    );
  }
}

class TripPlanStepCard extends StatelessWidget {
  static const Key cardKey = ValueKey('plan-top-card');
  static const Key nameKey = ValueKey('plan-top-name');

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
      final editable = c.canEditStructure;
      final pct = progress.percent.clamp(0, 100).toDouble();
      final name = c.title;
      final sub = step == 2 ? (progress.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsV2Plan.arranged(progress.done, progress.total)) : null;
      return Tap3D(
        onTap: () => onMenu(TripPlanMenu.easy),
        label: '${TripStringsDayplan.yourPlan}, $name',
        child: Padding(
          padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(36), DS.s(18), DS.gv(8)),
          child: Container(
            key: cardKey,
            padding: DS.insets(l: 20, t: 22, r: 20, b: 18),
            decoration: BoxDecoration(
              gradient: tone.gradient,
              borderRadius: DS.br(kMealsRadius),
              boxShadow: [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(TripStringsDayplan.yourPlan, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w600, DesignColors.tint(white, Alpha.v90))),
                      Text(name, key: nameKey, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(21, FontWeight.w700, white, height: 1.25)),
                      if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, DesignColors.tint(white, Alpha.v90))),
                      if (hint != null && step == 2)
                        Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, DesignColors.tint(white, Alpha.v90))),
                      Gap.v(14),
                      ClipRRect(
                        borderRadius: DS.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: DS.s(4),
                          color: white,
                          backgroundColor: DesignColors.tint(white, Alpha.scrim),
                        ),
                      ),
                      Gap.v(14),
                      _pace(context, c, editable, tone),
                    ],
                  ),
                ),
                SizedBox(width: DS.s(22)),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 600),
                  curve: Curves.fastOutSlowIn,
                  builder: (_, v, _) => RingBadge(progress: v / 100, fill: tone.g2, size: 58, labelSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _pace(BuildContext context, TripPlanController c, bool editable, ListingTone tone) {
    final label = TripStringsDayplan.pace(relaxed: c.settings.isRelaxed);
    const white = DesignColors.surface;
    return Tap3D(
      onTap: editable
          ? () async {
              final picked = await TripPaceSheet.show(context);
              if (picked != null) await c.setPace(picked);
            }
          : null,
      label: label,
      child: Container(
        height: DS.s(40),
        padding: DS.sym(h: 16),
        decoration: BoxDecoration(
          color: DesignColors.tint(white, Alpha.v22),
          borderRadius: DS.circular(20),
          border: Border.all(color: DesignColors.tint(white, Alpha.v55)),
        ),
        child: Center(widthFactor: 1, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, white, letterSpacing: 0))),
      ),
    );
  }
}
