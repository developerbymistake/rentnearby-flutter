import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_insets.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_model.dart';
import '../trip_strings_mca_a1.dart';
import '../trip_strings_overview.dart';
import '../utils/trip_parts.dart';
import '../../buddy/sharing/widgets/owner_overview_seam.dart';
import '../widgets/trip_hero_card.dart';
import '../widgets/trip_overview_progress.dart';
import '../widgets/trip_plan_header.dart';

enum TripOverviewTaxiState { optional, requested, booked, completed }

// Contract section 4: the Taxi card follows taxiRequest.view; no request or an unknown view is Optional.
class TripOverviewTaxi {
  const TripOverviewTaxi._(this.state, this.chip, this.button);

  final TripOverviewTaxiState state;
  final String chip;
  final String button;

  bool get hasRequest => state != TripOverviewTaxiState.optional;

  static const TripOverviewTaxi _optional =
      TripOverviewTaxi._(TripOverviewTaxiState.optional, TripStringsOverview.optional, TripStringsOverview.requestTaxi);
  static const TripOverviewTaxi _requested =
      TripOverviewTaxi._(TripOverviewTaxiState.requested, TripStringsOverview.requested, TripStringsOverview.viewRequest);
  static const TripOverviewTaxi _booked =
      TripOverviewTaxi._(TripOverviewTaxiState.booked, TripStringsOverview.booked, TripStringsOverview.viewBooking);
  static const TripOverviewTaxi _completed =
      TripOverviewTaxi._(TripOverviewTaxiState.completed, TripStringsOverview.completed, TripStringsOverview.viewBooking);

  static TripOverviewTaxi of(TripTaxiRequestRef? ref, {bool canRate = false}) => canRate && ref?.view == 'Ended' ? _completed : switch (ref?.view) {
        'Finding' || 'FindingWaiting' || 'NoReply' || 'Collecting' || 'Selected' => _requested,
        'Booked' || 'InProgress' => _booked,
        'Rate' || 'Done' => _completed,
        _ => _optional,
      };
}

enum TripOverviewStayState { notAdded, requested, booked }

class TripOverviewStay {
  const TripOverviewStay._(this.state, this.chip, this.button, [this.line = TripStringsOverview.stayLine]);

  final TripOverviewStayState state;
  final String chip;
  final String button;
  final String line;

  bool get added => state != TripOverviewStayState.notAdded;

  static const TripOverviewStay notAdded =
      TripOverviewStay._(TripOverviewStayState.notAdded, TripStringsOverview.optional, TripStringsOverview.addStay);
  static const TripOverviewStay requested =
      TripOverviewStay._(TripOverviewStayState.requested, TripStringsOverview.added, TripStringsOverview.viewStays);
  static const TripOverviewStay booked =
      TripOverviewStay._(TripOverviewStayState.booked, TripStringsOverview.booked, TripStringsOverview.viewStays);

  // [cityOf] names the city of an enquiry; the line names it only when every asked stay is in one city.
  static TripOverviewStay of(Iterable<TripEnquiryModel> enquiries, {String? Function(TripEnquiryModel e)? cityOf}) {
    final stays = [for (final e in enquiries) if (!e.isTaxi && (e.isOpen || e.isConfirmed || e.isBooked)) e];
    if (stays.isEmpty) return notAdded;
    final base = stays.any((e) => e.isBooked || e.isConfirmed) ? booked : requested;
    final cities = cityOf == null ? const <String?>{} : {for (final e in stays) cityOf(e)};
    final city = cities.length == 1 ? cities.first : null;
    final n = {for (final e in stays) e.listingId}.length;
    return TripOverviewStay._(base.state, base.chip, base.button, TripStringsOverview.staysAsked(n, city));
  }
}

class TripOverviewScreen extends StatelessWidget {
  const TripOverviewScreen({
    super.key,
    required this.trip,
    required this.onViewPlan,
    required this.onTaxi,
    required this.onDone,
    this.paused = false,
    this.taxiCanRate = false,
    this.onBack,
    this.stay = TripOverviewStay.notAdded,
    this.onStay,
    this.showStay = true,
    this.parts = TripParts.saved,
    this.highlight,
    this.subtitle,
    this.travellerCount,
    this.extraCards = const [],
    this.extraMenuItems = const [],
    this.compactCards = false,
    this.progressLine,
    this.showProgress = true,
  });

