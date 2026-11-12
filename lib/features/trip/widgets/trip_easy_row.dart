import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'trip_ui.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_plan_guide.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_easy_rules.dart';
import 'trip_arrange_confirm.dart';

class TripEasyStatePill extends StatelessWidget {
  const TripEasyStatePill(this.state, {super.key});

  final TripRowState state;

  static String label(TripRowState s) => switch (s) {
        TripRowState.todo => TripStringsV2Easy.pillTodo,
        TripRowState.asked => TripStringsV2Easy.pillAsked,
        TripRowState.offer => TripStringsV2Easy.pillOffer,
        TripRowState.confirmed => TripStringsV2Easy.pillConfirmed,
        TripRowState.booked => TripStringsV2Easy.pillBooked,
        TripRowState.own => TripStringsV2Easy.pillOwn,
        TripRowState.saved => TripStringsV2Easy.pillSaved,
        TripRowState.skipped => TripStringsV2Easy.pillSkipped,
        TripRowState.attention => TripStringsV2Easy.pillAttention,
      };

  static (Color, Color) colors(TripRowState s) => switch (s) {
        TripRowState.todo || TripRowState.skipped => (TripLook.neutralChip, TripLook.neutralChipText),
        TripRowState.asked || TripRowState.offer => (TripLook.warningSurface, TripLook.warningText),
        TripRowState.confirmed || TripRowState.booked || TripRowState.own || TripRowState.saved => (TripLook.successSurface, TripLook.successText),
        TripRowState.attention => (TripLook.errorSurface, TripLook.errorText),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label(state),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class TripEasyRow extends StatefulWidget {
  const TripEasyRow(this.info, {super.key});

  final TripEasyRowInfo info;

  static IconData iconOf(TripEasyRowKind k) => switch (k) {
        TripEasyRowKind.gettingThere => Icons.alt_route,
        TripEasyRowKind.comingBack => Icons.alt_route,
        TripEasyRowKind.between => Icons.chevron_right,
        TripEasyRowKind.stay => Icons.home_outlined,
        TripEasyRowKind.taxi => Icons.directions_car,
      };

  static String ownLine(TripEasyRowKey key) => switch (key.kind) {
        TripEasyRowKind.stay => TripStringsV2Easy.youArrangeStay,
        TripEasyRowKind.taxi => TripStringsV2Easy.youArrangeTaxi,
        TripEasyRowKind.between => TripStringsV2Easy.youArrangeIt,
        _ => TripStringsV2Easy.youArrangeTravel,
      };

  @override
  State<TripEasyRow> createState() => _TripEasyRowState();
}

class _TripEasyRowState extends State<TripEasyRow> {
  List<dynamic> _withdraw = const [];
  bool _blocked = false;
  bool _busy = false;

  TripEasyRowInfo get _i => widget.info;

  TripPlanController get _c => TripPlanController.to;

  bool get _clickable =>
      _i.state == TripRowState.asked ||
      _i.state == TripRowState.offer ||
      _i.state == TripRowState.confirmed ||
      _i.state == TripRowState.booked ||
      _i.state == TripRowState.saved;

  Future<void> _arrange() async {
    final ok = await TripArrangeConfirm.show(context, _i.key);
    if (!ok || !mounted) return;
    await _mark(false);
  }

  void _skip() {
    if (_c.openRowsOf(_i.key).isNotEmpty || _c.confirmedRowOf(_i.key) != null) {
      setState(() {
        _withdraw = const [];
        _blocked = true;
      });
      return;
    }
    _c.skipRow(_i.key);
  }

  Widget _titleTap(Widget title) {
    if (!_c.guideState.overview.value || !_c.guideAvailable) return title;
    return GestureDetector(
      key: ValueKey('overview-title-${_i.key.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _c.guideJumpTo(_i.key.id, persist: true),
      child: title,
    );
  }

  Widget _kindIcon(TripEasyRowKind k) => switch (k) {
        TripEasyRowKind.gettingThere || TripEasyRowKind.comingBack => const TravelIcon(TravelIcon.route, size: 22),
        TripEasyRowKind.stay => const TravelIcon(TravelIcon.stay, size: 22),
        TripEasyRowKind.taxi => const TravelIcon(TravelIcon.taxi, size: 22),
        TripEasyRowKind.between => Icon(TripEasyRow.iconOf(k), size: 18, color: TripLook.accentDark),
      };

  Widget _menu() => SizedBox(
        width: 32,
        height: 32,
        child: PopupMenuButton<int>(
          padding: EdgeInsets.zero,
          tooltip: TripStringsV2Easy.more,
          icon: const Icon(Icons.more_vert, size: 18, color: TripLook.textMedium),
          onSelected: (_) => _arrange(),
          itemBuilder: (_) => const [
            PopupMenuItem<int>(
              value: 0,
              child: Text(TripStringsV2Easy.arrangeMyself,
                  style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Future<void> _mark(bool withdraw) async {
    setState(() => _busy = true);
    final r = await _c.markOwn(_i.key, withdrawOpen: withdraw);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _withdraw = r is TripMarkNeedsWithdraw ? r.open : const [];
      _blocked = r is TripMarkBlocked;
    });
  }

  void _clearNotice() => setState(() {
        _withdraw = const [];
        _blocked = false;
      });

  int get _supplyDay {
    final p = _c.plan.value;
    final k = _i.key.legIndex;
    return _i.key.kind == TripEasyRowKind.stay && p != null && k != null ? p.legStart(k) : 1;
  }

  bool get _loadFailed =>
      (_i.key.kind == TripEasyRowKind.stay || _i.key.kind == TripEasyRowKind.taxi) &&
      _i.state == TripRowState.todo &&
      _c.supplyCheckFailedFor(_supplyDay);

  String get _blockedText => switch (_i.key.kind) {
        TripEasyRowKind.stay => TripStringsV2Easy.cancelConfirmedStay,
        TripEasyRowKind.taxi => TripStringsV2Easy.cancelConfirmedTaxi,
        _ => TripStringsV2Easy.cancelConfirmedTravel,
      };

  Widget _text(String t, {Color color = TripLook.textLight, double size = 12, FontWeight? w}) => Text(
        t,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: size, color: color, fontWeight: w, height: 1.3),
      );

  Widget _link(String label, VoidCallback? onTap, {Color color = DesignColors.lunchEnd}) =>
      TextLink(label: label, onTap: _busy ? null : onTap, tone: TripUi.toneOf(color));

  Widget _actions() {
    if (_c.isReadOnly) return const SizedBox.shrink();
    switch (_i.state) {
      case TripRowState.todo || TripRowState.attention:
        if (_loadFailed) return const SizedBox.shrink();
        final noSupply = _noSupply;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!noSupply) ...[
              PrimaryButton(
                label: TripStringsV2Easy.helpMeFind,
                height: 44,
                tone: KitTone.trip,
                onPressed: _busy ? null : () => TripNavigation.helpMeFind(context, _i.key),
              ),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(
                child: noSupply
                    ? PrimaryButton(
                        label: TripStringsV2Easy.arrangeMyself, height: 44, tone: KitTone.trip, onPressed: _busy ? null : _arrange)
                    : SecondaryButton(
                        label: TripStringsV2Easy.arrangeMyself, height: 44, tone: KitTone.trip, onPressed: _busy ? null : _arrange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                    label: TripStringsV2Easy.skip, height: 44, tone: KitTone.trip, neutral: true, onPressed: _busy ? null : _skip),
              ),
            ]),
          ],
        );
      case TripRowState.own || TripRowState.skipped:
        return const SizedBox.shrink();
      case TripRowState.asked || TripRowState.offer || TripRowState.confirmed || TripRowState.booked || TripRowState.saved:
        return const SizedBox.shrink();
    }
  }

  String get _shownTitle {
    final p = _c.plan.value;
    if (p == null) return _i.title;
    switch (_i.key.kind) {
      case TripEasyRowKind.taxi:
        final names = [for (final l in p.legs) l.cityName].where((n) => n.isNotEmpty).toSet().toList();
        if (names.isEmpty) return TripStringsV2Easy.localTaxiIn(p.cityName);
        final shown = names.length <= 2 ? names.join(' & ') : '${names.take(2).join(', ')} +${names.length - 2}';
        return TripStringsV2Easy.localTaxiIn(shown);
      case TripEasyRowKind.stay:
        return TripStringsV2Easy.localStayIn(p.legAt(_i.key.legIndex ?? 1)?.cityName ?? p.cityName);
      default:
        return _i.title;
    }
  }

  bool get _noSupply {
    final p = _c.plan.value;
    if (p == null || _c.isReadOnly || _i.state != TripRowState.todo || _loadFailed) return false;
    switch (_i.key.kind) {
      case TripEasyRowKind.stay:
        return _c.stayTabOff.value;
      case TripEasyRowKind.taxi:
        return _c.taxiTabOff.value;
      default:
        return false;
    }
  }

  bool get _offlineTodo =>
      !_c.isReadOnly &&
      _c.netOff &&
      _i.state == TripRowState.todo &&
      (_i.key.kind == TripEasyRowKind.stay || _i.key.kind == TripEasyRowKind.taxi) &&
      !_loadFailed &&
      !_noSupply;

  String get _offlineLine =>
      _i.key.kind == TripEasyRowKind.taxi ? TripStringsV2Easy.connectDrivers : TripStringsV2Easy.connectHosts;

  Widget _pill() {
    if (_loadFailed && !_c.isReadOnly) {
      return GestureDetector(
        onTap: _busy ? null : () => _c.retrySupply(_supplyDay),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: TripLook.errorSurface, borderRadius: BorderRadius.circular(20)),
            child: const Text(TripStringsV2Easy.retry,
                style: TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, fontWeight: FontWeight.w700, color: TripLook.errorText)),
          ),
        ),
      );
    }
    if (_noSupply) return const SizedBox.shrink();
    if (_offlineTodo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: TripLook.neutralChip, borderRadius: BorderRadius.circular(20)),
        child: const Text(TripStringsV2Easy.pillOffline,
            style: TextStyle(
                fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w600, color: TripLook.neutralChipText)),
      );
    }
    return TripEasyStatePill(_i.state);
  }

  Widget _notice() {
    if (_blocked) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: _text(_blockedText, color: TripLook.errorText, w: FontWeight.w600)),
          _link(TripStringsV2Easy.cancel, _clearNotice, color: TripLook.textMedium),
        ]),
      );
    }
    if (_withdraw.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: _text(TripStringsV2Easy.withdrawLine(_withdraw.length), color: TripLook.textDark, w: FontWeight.w600)),
          _link(TripStringsV2Easy.keepAsks, _clearNotice, color: TripLook.textMedium),
          _link(TripStringsV2Easy.withdraw, () => _mark(true), color: TripLook.errorText),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        _c.netOff;
        return EntranceOnce(child: _card(context));
      });

  Widget _card(BuildContext context) {
    final i = _i;
    final noSupply = _noSupply;
    final failed = _loadFailed && !_c.isReadOnly;
    final subtitle = failed
        ? TripStringsV2Easy.couldNotLoad
        : (noSupply
            ? (i.kind == TripEasyRowKind.taxi ? TripStringsV2Easy.ownTravelHint : TripStringsV2Easy.ownStayHint)
            : (_offlineTodo ? _offlineLine : i.subtitle));
    final red = i.state == TripRowState.attention || failed;
    final own = i.state == TripRowState.own;
    final title = own
        ? TripEasyRow.ownLine(i.key)
        : (noSupply
            ? (i.kind == TripEasyRowKind.taxi ? TripStringsV2Easy.noTaxiHere : TripStringsV2Easy.noStayHere)
            : _shownTitle);
    final muted = i.state == TripRowState.skipped;
    final subtitleColor = muted
        ? DesignColors.textMuted
        : red
        ? TripLook.errorText
        : (i.state == TripRowState.asked || i.state == TripRowState.offer ? TripLook.warningText : TripLook.textLight);
    return Semantics(
      container: true,
      label: '${i.title}. ${TripEasyStatePill.label(i.state)}. ${i.subtitle}',
      child: TripSurface(
        onTap: _clickable ? () => TripNavigation.openRepliesForRow(i.key) : null,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        borderColor: red ? DesignColors.tint(TripLook.error, Alpha.half) : null,
        child: AnimatedSize(
          duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          alignment: Alignment.topCenter,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: own ? TripLook.successSurface : TripLook.surface, borderRadius: BorderRadius.circular(10)),
                      child: own
                          ? Icon(Icons.check_circle_rounded, size: 20, color: TripLook.success)
                          : _kindIcon(i.kind)
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _titleTap(
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w600, color: muted ? DesignColors.textMuted : TripLook.textDark)),
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (i.state == TripRowState.asked || i.state == TripRowState.offer) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(color: TripLook.warning, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(child: _text(subtitle, color: subtitleColor)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (own)
                      if (_c.isReadOnly) const SizedBox.shrink() else _link(TripStringsV2Easy.undo, () => _c.undoMark(i.key))
                    else if (i.state == TripRowState.skipped && !_c.isReadOnly)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _pill(),
                        _link(TripStringsV2Easy.change, () => _c.unskipRow(i.key)),
                      ])
                    else if (_i.state == TripRowState.asked || _i.state == TripRowState.offer)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Padding(padding: const EdgeInsets.only(top: 2), child: _pill()),
                        if (!_c.isReadOnly) ...[const SizedBox(width: 2), _menu()],
                      ])
                    else
                      Padding(padding: const EdgeInsets.only(top: 2), child: _pill()),
                  ],
                ),
                if (_clickable && !_c.isReadOnly)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _link(TripStringsV2Easy.replies, () => TripNavigation.openRepliesForRow(i.key)),
                  ),
                if (i.kind == TripEasyRowKind.stay && i.partial && !_c.isReadOnly && i.legIndex != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _link(
                      i.uncoveredDays.length == 1
                          ? TripStringsV2Easy.askLastNight
                          : TripStringsV2Easy.askMoreNights(i.uncoveredDays.length),
                      () => TripNavigation.openStay(i.legIndex!, onlyDays: i.uncoveredDays),
                    ),
                  ),
                if (!_clickable) ...[const SizedBox(height: 8), _actions()],
                _notice(),
                const SizedBox(height: 4),
              ],
            ),
        ),
      ),
    );
  }
}
