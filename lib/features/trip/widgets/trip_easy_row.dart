import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
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
        TripRowState.todo || TripRowState.skipped => (AppColors.neutralChip, AppColors.neutralChipText),
        TripRowState.asked || TripRowState.offer => (AppColors.warningSurface, AppColors.warningText),
        TripRowState.confirmed || TripRowState.booked || TripRowState.own || TripRowState.saved => (AppColors.successSurface, AppColors.successText),
        TripRowState.attention => (AppColors.errorSurface, AppColors.errorText),
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
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class TripEasyRow extends StatefulWidget {
  const TripEasyRow(this.info, {super.key});

  final TripEasyRowInfo info;

  static IconData iconOf(TripEasyRowKind k) => switch (k) {
        TripEasyRowKind.gettingThere => Iconsax.routing_2,
        TripEasyRowKind.comingBack => Iconsax.routing_2,
        TripEasyRowKind.between => Iconsax.arrow_right_3,
        TripEasyRowKind.stay => Iconsax.house_2,
        TripEasyRowKind.taxi => Iconsax.car,
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

  Widget _menu() => SizedBox(
        width: 20,
        height: 20,
        child: PopupMenuButton<int>(
          padding: EdgeInsets.zero,
          tooltip: TripStringsV2Easy.more,
          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMedium),
          onSelected: (_) => _arrange(),
          itemBuilder: (_) => const [
            PopupMenuItem<int>(
              value: 0,
              child: Text(TripStringsV2Easy.arrangeMyself,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _text(String t, {Color color = AppColors.textLight, double size = 12, FontWeight? w}) => Text(
        t,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Poppins', fontSize: size, color: color, fontWeight: w, height: 1.3),
      );

  Widget _link(String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) => TextButton(
        onPressed: _busy ? null : onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

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
              SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: _busy ? null : () => TripNavigation.helpMeFind(context, _i.key),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TripColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(TripStringsV2Easy.helpMeFind,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
              const SizedBox(height: 8),
            ],
            Row(children: [
            Expanded(child: SizedBox(
              height: 38,
              child: noSupply
                  ? ElevatedButton(
                      onPressed: _busy ? null : _arrange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TripColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(TripStringsV2Easy.arrangeMyself,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
                    )
                  : OutlinedButton(
                      onPressed: _busy ? null : _arrange,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TripColors.accentDark,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(TripStringsV2Easy.arrangeMyself,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
            )),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(
              height: 38,
              child: OutlinedButton(
                onPressed: _busy ? null : _skip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(TripStringsV2Easy.skip,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            )),
            ]),
          ],
        );
      case TripRowState.own:
        return const SizedBox.shrink();
      case TripRowState.skipped:
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
            decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(20)),
            child: const Text(TripStringsV2Easy.retry,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.errorText)),
          ),
        ),
      );
    }
    if (_noSupply) return const SizedBox.shrink();
    if (_offlineTodo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(20)),
        child: const Text(TripStringsV2Easy.pillOffline,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.neutralChipText)),
      );
    }
    return TripEasyStatePill(_i.state);
  }

  Widget _notice() {
    if (_blocked) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: _text(_blockedText, color: AppColors.errorText, w: FontWeight.w600)),
          _link(TripStringsV2Easy.cancel, _clearNotice, color: AppColors.textMedium),
        ]),
      );
    }
    if (_withdraw.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: _text(TripStringsV2Easy.withdrawLine(_withdraw.length), color: AppColors.textDark, w: FontWeight.w600)),
          _link(TripStringsV2Easy.keepAsks, _clearNotice, color: AppColors.textMedium),
          _link(TripStringsV2Easy.withdraw, () => _mark(true), color: AppColors.errorText),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        _c.netOff;
        return _card(context);
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
    final subtitleColor = red
        ? AppColors.errorText
        : (i.state == TripRowState.asked || i.state == TripRowState.offer ? AppColors.warningText : AppColors.textLight);
    return Semantics(
      container: true,
      label: '${i.title}. ${TripEasyStatePill.label(i.state)}. ${i.subtitle}',
      child: GestureDetector(
        onTap: _clickable ? () => TripNavigation.openRepliesForRow(i.key) : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: red ? AppColors.error.withValues(alpha: 0.5) : AppColors.divider),
          ),
          child: Opacity(
            opacity: muted ? 0.6 : 1,
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
                          color: own ? AppColors.successSurface : TripColors.surface, borderRadius: BorderRadius.circular(10)),
                      child: own
                          ? const Icon(Iconsax.tick_circle5, size: 18, color: AppColors.success)
                          : Icon(TripEasyRow.iconOf(i.kind), size: 18, color: TripColors.accentDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (i.state == TripRowState.asked || i.state == TripRowState.offer) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
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
      ),
    );
  }
}