  final String? subtitle;
  final int? travellerCount;
  final List<Widget> extraCards;
  final List<OverviewMenuItem> extraMenuItems;
  final bool compactCards;
  final String? progressLine;
  final bool showProgress;
  final TripModel trip;
  final bool taxiCanRate;
  final bool paused;
  final VoidCallback onViewPlan;
  final void Function(TripOverviewTaxi taxi) onTaxi;
  final VoidCallback onDone;
  final VoidCallback? onBack;
  final TripOverviewStay stay;
  final void Function(TripOverviewStay stay)? onStay;
  final bool showStay;
  final TripParts parts;
  final TripPart? highlight;

  static const double _maxWidth = 640;

  static TripPart? highlightOf(TripParts parts, {required bool showStay}) {
    final next = parts.next;
    if (next == TripPart.stay && !showStay) return parts.taxi == TripPartState.open ? TripPart.taxi : null;
    return next;
  }

  // Same rule as TripPlanController.title: an unchosen stored default follows the current cities.
  static String displayTitle(TripModel trip) {
    final fallback = TripStringsMcaA1.defaultTitle(trip.plan.legCities);
    final t = trip.title;
    if (t.isEmpty) return fallback;
    if (trip.nameChosen) return t;
    final storedDefault = t == fallback || t == TripStringsMcaA1.defaultTitle([trip.cityName]);
    return storedDefault ? fallback : t;
  }

  Widget _menu() => PopupMenuButton<int>(
        key: const ValueKey('overview_menu'),
        tooltip: TripStringsOverview.moreOptions,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: DS.circular(12)),
        color: DesignColors.surface,
        onSelected: (i) => i == 0 ? onViewPlan() : extraMenuItems[i - 1].onTap(),
        itemBuilder: (_) => [
          PopupMenuItem<int>(
            value: 0,
            child: Text(TripStringsOverview.viewPlan, style: Ink3D.text(13, FontWeight.w600, Ink3D.title)),
          ),
          for (var i = 0; i < extraMenuItems.length; i++)
            PopupMenuItem<int>(
              key: ValueKey('overview_menu_extra_$i'),
              value: i + 1,
              child: Text(extraMenuItems[i].label, style: Ink3D.text(13, FontWeight.w600, extraMenuItems[i].danger ? DesignColors.error : Ink3D.title)),
            ),
        ],
        child: TripMenuDots.box(),
      );

  @override
  Widget build(BuildContext context) {
    final taxi = TripOverviewTaxi.of(trip.taxiRequest, canRate: taxiCanRate);
    // Paused blocks only a new request; an existing request or booking can still be opened.
    final taxiBlocked = paused && !taxi.hasRequest;
    final indigo = ListingTone.indigo;
    final gap = compactCards ? 12.0 : 16.0;
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: _OverviewHeader(
              onBack: onBack ?? () => Navigator.maybePop(context),
              menu: _menu(),
              subtitle: subtitle,
              bottom: _TripLine(trip: trip, travellerCount: travellerCount),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: Padding(
                        padding: DS.insets(l: 18, t: 20, r: 18, b: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                      if (showProgress) ...[
                        TripOverviewProgress(parts: parts, line: progressLine),
                        Gap.v(gap),
                      ],
                      TripHeroCard(
                        key: const ValueKey('overview_itinerary_card'),
                        tone: indigo,
                        asset: TravelIcon.route,
                        title: TripStringsOverview.itinerary,
                        chip: TripStringsOverview.saved,
                        line: TripStringsOverview.planLine(trip.dayCount, trip.spotCount),
                        button: TripStringsOverview.view,
                        buttonKey: const ValueKey('overview_itinerary_button'),
                        onTap: onViewPlan,
                        compact: compactCards,
                      ),
                      Gap.v(gap),
                      Opacity(
                        opacity: taxiBlocked ? 0.5 : 1,
                        child: TripHeroCard(
                          key: const ValueKey('overview_taxi_card'),
                          tone: ListingTone.sunrise,
                          asset: TravelIcon.taxi,
                          title: TripStringsOverview.taxi,
                          chip: taxi.chip,
                          line: TripStringsOverview.taxiLine,
                          button: taxi.button,
                          buttonKey: const ValueKey('overview_taxi_button'),
                          highlight: highlight == TripPart.taxi && !taxiBlocked,
                          onTap: taxiBlocked ? null : () => onTaxi(taxi),
                          compact: compactCards,
                        ),
                      ),
                      if (paused) ...[
                        Gap.v(10),
                        Text(
                          TripStringsOverview.paused,
                          key: const ValueKey('overview_paused_line'),
                          textAlign: TextAlign.center,
                          style: Ink3D.text(13, FontWeight.w600, Ink3D.sub),
                        ),
                      ],
                      if (showStay) ...[
                        Gap.v(gap),
                        TripHeroCard(
                          key: const ValueKey('overview_stay_card'),
                          tone: ListingTone.forest,
                          asset: TravelIcon.stay,
                          title: TripStringsOverview.stay,
                          chip: stay.chip,
                          line: stay.line,
                          button: stay.button,
                          buttonKey: const ValueKey('overview_stay_button'),
                          highlight: highlight == TripPart.stay,
                          onTap: onStay == null ? null : () => onStay!(stay),
                          compact: compactCards,
                        ),
                      ],
                      for (final card in extraCards) ...[Gap.v(gap), card],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Follows the card: Busy and Ended read Request taxi again, so the label stays Skip.
          _BottomBar(
            label: taxi.hasRequest || (showStay && stay.added) ? TripStringsOverview.backToTrips : TripStringsOverview.skip,
            tone: indigo,
            onTap: onDone,
          ),
        ],
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.onBack, required this.menu, required this.bottom, this.subtitle});

  final String? subtitle;
  final VoidCallback onBack;
  final Widget menu;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(44)),
              child: Row(
                children: [
                  Tap3D(
                    tapKey: const ValueKey('overview_back'),
                    onTap: onBack,
                    label: TripStringsOverview.back,
                    child: Container(
                      width: DS.s(44),
                      height: DS.s(44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: DesignColors.tint(white, Alpha.v22), shape: BoxShape.circle),
                      child: Text('‹', textScaler: TextScaler.noScaling, style: Ink3D.text(24, FontWeight.w400, white, height: 1, letterSpacing: 0)),
                    ),
                  ),
                  Gap.h(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(TripStringsOverview.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(20, FontWeight.w700, white, height: 1.25, letterSpacing: 0)),
                        Text(subtitle ?? TripStringsOverview.subtitle, key: const ValueKey('overview_subtitle'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, DesignColors.tint(white, Alpha.v93), letterSpacing: 0)),
                      ],
                    ),
                  ),
                  menu,
                ],
              ),
            ),
            bottom,
          ],
        ),
      ),
    );
  }
}

