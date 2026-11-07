import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_shadows.dart';
import '../../../utils/contact_launcher.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcd_a2.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_format.dart';
import 'trip_day_chips.dart';
import 'trip_map_travel_block.dart';
import 'trip_route_strip.dart';
import 'trip_today_card.dart';

enum _PageKind { all, city, day }

class _MapPage {
  final _PageKind kind;
  final int value;

  const _MapPage.all()
      : kind = _PageKind.all,
        value = TripDayChips.all;

  const _MapPage.city(this.value) : kind = _PageKind.city;

  const _MapPage.day(this.value) : kind = _PageKind.day;

  String get key => '${kind.index}:$value';
}

class TripMapDayCard extends StatefulWidget {
  final int dayCount;
  final int selected;
  final ValueChanged<int> onDaySelected;
  final int selectedLeg;
  final ValueChanged<int>? onLegSelected;

  const TripMapDayCard({
    super.key,
    required this.dayCount,
    required this.selected,
    required this.onDaySelected,
    this.selectedLeg = 0,
    this.onLegSelected,
  });

  @override
  State<TripMapDayCard> createState() => _TripMapDayCardState();
}

class _TripMapDayCardState extends State<TripMapDayCard> {
  static const double _fallbackHeight = 120;
  static const _anim = Duration(milliseconds: 220);

  late PageController _pages;
  late int _current;
  final _heights = <int, double>{};
  int _programmatic = 0;
  bool _measured = false;
  List<_MapPage> _list = const [];
  String _listKey = '';

  List<_MapPage> _buildPages() {
    final p = TripPlanController.to.plan.value;
    if (p != null && p.isMultiCity) {
      return [
        const _MapPage.all(),
        for (final l in p.legs)
          if (p.legStart(l.index) >= 1) ...[
            if (!p.isSingleDayLeg(l.index)) _MapPage.city(l.index),
            for (final d in p.daysOf(l.index)) _MapPage.day(d.day),
          ],
      ];
    }
    final hasAll = widget.dayCount > 1;
    return [
      if (hasAll) const _MapPage.all(),
      for (var d = 1; d <= max(1, widget.dayCount); d++) _MapPage.day(d),
    ];
  }

  bool _refreshPages() {
    final next = _buildPages();
    final key = next.map((e) => e.key).join('|');
    if (key == _listKey) return false;
    _list = next;
    _listKey = key;
    return true;
  }

  int get _pageCount => max(1, _list.length);

  int _indexWhere(bool Function(_MapPage) test) {
    final i = _list.indexWhere(test);
    return i < 0 ? 0 : i;
  }

  int _pageOf(int day, int leg) {
    if (leg > 0) {
      final i = _list.indexWhere((e) => e.kind == _PageKind.city && e.value == leg);
      if (i >= 0) return i;
    }
    if (day == TripDayChips.all) return _indexWhere((e) => e.kind == _PageKind.all);
    final i = _list.indexWhere((e) => e.kind == _PageKind.day && e.value == day);
    return i >= 0 ? i : _pageCount - 1;
  }

  _MapPage _at(int page) => page >= 0 && page < _list.length ? _list[page] : const _MapPage.day(1);

  @override
  void initState() {
    super.initState();
    _refreshPages();
    _current = _pageOf(widget.selected, widget.selectedLeg);
    _pages = PageController(initialPage: _current);
  }

  @override
  void didUpdateWidget(TripMapDayCard old) {
    super.didUpdateWidget(old);
    final changed = _refreshPages() || old.dayCount != widget.dayCount;
    if (changed) _heights.clear();
    final target = _pageOf(widget.selected, widget.selectedLeg);
    if (target == _current && !changed) return;
    _current = target;
    WidgetsBinding.instance.addPostFrameCallback((_) => _moveTo(target));
  }

