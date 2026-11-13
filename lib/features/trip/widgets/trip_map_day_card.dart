import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../utils/contact_launcher.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcd_a2.dart';
import '../trip_strings_v2_easy.dart';
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
        await _pages.animateToPage(target, duration: _anim, curve: Curves.fastOutSlowIn);
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
    final m = _ArtMetrics.of(MediaQuery.sizeOf(context).width);
    final showDots = _pageCount > 1;
    final maxContent = max(80.0, screenH * 0.45 - 24 - (showDots ? 18 : 0));
    final height = min(_heights[_current] ?? _fallbackHeight, maxContent);
    final c = TripPlanController.to;
    final art = _artOf(c, _at(_current));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, AppInsets.bottomViewPadding(context) + 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(top: m.overhang),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: ListingTone.indigo.gradient,
                    borderRadius: kMealsRadius,
                    boxShadow: [BoxShadow(color: ListingTone.indigo.shadow, offset: const Offset(1.1, 6), blurRadius: 14)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: _measured ? _anim : Duration.zero,
                          curve: Curves.fastOutSlowIn,
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
                                child: _pageBody(c, _at(page), m),
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
              Positioned(
                left: m.artLeft - 2,
                top: 6,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.tint(DesignColors.surface, Alpha.v24)),
                    child: SizedBox(width: m.halo, height: m.halo),
                  ),
                ),
              ),
              Positioned(
                left: m.artLeft,
                top: 0,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: _anim,
                    child: Art3D(key: ValueKey(art), asset: art, size: m.art),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _artOf(TripPlanController c, _MapPage page) => switch (page.kind) {
        _PageKind.all => ListingArt.worldMap,
        _PageKind.city => ListingArt.roundPushpin,
        _PageKind.day => c.isMultiCity && c.isTravelDay(page.value) ? ListingArt.bus : ListingArt.sunrise,
      };

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
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
                    color: i == _current ? DesignColors.surface : DesignColors.tint(DesignColors.surface, Alpha.v40),
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

  static const _eyebrowStyle = TextStyle(
      fontFamily: FitnessAppTheme.fontName, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, height: 1.3, color: DesignColors.whiteHigh);
  static const _lineStyle = TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.45, color: DesignColors.textInverse);

  Widget _head(_ArtMetrics m, {required String eyebrow, required String title, required List<String> lines}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: m.headMin),
      child: Padding(
        padding: EdgeInsets.only(left: m.textLeft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eyebrow.isNotEmpty) Text(eyebrow.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: _eyebrowStyle),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: m.title, fontWeight: FontWeight.w700, height: 1.25, color: DesignColors.textInverse),
            ),
            for (final l in lines)
              if (l.isNotEmpty) Text(l, maxLines: 3, overflow: TextOverflow.ellipsis, style: _lineStyle),
          ],
        ),
      ),
    );
  }

  Widget _pageBody(TripPlanController c, _MapPage page, _ArtMetrics m) => switch (page.kind) {
        _PageKind.all => _allPage(c, m),
        _PageKind.city => _cityPage(c, page.value, m),
        _PageKind.day => _dayPage(c, page.value, m),
      };

  Widget _cityPage(TripPlanController c, int k, _ArtMetrics m) {
    return Obx(() {
      c.result.value;
      c.trip.value;
      final p = c.plan.value;
      final leg = p?.legAt(k);
      if (p == null || leg == null) return const SizedBox.shrink();
      final headline = leg.arrival == null ? null : c.travelHeadline(k);
      return _head(
        m,
        eyebrow: TripStringsMcaA3.dayRange(p.legStart(k), p.legEnd(k)),
        title: leg.cityName,
        lines: [
          '${TripFormat.km(c.cityKm(k))} · ${TripFormat.duration(c.cityMinutes(k))}',
          ?headline,
          TripStringsMcdA2.tapCityHint,
        ],
      );
    });
  }

  Widget _dayPage(TripPlanController c, int day, _ArtMetrics m) {
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
      final eyebrow = [
        if (travel) TripStringsMcaA3.travelDay,
        ?city,
        if (date != null) TripFormat.shortDate(date),
      ].join(' · ');
      final b = _bookings(c, day);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _head(
            m,
            eyebrow: eyebrow,
            title: 'Day $day',
            lines: [
              if (!freeTravel) _dayLine(c, day, d.spots.length),
              if (b.line.isNotEmpty) b.line,
            ],
          ),
          if (travel) ...[
            const SizedBox(height: 10),
            TripMapTravelBlock(legIndex: c.legIndexOf(day)),
          ],
          _PillRow(pills: [
            _Pill(lead: _dot(TripKit.dayColor(day)), label: 'Day $day'),
            ...b.pills,
          ]),
        ],
      );
    });
  }

  static String? _phone(String? raw) => raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;

  ({String line, List<_Pill> pills}) _bookings(TripPlanController c, int day) {
    final parts = <String>[];
    final pills = <_Pill>[];
    final stay = c.primaryEnquiry(day);
    if (stay != null && stay.isBooked) {
      parts.add(stay.listingName.isEmpty ? TripStrings.stay : stay.listingName);
      final phone = TripTodayCard.stayPhone(stay);
      if (phone != null) {
        pills.add(_Pill(lead: _icon('house_with_garden'), label: TripStringsA4.callHost, onTap: () => ContactLauncher.call(phone)));
      }
    }
    final taxi = c.primaryTaxiEnquiry(day);
    if (taxi != null && taxi.isBooked) {
      final pickup = taxi.taxi?.pickupTime;
      if (pickup != null && pickup.isNotEmpty) parts.add(TripStrings.pickupAt(TripFormat.time12(pickup)));
      parts.add(taxi.isConfirmedByBoth ? TripStringsV2Plan.confirmedShort : TripStringsV2Plan.bookedByYouDriver);
      final phone = _phone(taxi.owner.phone);
      if (phone != null) {
        pills.add(_Pill(lead: _icon('taxi'), label: TripStringsA4.callDriver, onTap: () => ContactLauncher.call(phone)));
      }
    }
    return (line: parts.join(' · '), pills: pills);
  }

  static Widget _icon(String name) => Image.asset('assets/images/design/travel3d/$name.png', width: 16, height: 16);

  static Widget _dot(Color color) => Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      );

  static Widget _dash() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(width: 5, height: 3, decoration: BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(1))),
          ],
        ],
      );

  static Widget _stayLead() => Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(color: DesignColors.statusAttention, shape: BoxShape.circle),
        child: const TravelIcon(TravelIcon.stay, size: 9),
      );

  Widget _allPage(TripPlanController c, _ArtMetrics m) {
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
      if (p.isMultiCity) return _allCitiesPage(c, hasStayPin, m);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _head(
            m,
            eyebrow: TripStringsV2Easy.wholeTrip,
            title: '${p.days.length} days',
            lines: ['${TripFormat.km(km)} · ${TripFormat.duration(minutes)}', TripStrings.tapDayChip],
          ),
          _PillRow(pills: [
            for (final d in p.days) _Pill(lead: _dot(TripKit.dayColor(d.day)), label: 'Day ${d.day}'),
            if (hasStayPin) _Pill(lead: _stayLead(), label: TripStrings.stay),
          ]),
        ],
      );
    });
  }

  Widget _allCitiesPage(TripPlanController c, bool hasStayPin, _ArtMetrics m) {
    final p = c.plan.value!;
    final legs = [for (final l in p.legs) if (p.legStart(l.index) >= 1) l];
    var km = 0.0;
    for (final l in legs) {
      km += c.cityKm(l.index);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _head(
          m,
          eyebrow: TripStringsV2Easy.wholeTrip,
          title: TripStringsMcdA2.daysCities(p.days.length, legs.length),
          lines: [TripStringsMcdA2.inCitiesLine(TripFormat.km(km), c.travelDays), TripStringsMcdA2.tapCityHint],
        ),
        _PillRow(pills: [
          for (final l in legs) _Pill(lead: _dot(TripKit.dayColor(p.legStart(l.index))), label: l.cityName),
          _Pill(lead: _dash(), label: TripStringsMcdA2.travelLegend),
          if (hasStayPin) _Pill(lead: _stayLead(), label: TripStrings.stay),
        ]),
      ],
    );
  }
}