class _TripLine extends StatelessWidget {
  const _TripLine({required this.trip, this.travellerCount});

  final TripModel trip;
  final int? travellerCount;

  @override
  Widget build(BuildContext context) {
    final line = TripStringsOverview.tripLine(trip.legCount, trip.dayCount, travellerCount ?? trip.plan.settings.peopleCount);
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(16)),
      child: Container(
        padding: DS.sym(h: 16, v: 14),
        decoration: BoxDecoration(
          gradient: TripCustomizeLook.tripCardGradient,
          border: Border.all(color: TripCustomizeLook.tripCardBorder, width: DS.s(1)),
          borderRadius: DS.br(TripCustomizeLook.tripLineRadius),
          boxShadow: DS.shadows(TripCustomizeLook.tripCardShadow),
        ),
        child: Row(
          children: [
            SizedBox(
              width: DS.s(narrow ? 52 : 72),
              height: DS.s(narrow ? 52 : 72),
              child: Center(
                child: Art3D(
                  asset: ListingArt.luggage,
                  size: narrow ? 38 : 50,
                  halo: narrow ? 52 : 72,
                  haloColor: DesignColors.surface,
                  shadowBlur: 4,
                  shadowOffset: const Offset(2, 3),
                ),
              ),
            ),
            Gap.h(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TripOverviewScreen.displayTitle(trip),
                    key: const ValueKey('overview_trip_name'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(17, FontWeight.w700, TripCustomizeLook.tripCardName),
                  ),
                  Text(
                    line,
                    key: const ValueKey('overview_trip_line'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12.5, FontWeight.w400, TripCustomizeLook.tripCardSub, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.label, required this.tone, required this.onTap});

  final String label;
  final ListingTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(TripCustomizeLook.barRadius),
        boxShadow: DS.shadows(TripLook.barShadowUp),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), AppInsets.bottomViewPadding(context) + DS.s(16)),
        child: WhitePillButton(key: const ValueKey('overview_done_button'), tone: tone, label: label, onTap: onTap),
      ),
    );
  }
}