  Future<void> _moveTo(int target) async {
    if (!mounted || !_pages.hasClients) return;
    final at = _pages.page?.round() ?? target;
    if (at == target) return;
    _programmatic++;
    try {
      if ((at - target).abs() > 1) {
        _pages.jumpToPage(target);
      } else {
        await _pages.animateToPage(target, duration: _anim, curve: Curves.easeOut);
      }
    } finally {
      _programmatic--;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    if (_programmatic > 0) return;
    setState(() => _current = page);
    final target = _at(page);
    if (target.kind == _PageKind.city) {
      if (target.value != widget.selectedLeg) widget.onLegSelected?.call(target.value);
      return;
    }
    if (target.value != widget.selected || widget.selectedLeg > 0) widget.onDaySelected(target.value);
  }

  void _onMeasured(int page, double height) {
    if (!mounted || _heights[page] == height) return;
    setState(() {
      _heights[page] = height;
      if (page == _current) _measured = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final showDots = _pageCount > 1;
    final maxContent = max(80.0, screenH * 0.45 - 24 - (showDots ? 18 : 0));
    final height = min(_heights[_current] ?? _fallbackHeight, maxContent);
    final c = TripPlanController.to;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, AppInsets.bottomViewPadding(context) + 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.16, blur: 18, offset: const Offset(0, 6)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: _measured ? _anim : Duration.zero,
                    curve: Curves.easeOut,
                    height: height,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _pageCount,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (_, page) => SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _MeasureSize(
                          onChange: (s) => _onMeasured(page, s.height),
                          child: _pageBody(c, _at(page)),
                        ),
                      ),
                    ),
                  ),
                  if (showDots) _dots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 10,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _pageCount; i++)
                AnimatedContainer(
                  duration: _anim,
                  width: i == _current ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: i == _current ? TripColors.accent : AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dayLine(TripPlanController c, int day, int spots) {
    if (spots == 0) return TripStrings.freeDay;
    if (spots == 1) return '${TripStrings.oneStop} · ${TripFormat.duration(c.dayTotalMinutes(day))}';
    return TripRouteStrip.routeLine(c, day);
  }

  Widget _titleRow(String title, Color color, String line) {
    return Row(
      children: [
        Text(
          title,
          maxLines: 1,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          ),
        ),
      ],
    );
  }

  Widget _pageBody(TripPlanController c, _MapPage page) => switch (page.kind) {
        _PageKind.all => _allPage(c),
        _PageKind.city => _cityPage(c, page.value),
        _PageKind.day => _dayPage(c, page.value),
      };

