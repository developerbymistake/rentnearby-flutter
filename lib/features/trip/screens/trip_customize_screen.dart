import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings_customize.dart';
import '../trip_strings_mca_a1.dart';
import '../trip_strings_pick_draft.dart';
import '../utils/trip_format.dart';
import '../utils/trip_leg_draft.dart';
import '../widgets/customize/trip_customize_board.dart';
import '../widgets/trip_update_ask_sheet.dart';

typedef TripDraftPicker = Future<List<TripSpotModel>?> Function(
  TripCityModel city, {
  required int legIndex,
  required int dayNumber,
  required int dayCount,
  required Set<String> existingIds,
});

typedef TripCustomizeToast = void Function(bool success, String message);

class TripCustomizeScreen extends StatefulWidget {
  const TripCustomizeScreen({super.key, this.legIndex, this.picker, this.toast});

  final int? legIndex;
  final TripDraftPicker? picker;
  final TripCustomizeToast? toast;

  @override
  State<TripCustomizeScreen> createState() => _TripCustomizeScreenState();
}

class _TripCustomizeScreenState extends State<TripCustomizeScreen> {
  static const double _maxWidth = 640;

  final TripPlanController _plan = TripPlanController.to;
  late final int _legIndex;
  late final TripLegDraft _draft;
  late final int _startDayCount;
  int? _errorDay;
  String? _blockedTitle;
  String? _blockedDetail;
  String? _doneText;
  int _version = 0;
  bool _missing = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final leg = widget.legIndex ?? (args is Map ? args['legIndex'] : null);
    final p = _plan.plan.value;
    if (leg is! int || p == null || (p.legs.isNotEmpty && p.legAt(leg) == null)) {
      _missing = true;
      _legIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Get.back();
        _say(false, TripStringsCustomize.missingCity);
      });
      return;
    }
    _legIndex = leg;
    _draft = TripLegDraft.from(
      p,
      _legIndex,
      frozenDays: _plan.legDays(_legIndex).where(_plan.isDayPast).length,
      otherLegsDayCount: p.days.length - p.legDayCount(_legIndex),
      otherLegsSpotCount: p.spotCount - p.legSpotCount(_legIndex),
    );
    _startDayCount = _draft.dayCount;
  }

  TripPlan get _current => _plan.plan.value!;

  TripCityLeg get _leg => _current.legAt(_legIndex) ?? _current.legOf(_draft.firstDayNumber);

  void _say(bool success, String message) {
    final sink = widget.toast;
    if (sink != null) return sink(success, message);
    success ? AppToast.success(message) : AppToast.warning(message);
  }

  void _touched() => setState(() {
        _errorDay = null;
        _version++;
      });

  void _clearBanners() {
    _blockedTitle = null;
    _blockedDetail = null;
    _doneText = null;
  }

  void _onChanged() {
    _clearBanners();
    _touched();
  }

  void _addDay() {
    if (_draft.addDay() == TripDraftBlock.tooManyDays) {
      _say(false, TripStringsCustomize.maxDays);
      return;
    }
    _onChanged();
  }

  void _deleteDay(int index) {
    final number = _draft.firstDayNumber + index;
    final before = _draft.dayCount;
    final block = _draft.deleteDay(index);
    _clearBanners();
    switch (block) {
      case TripDraftBlock.none:
        final r = _draft.deleteDayResult;
        _doneText = TripStringsCustomize.deletedDone(
          number,
          r?.moved ?? 0,
          [for (final i in r?.intoDays ?? const <int>[]) _draft.firstDayNumber + i],
        );
      case TripDraftBlock.placesDontFit:
        final left = before - 1;
        final frozenSpots = _draft.days.take(_draft.frozenDays).fold<int>(0, (n, d) => n + d.spots.length);
        final fit = (left - _draft.frozenDays) * TripConstants.maxSpotsPerDay + frozenSpots;
        _blockedTitle = TripStringsCustomize.blockedTitle(left);
        _blockedDetail = TripStringsCustomize.blockedDetail(_draft.spotCount, left, fit);
      default:
        break;
    }
    _touched();
  }

  Future<List<TripSpotModel>?> _openPicker(TripCityModel city, int dayNumber, int dayCount, Set<String> existing) async {
    final custom = widget.picker;
    if (custom != null) {
      return custom(city, legIndex: _legIndex, dayNumber: dayNumber, dayCount: dayCount, existingIds: existing);
    }
    // Untyped on purpose: GetMaterialApp builds named routes as GetPageRoute<dynamic>.
    final res = await Get.toNamed(
      AppRoutes.tripSpots,
      arguments: {
        'city': city,
        'pickForDraft': true,
        'legIndex': _legIndex,
        'dayNumber': dayNumber,
        'dayCount': dayCount,
        'existingIds': existing,
      },
    );
    return res is List ? res.whereType<TripSpotModel>().toList() : null;
  }

  Future<void> _addPlaces(int index) async {
    final leg = _leg;
    final city = TripCityModel(cityKey: leg.cityKey, name: leg.cityName, latitude: leg.latitude, longitude: leg.longitude);
    final number = _draft.firstDayNumber + index;
    final existing = {for (final d in _draft.days) ...d.spots.map((s) => s.id)};
    final picked = await _openPicker(city, number, _draft.days[index].spots.length, existing);
    if (!mounted || picked == null || picked.isEmpty) return;
    final block = _draft.addSpots(index, [for (final s in picked) TripSpotRef.fromSpot(s)]);
    if (block == TripDraftBlock.dayFull) _say(false, TripStringsPickDraft.dayFull(number));
    if (block == TripDraftBlock.tooManySpots) _say(false, TripStringsMcaA1.maxPlaces);
    _onChanged();
  }

  void _reset() {
    _draft.reset();
    _onChanged();
  }

  Future<void> _update() async {
    if (_closing || !_draft.changed) return;
    final result = _plan.applyLegDraft(_legIndex, _draft);
    switch (result) {
      case TripLegApplyBlock.none:
        _closing = true;
        final dayCountChanged = _draft.dayCount != _startDayCount;
        Get.back();
        _say(true, TripStringsCustomize.planUpdated);
        if (dayCountChanged) await TripUpdateAskSheet.afterDaysEdit();
      case TripLegApplyBlock.emptyDay:
        setState(() => _errorDay = _draft.firstEmptyDay);
      case TripLegApplyBlock.stale:
        _closing = true;
        Get.back();
        _say(false, TripStringsCustomize.planChanged);
      case TripLegApplyBlock.locked:
        _say(false, _plan.planLockMessage);
      case TripLegApplyBlock.readOnly:
        _say(false, TripStringsCustomize.readOnly);
      case TripLegApplyBlock.bookings:
        _say(false, TripStringsCustomize.bookingsFirst(_leg.cityName));
      case TripLegApplyBlock.running:
        _say(false, TripStringsCustomize.running);
      case TripLegApplyBlock.invalid:
        _say(false, TripStringsCustomize.cannotApply);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_draft.changed) return true;
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: ListingArt.clipboard,
        title: TripStringsCustomize.discardTitle,
        body: TripStringsCustomize.discardBody,
        tight: true,
        secondaryKey: const ValueKey('customize-keep-editing'),
        secondaryLabel: TripStringsCustomize.keepEditing,
        secondaryNeutral: true,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryKey: const ValueKey('customize-discard'),
        primaryLabel: TripStringsCustomize.discard,
        primaryDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    return ok == true;
  }

  Future<void> _back() async {
    if (await _confirmDiscard() && mounted) Get.back();
  }

  String _subtitle() {
    final start = _current.settings.dateOf(_draft.firstDayNumber);
    final end = _current.settings.dateOf(_draft.firstDayNumber + _draft.dayCount - 1);
    return TripStringsCustomize.summary(
      _draft.dayCount,
      _draft.spotCount,
      dates: start == null || end == null ? null : TripFormat.dayMonthRange(start, end),
    );
  }

  Widget _hint(String text) => Padding(
        padding: DS.insets(l: 4, t: 0, r: 4, b: 4),
        child: Text(text, style: Ink3D.text(13, FontWeight.w500, Ink3D.sub)),
      );

  Widget _banner(BannerKind kind, String title, {String? subtitle}) => Banner3D(
        kind: kind,
        title: title,
        subtitle: subtitle,
        compact: true,
        margin: EdgeInsets.only(bottom: DS.gv(10)),
      );

  Widget _addDayButton() {
    final can = _draft.canAddDay;
    return Tap3D(
      tapKey: const ValueKey('customize-add-day'),
      onTap: can ? _addDay : null,
      label: TripStringsCustomize.addDay,
      child: Opacity(
        opacity: can ? 1 : 0.5,
        child: Container(
          padding: DS.sym(h: 16, v: 12),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: DS.circular(20),
            border: Border.all(color: ListingTone.indigo.g2, width: DS.s(1.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: DS.s(20), color: ListingTone.indigo.text),
              Gap.h(8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(TripStringsCustomize.addDay, style: Ink3D.text(15, FontWeight.w700, ListingTone.indigo.text)),
                    Text(TripStringsCustomize.newDayEmpty, style: Ink3D.text(12, FontWeight.w500, Ink3D.sub)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final changed = _draft.changed;
    final canUpdate = changed && _errorDay == null;
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(10), DS.s(16), AppInsets.bottomViewPadding(context) + DS.s(10)),
      decoration: BoxDecoration(color: DesignColors.surface, boxShadow: DS.shadows(TripEntryStyle.topShadow)),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillButtonRow(
                children: [
                  WhitePillButton(
                    key: const ValueKey('customize-reset'),
                    tone: ListingTone.indigo,
                    label: TripStringsCustomize.reset,
                    neutral: true,
                    onTap: changed ? _reset : null,
                  ),
                  GradientPillButton(
                    key: const ValueKey('customize-update'),
                    tone: ListingTone.indigo,
                    label: TripStringsCustomize.update,
                    enabled: canUpdate,
                    onTap: canUpdate ? _update : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) return const Scaffold(backgroundColor: DesignColors.surface);
    return PopScope(
      canPop: !_draft.changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: DesignColors.surface,
        body: Column(
          children: [
            ModuleHeader(
              title: TripStringsCustomize.title(_leg.cityName),
              subtitle: _subtitle(),
              tone: KitTone.trip,
              onBack: _back,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: DS.sym(h: 16, v: 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hint(TripStringsCustomize.hintDrag),
                        _hint(TripStringsCustomize.hintCity),
                        Gap.v(8),
                        if (_blockedTitle != null)
                          _banner(BannerKind.warn, _blockedTitle!, subtitle: _blockedDetail),
                        if (_doneText != null) _banner(BannerKind.good, _doneText!),
                        TripCustomizeBoard(
                          key: ValueKey('customize-board-$_version'),
                          draft: _draft,
                          dayLimitMinutes: _plan.dayLimitMinutes,
                          firstDate: _current.settings.dateOf(_draft.firstDayNumber),
                          errorDay: _errorDay,
                          onChanged: _onChanged,
                          onAddPlaces: _addPlaces,
                          onDeleteDay: _deleteDay,
                        ),
                        Gap.v(12),
                        _addDayButton(),
                        Gap.v(16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }
}
