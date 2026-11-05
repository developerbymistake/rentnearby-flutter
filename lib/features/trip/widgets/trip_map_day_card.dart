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
import '../utils/trip_format.dart';
import 'trip_day_actions.dart';
import 'trip_day_chips.dart';
import 'trip_route_strip.dart';
import 'trip_today_card.dart';

class TripMapDayCard extends StatefulWidget {
  final int dayCount;
  final int selected;
  final ValueChanged<int> onDaySelected;

  const TripMapDayCard({
    super.key,
    required this.dayCount,
    required this.selected,
    required this.onDaySelected,
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

  bool get _hasAll => widget.dayCount > 1;

  int get _pageCount => max(1, widget.dayCount + (_hasAll ? 1 : 0));

  int _pageOf(int day) {
    final page = day == TripDayChips.all ? 0 : (_hasAll ? day : day - 1);
    return page.clamp(0, _pageCount - 1);
  }

  int _dayOf(int page) => _hasAll ? (page == 0 ? TripDayChips.all : page) : page + 1;

  @override
  void initState() {
    super.initState();
    _current = _pageOf(widget.selected);
    _pages = PageController(initialPage: _current);
  }

  @override
  void didUpdateWidget(TripMapDayCard old) {
    super.didUpdateWidget(old);
    if (old.dayCount != widget.dayCount) _heights.clear();
    final target = _pageOf(widget.selected);
    if (target == _current && old.dayCount == widget.dayCount) return;
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
    final day = _dayOf(page);
    if (day != widget.selected) widget.onDaySelected(day);
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
                          child: _dayOf(page) == TripDayChips.all ? _allPage(c) : _dayPage(c, _dayOf(page)),
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

  Widget _dayPage(TripPlanController c, int day) {
    return Obx(() {
      c.result.value;
      c.enquiryList.length;
      final d = c.plan.value?.dayAt(day);
      if (d == null) return const SizedBox.shrink();
      final date = c.dateOf(day);
      final city = c.isMultiCity ? c.cityNameOf(day) : null;
      final line = [?city, if (date != null) TripFormat.shortDate(date)].join(' · ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _titleRow('Day $day', TripColors.dayColor(day), _dayLine(c, day, d.spots.length)),
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
          const SizedBox(height: 12),
          TripDayActions(day),
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
    } else {
      final own = c.ownStayOf(day);
      final phone = _phone(own?.ownPhone);
      if (own != null && phone != null) {
        rows.add(_contactRow(
          icon: Iconsax.building_4,
          accent: StayColors.accent,
          text: own.name,
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
        taxi.isConfirmedByBoth ? TripStrings.bothConfirmedShort : TripStrings.bookedByYouShort,
      ].join(' · ');
      rows.add(_contactRow(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        text: text,
        action: TripStringsA4.callDriver,
        phone: _phone(taxi.owner.phone),
      ));
    } else {
      final own = c.ownTaxiOf(day);
      if (own != null) {
        final pickup = own.booking?.pickupTime;
        rows.add(_contactRow(
          icon: Iconsax.car,
          accent: TaxiColors.accent,
          text: [
            if (pickup != null && pickup.isNotEmpty) TripStrings.pickupAt(TripFormat.time12(pickup)),
            TripStrings.ownBookingShort,
          ].join(' · '),
          action: TripStringsA4.callDriver,
          phone: _phone(own.ownPhone),
        ));
      }
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
      final hasStayPin = p.days.any((d) {
        final s = d.stay;
        return s != null && !s.isSameStay && s.hasCoordinates;
      });
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
