import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'trip_update_ask_sheet.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import '../trip_strings_v2_plan.dart';
import 'trip_leg_menu_sheet.dart';

class TripDaysSheet extends StatefulWidget {
  const TripDaysSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final r = await SheetFrame.show<bool>(context, builder: (_) => const TripDaysSheet());
    return r == true;
  }

  @override
  State<TripDaysSheet> createState() => _TripDaysSheetState();
}

class _TripDaysSheetState extends State<TripDaysSheet> {
  final _c = TripPlanController.to;
  late final TripPlan _plan;
  late final List<int> _current;
  late final List<int> _min;
  late List<int> _alloc;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _plan = _c.plan.value!;
    final n = _plan.legCount;
    _current = [for (var k = 1; k <= n; k++) _plan.legDayCount(k)];
    _alloc = [..._current];
    _min = [
      for (var k = 1; k <= n; k++)
        _larger(_c.minDaysForLeg(k), _larger(1, (_plan.legSpotCount(k) / TripConstants.maxSpotsPerDay).ceil())),
    ];
  }

  static int _larger(int a, int b) => a > b ? a : b;

  int get _total => _alloc.fold(0, (a, b) => a + b);

  int get _minTotal => _min.fold(0, (a, b) => a + b);

  bool get _changed {
    for (var i = 0; i < _alloc.length; i++) {
      if (_alloc[i] != _current[i]) return true;
    }
    return false;
  }

  bool _canGrow(int i) =>
      _total < TripConstants.maxDaysCap && (_alloc[i] < _current[i] || !_c.growthBlockedByBookings(i + 1));

  void _step(int delta) {
    if (_alloc.length == 1) {
      final next = _alloc[0] + delta;
      if (next < _min[0] || next > TripConstants.maxDaysCap) return;
      setState(() => _alloc[0] = next);
      return;
    }
    var at = -1;
    var best = delta > 0 ? -1.0 : double.infinity;
    for (var i = 0; i < _alloc.length; i++) {
      if (delta > 0 ? !_canGrow(i) : _alloc[i] <= _min[i]) continue;
      final load = _plan.legSpotCount(i + 1) / _alloc[i];
      if (delta > 0 ? load > best : load < best) {
        best = load;
        at = i;
      }
    }
    if (at < 0) return;
    setState(() => _alloc[at] += delta);
  }

  void _stepCity(int i, int delta) {
    final next = _alloc[i] + delta;
    if (next < _min[i] || (delta > 0 && !_canGrow(i))) return;
    setState(() => _alloc[i] = next);
  }

  Future<void> _apply() async {
    if (_busy || !_changed) return;
    setState(() => _busy = true);
    final order = [
      for (var i = 0; i < _alloc.length; i++)
        if (_alloc[i] < _current[i]) i,
      for (var i = 0; i < _alloc.length; i++)
        if (_alloc[i] > _current[i]) i,
    ];
    for (final i in order) {
      final k = i + 1;
      final block = _c.canSetLegDays(k, _alloc[i], keepBookings: true);
      final ok = block == TripLegEditBlock.none && await _c.setLegDays(k, _alloc[i], keepBookings: true);
      if (!ok) {
        final text = TripLegMenuSheet.blockText(block, _plan.legAt(k)?.cityName ?? '');
        AppToast.warning(text ?? TripStringsV2Plan.daysBookings);
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    if (mounted) Navigator.pop(context, true);
    TripUpdateAskSheet.afterDaysEdit();
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    return SheetFrame(
      title: TripStringsV2Plan.daysTitle,
      subtitle: TripStringsV2Plan.daysSub,
      footer: PrimaryButton(
        label: TripStringsV2Plan.apply,
        tone: KitTone.trip,
        loading: _busy,
        onPressed: _changed && !_busy ? _apply : null,
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _btn(Icons.remove_rounded, total > _minTotal ? () => _step(-1) : null),
            SizedBox(
              width: 120,
              child: Text(
                TripStringsV2Plan.days(total),
                textAlign: TextAlign.center,
                style: TypeTokens.style(24, FontWeight.w700, color: KitTone.trip.accentDark, letterSpacing: 0.2),
              ),
            ),
            _btn(Icons.add_rounded, total < TripConstants.maxDaysCap ? () => _step(1) : null),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          TripStringsV2Plan.daysHint(total),
          textAlign: TextAlign.center,
          style: TypeTokens.style(12, FontWeight.w400, color: TypeTokens.secondary),
        ),
        if (_alloc.length > 1) ...[
          const SizedBox(height: 14),
          for (var i = 0; i < _alloc.length; i++) ...[
            _cityRow(i),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 4),
        Text(
          total <= _minTotal ? TripStringsV2Plan.daysMinHint(_minTotal) : TripStringsV2Plan.daysLocked,
          textAlign: TextAlign.center,
          style: TypeTokens.style(11, FontWeight.w400, color: TypeTokens.secondary),
        ),
      ],
      ),
    );
  }

  Widget _cityRow(int i) {
    final name = _plan.legAt(i + 1)?.cityName ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.elev2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeTokens.style(14, FontWeight.w600, color: DesignColors.textStrong),
            ),
          ),
          _btn(Icons.remove_rounded, _alloc[i] > _min[i] ? () => _stepCity(i, -1) : null),
          SizedBox(
            width: 64,
            child: Text(
              TripStringsV2Plan.days(_alloc[i]),
              textAlign: TextAlign.center,
              style: TypeTokens.style(14, FontWeight.w700, color: KitTone.trip.accentDark),
            ),
          ),
          _btn(Icons.add_rounded, _canGrow(i) ? () => _stepCity(i, 1) : null),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => TemplateRoundButton(icon: icon, size: 44, onTap: onTap);
}