  Widget _cityPage(TripPlanController c, int k) {
    return Obx(() {
      c.result.value;
      c.trip.value;
      final p = c.plan.value;
      final leg = p?.legAt(k);
      if (p == null || leg == null) return const SizedBox.shrink();
      final range = TripStringsMcaA3.dayRange(p.legStart(k), p.legEnd(k));
      final headline = leg.arrival == null ? null : c.travelHeadline(k);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Iconsax.location, size: 15, color: TripColors.accentDark),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  leg.cityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                range,
                maxLines: 1,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${TripFormat.km(c.cityKm(k))} · ${TripFormat.duration(c.cityMinutes(k))}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
          if (headline != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Iconsax.car, size: 13, color: TaxiColors.accentDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            TripStringsMcdA2.tapCityHint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
          ),
        ],
      );
    });
  }

  Widget _dayPage(TripPlanController c, int day) {
    return Obx(() {
      c.result.value;
      c.enquiryList.length;
      c.trip.value;
      final d = c.plan.value?.dayAt(day);
      if (d == null) return const SizedBox.shrink();
      final date = c.dateOf(day);
      final travel = c.isMultiCity && c.isTravelDay(day);
      final city = c.isMultiCity && !travel ? c.cityNameOf(day) : null;
      final freeTravel = travel && d.spots.isEmpty;
      final line = [
        if (travel && !freeTravel) TripStringsMcaA3.travelDay,
        ?city,
        if (date != null) TripFormat.shortDate(date),
      ].join(' · ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _titleRow(
            'Day $day',
            TripColors.dayColor(day),
            freeTravel ? TripStringsMcaA3.travelDay : _dayLine(c, day, d.spots.length),
          ),
          if (line.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(city != null ? Iconsax.location : Iconsax.calendar_1, size: 13, color: AppColors.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                  ),
                ),
              ],
            ),
          ],
          if (travel) ...[
            const SizedBox(height: 10),
            TripMapTravelBlock(legIndex: c.legIndexOf(day)),
          ],
          ..._contactRows(c, day),
        ],
      );
    });
  }

  static String? _phone(String? raw) => raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;

  List<Widget> _contactRows(TripPlanController c, int day) {
    final rows = <Widget>[];
    final stay = c.primaryEnquiry(day);
    if (stay != null && stay.isBooked) {
      final phone = TripTodayCard.stayPhone(stay);
      if (phone != null) {
        rows.add(_contactRow(
          icon: Iconsax.building_4,
          accent: StayColors.accent,
          text: stay.listingName.isEmpty ? TripStrings.stay : stay.listingName,
          action: TripStringsA4.callHost,
          phone: phone,
        ));
      }
    }
    final taxi = c.primaryTaxiEnquiry(day);
    if (taxi != null && taxi.isBooked) {
      final pickup = taxi.taxi?.pickupTime;
      final text = [
        if (pickup != null && pickup.isNotEmpty) TripStrings.pickupAt(TripFormat.time12(pickup)),
        taxi.isConfirmedByBoth ? TripStringsV2Plan.confirmedShort : TripStringsV2Plan.bookedByYouDriver,
      ].join(' · ');
      rows.add(_contactRow(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        text: text,
        action: TripStringsA4.callDriver,
        phone: _phone(taxi.owner.phone),
      ));
    }
    return [
      for (final r in rows) ...[const SizedBox(height: 8), r],
    ];
  }

  Widget _contactRow({
    required IconData icon,
    required Color accent,
    required String text,
    required String action,
    required String? phone,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
        ),
        if (phone != null)
          TextButton.icon(
            onPressed: () => ContactLauncher.call(phone),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 10)),
            icon: Icon(Iconsax.call, size: 16, color: accent),
            label: Text(
              action,
              maxLines: 1,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
      ],
    );
  }

  Widget _allPage(TripPlanController c) {
    return Obx(() {
      c.result.value;
      final p = c.plan.value;
      if (p == null) return const SizedBox.shrink();
      var km = 0.0;
      var minutes = 0;
      for (final d in p.days) {
        km += c.dayKm(d.day);
        minutes += c.dayTotalMinutes(d.day);
      }
      final hasStayPin = c.enquiryList.any((e) => !e.isTaxi && e.isConfirmedByBoth && e.listingLatitude != null);
      if (p.isMultiCity) return _allCitiesPage(c, hasStayPin);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _titleRow('${p.days.length} days', AppColors.textDark, '${TripFormat.km(km)} · ${TripFormat.duration(minutes)}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final d in p.days) _legendDay(d.day),
              if (hasStayPin) _legendStay(),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            TripStrings.tapDayChip,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
          ),
        ],
      );
    });
  }

  Widget _allCitiesPage(TripPlanController c, bool hasStayPin) {
    final p = c.plan.value!;
    final legs = [for (final l in p.legs) if (p.legStart(l.index) >= 1) l];
    var km = 0.0;
    for (final l in legs) {
      km += c.cityKm(l.index);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TripStringsMcdA2.daysCities(p.days.length, legs.length),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        const SizedBox(height: 2),
        Text(
          TripStringsMcdA2.inCitiesLine(TripFormat.km(km), c.travelDays),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final l in legs) _legendDot(TripColors.dayColor(p.legStart(l.index)), l.cityName),
            _legendTravel(),
            if (hasStayPin) _legendStay(),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          TripStringsMcdA2.tapCityHint,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendTravel() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 4,
            height: 3,
            decoration: BoxDecoration(color: TaxiColors.accent, borderRadius: BorderRadius.circular(1)),
          ),
        ],
        const SizedBox(width: 5),
        const Text(
          TripStringsMcdA2.travelLegend,
          maxLines: 1,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ),
      ],
    );
  }

  Widget _legendDay(int day) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: TripColors.dayColor(day), shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          'Day $day',
          maxLines: 1,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ),
      ],
    );
  }

  Widget _legendStay() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(color: StayColors.accent, shape: BoxShape.circle),
          child: const Icon(Iconsax.building_4, size: 9, color: Colors.white),
        ),
        const SizedBox(width: 5),
        const Text(
          TripStrings.stay,
          maxLines: 1,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ),
      ],
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.onChange, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasureSize renderObject) => renderObject.onChange = onChange;
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final s = size;
    if (s == _last) return;
    _last = s;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(s));
  }
}