class _ArtMetrics {
  const _ArtMetrics(this.art, this.halo, this.overhang, this.title);

  final double art;
  final double halo;
  final double overhang;
  final double title;

  double get artLeft => 6;
  double get textLeft => art - 6;
  double get headMin => art - overhang - 12;

  static _ArtMetrics of(double width) => width < 340 ? const _ArtMetrics(84, 88, 30, 18) : const _ArtMetrics(104, 108, 40, 20);
}

class _Pill {
  const _Pill({required this.lead, required this.label, this.onTap});

  final Widget lead;
  final String label;
  final VoidCallback? onTap;
}

class _PillRow extends StatelessWidget {
  const _PillRow({required this.pills});

  final List<_Pill> pills;

  static const _style = TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, fontWeight: FontWeight.w700, color: DesignColors.textInverse);
  static const double _gap = 8;
  static const double _pad = 12;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final n = pills.length;
        const slots = 3;
        final cell = (w - _gap * (slots - 1)) / slots;
        final even = n <= slots && pills.every((p) => KitText.widthOf(p.label, _style, scaler) + 16 + 6 + _pad * 2 <= cell);
        if (even) {
          return Row(
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(width: cell, child: _pill(pills[i], center: true)),
              ],
            ],
          );
        }
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final p in pills) ConstrainedBox(constraints: BoxConstraints(maxWidth: w), child: _pill(p, center: false)),
          ],
        );
      }),
    );
  }

  Widget _pill(_Pill p, {required bool center}) {
    final body = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 6),
      decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surface, Alpha.v26), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: center ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          p.lead,
          const SizedBox(width: 6),
          Flexible(child: Text(p.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: _style)),
        ],
      ),
    );
    if (p.onTap == null) return body;
    return Semantics(
      button: true,
      label: p.label,
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: p.onTap, child: body),
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
