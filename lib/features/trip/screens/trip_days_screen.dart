import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_city_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings_v2_create.dart';
import '../utils/trip_days_rules.dart';
import '../widgets/trip_city_sheet.dart';

class TripDaysScreen extends StatefulWidget {
  const TripDaysScreen({super.key});

  @override
  State<TripDaysScreen> createState() => _TripDaysScreenState();
}

class _TripDaysScreenState extends State<TripDaysScreen> {
  late final List<TripCityModel> _cities;
  late List<TripDraftLeg> _draftLegs;
  late final TripCreateSession _session;
  late int _min;
  bool _opening = false;

  int get _days => _session.days.value;

  List<int> get _counts => [
        for (final c in _cities)
          _draftLegs.where((l) => l.city.cityKey == c.cityKey).fold<int>(0, (n, l) => n + l.ids.length),
      ];

  int get _bestFit => _cities.fold<int>(0, (n, c) => n + TripDaysRules.suggestedDays(c.spotCount));

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    final list = args['cities'];
    _cities = [if (list is List) ...list.whereType<TripCityModel>()];
    if (_cities.isEmpty && args['city'] is TripCityModel) _cities.add(args['city'] as TripCityModel);
    final legs = args['draftLegs'];
    _draftLegs = [if (legs is List) ...legs.whereType<TripDraftLeg>()];
    _min = _minNow();
    final wanted = (args['days'] as int?) ?? _bestFit;
    if (Get.isRegistered<TripCreateSession>()) Get.delete<TripCreateSession>(force: true);
    _session = Get.put(TripCreateSession(wanted.clamp(_min, TripConstants.maxDaysCap).toInt()));
  }

  @override
  void dispose() {
    if (Get.isRegistered<TripCreateSession>() && identical(Get.find<TripCreateSession>(), _session)) {
      Get.delete<TripCreateSession>(force: true);
    }
    super.dispose();
  }

  int _minNow() => TripDaysRules.minDays(_cities.length, _counts);

  void _set(int d) => _session.days.value = d.clamp(_min, TripConstants.maxDaysCap).toInt();

  Future<void> _choose() async {
    if (_opening || _cities.isEmpty) return;
    _opening = true;
    final legs = _draftLegs.isEmpty ? [for (final c in _cities) TripDraftLeg(c, const [])] : _draftLegs;
    TripNewDraft.save(legs, days: _days);
    await Get.toNamed(
      AppRoutes.tripSpots,
      arguments: {
        'city': _cities.first,
        if (_cities.length > 1) 'cities': _cities,
        if (_draftLegs.isNotEmpty) 'draftLegs': _draftLegs,
        'days': _days,
      },
    );
    _opening = false;
    if (!mounted) return;
    final saved = TripNewDraft.read();
    setState(() {
      _draftLegs = saved?.legs ?? const [];
      _min = _minNow();
      if (_days < _min) _session.days.value = _min;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
              children: [
                _stepperCard(),
                const SizedBox(height: 14),
                _bestFitCard(),
                const SizedBox(height: 16),
                _note(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: GradientButton(
          label: TripStringsV2Create.choosePlaces,
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _cities.isEmpty ? null : _choose,
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  TripStringsV2Create.daysTitle,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  TripStringsV2Create.daysSubtitle([for (final c in _cities) c.name]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperCard() {
    return Obx(() {
      final d = _days;
      return Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: TripColors.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: TripColors.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Iconsax.calendar_1, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(TripStringsV2Create.daysHeading,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          const Text(TripStringsV2Create.daysDescription,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepButton(Icons.remove_rounded, d > _min ? () => _set(d - 1) : null),
              Container(
                constraints: const BoxConstraints(minWidth: 110),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text('$d',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 54, height: 1.05, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    Text(d == 1 ? 'day' : 'days',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                  ],
                ),
              ),
              _stepButton(Icons.add_rounded, d < TripConstants.maxDaysCap ? () => _set(d + 1) : null, filled: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(TripStringsV2Create.limitHint(d),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          if (d <= _min && _min > 1) ...[
            const SizedBox(height: 4),
            Text(
              _counts.any((n) => n > 0) ? TripStringsV2Create.lessDaysBlocked : TripStringsV2Create.minDaysNote(_min),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
            ),
          ] else if (d >= TripConstants.maxDaysCap) ...[
            const SizedBox(height: 4),
            const Text(TripStringsV2Create.maxDaysNote,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
          ],
        ],
      );
    });
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap, {bool filled = false}) {
    final on = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? (filled ? TripColors.accent : Colors.white) : AppColors.neutralChip,
          border: Border.all(color: on ? TripColors.accent : AppColors.divider, width: 1.2),
        ),
        child: Icon(icon, size: 24, color: on ? (filled ? Colors.white : TripColors.accentDark) : AppColors.textHint),
      ),
    );
  }

  Widget _bestFitCard() {
    final best = _bestFit.clamp(_min, TripConstants.maxDaysCap).toInt();
    return Column(
      children: [
        Obx(() => InkWell(
              onTap: _days == best ? null : () => _set(best),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(TripStringsV2Create.bestFitPill(best),
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
              ),
            )),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final c in _cities)
              Container(
                constraints: const BoxConstraints(minWidth: 140),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    Text(TripStringsV2Create.suggested(TripDaysRules.suggestedDays(c.spotCount)),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _note() => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Iconsax.info_circle, size: 15, color: AppColors.textLight),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(TripStringsV2Create.noDatesNote,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ),
        ],
      );
}
