import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/trip_model.dart';
import '../trip_strings_mca_a1.dart';
import '../trip_strings_overview.dart';

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
  });

  final TripModel trip;
  final bool taxiCanRate;
  final bool paused;
  final VoidCallback onViewPlan;
  final void Function(TripOverviewTaxi taxi) onTaxi;
  final VoidCallback onDone;
  final VoidCallback? onBack;

  static const double _maxWidth = 640;

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
        onSelected: (_) => onViewPlan(),
        itemBuilder: (_) => [
          PopupMenuItem<int>(
            value: 0,
            child: Text(TripStringsOverview.viewPlan, style: Ink3D.text(13, FontWeight.w600, Ink3D.title)),
          ),
        ],
        child: SizedBox(
          width: DS.s(40),
          height: DS.s(40),
          child: Icon(Icons.more_vert_rounded, size: DS.s(24), color: DesignColors.surface),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final taxi = TripOverviewTaxi.of(trip.taxiRequest, canRate: taxiCanRate);
    // Paused blocks only a new request; an existing request or booking can still be opened.
    final taxiBlocked = paused && !taxi.hasRequest;
    final indigo = ListingTone.indigo;
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ModuleHeader(
              title: TripStringsOverview.title,
              subtitle: TripStringsOverview.subtitle,
              subtitleWidget: Text(TripStringsOverview.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TripCustomizeLook.headerSubtitle),
              autoHeight: true,
              tone: KitTone.brand,
              gradient: indigo.gradient,
              onBack: onBack ?? () => Get.back(),
              titleStyle: TripCustomizeLook.headerTitle,
              trailing: [_menu()],
              bottom: _TripLine(trip: trip),
            ),
          ),
          Flexible(
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
                      _HeroCard(
                        key: const ValueKey('overview_itinerary_card'),
                        tone: indigo,
                        asset: TravelIcon.route,
                        title: TripStringsOverview.itinerary,
                        chip: TripStringsOverview.saved,
                        line: TripStringsOverview.planLine(trip.dayCount, trip.spotCount),
                        button: TripStringsOverview.view,
                        buttonKey: const ValueKey('overview_itinerary_button'),
                        onTap: onViewPlan,
                      ),
                      Gap.v(16),
                      Opacity(
                        opacity: taxiBlocked ? 0.5 : 1,
                        child: _HeroCard(
                          key: const ValueKey('overview_taxi_card'),
                          tone: ListingTone.sunrise,
                          asset: TravelIcon.taxi,
                          title: TripStringsOverview.taxi,
                          chip: taxi.chip,
                          line: TripStringsOverview.taxiLine,
                          button: taxi.button,
                          buttonKey: const ValueKey('overview_taxi_button'),
                          onTap: taxiBlocked ? null : () => onTaxi(taxi),
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
            label: taxi.hasRequest ? TripStringsOverview.backToTrips : TripStringsOverview.skip,
            tone: indigo,
            onTap: onDone,
          ),
        ],
        ),
      ),
    );
  }
}

class _TripLine extends StatelessWidget {
  const _TripLine({required this.trip});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final line = TripStringsOverview.tripLine(trip.legCount, trip.dayCount, trip.plan.settings.peopleCount);
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(16)),
      child: Container(
        padding: DS.sym(h: 16, v: 12),
        decoration: BoxDecoration(color: DesignColors.whiteSoft, borderRadius: DS.br(CardRadius.hero)),
        child: Row(
          children: [
            Art3D(asset: ListingArt.mountain, size: narrow ? 52 : 72, shadowBlur: 4, shadowOffset: const Offset(2, 3)),
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
                    style: Ink3D.text(17, FontWeight.w700, DesignColors.textInverse),
                  ),
                  Text(
                    line,
                    key: const ValueKey('overview_trip_line'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12.5, FontWeight.w400, DesignColors.textInverse, height: 1.5),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    super.key,
    required this.tone,
    required this.asset,
    required this.title,
    required this.chip,
    required this.line,
    required this.button,
    required this.buttonKey,
    required this.onTap,
  });

  final ListingTone tone;
  final String asset;
  final String title;
  final String chip;
  final String line;
  final String button;
  final Key buttonKey;
  final VoidCallback? onTap;

  // Design units: WhitePillButton applies the DS scale itself.
  static const double _buttonFont = 13.5;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(140)),
      padding: DS.insets(l: 16, t: 16, r: 20, b: 16),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.br(CardRadius.hero), boxShadow: tone.glow(blur: 14, dy: 6)),
      child: Row(
        children: [
          Container(
            width: DS.s(narrow ? 84 : 100),
            height: DS.s(narrow ? 84 : 100),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: DesignColors.whiteSoft, shape: BoxShape.circle),
            child: Art3D(asset: asset, size: narrow ? 52 : 62, shadowBlur: 4, shadowOffset: const Offset(3, 5)),
          ),
          Gap.h(16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: DS.s(narrow ? 0 : 24)),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, maxLines: 1, style: Ink3D.text(21, FontWeight.w700, DesignColors.textInverse, height: 1.2)),
                      ),
                    ),
                    Gap.h(10),
                    Container(
                      padding: DS.sym(h: 12, v: 3),
                      decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surface, Alpha.v30), borderRadius: DS.circular(10)),
                      child: Text(chip, style: Ink3D.text(12.5, FontWeight.w700, DesignColors.textInverse)),
                    ),
                  ],
                ),
                Gap.v(8),
                Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, DesignColors.textInverse, height: 1.45)),
                Gap.v(8),
                WhitePillButton(
                  key: buttonKey,
                  tone: tone,
                  label: button,
                  onTap: onTap,
                  height: 40,
                  fontSize: _buttonFont,
                  expand: false,
                ),
              ],
            ),
            ),
          ),
        ],
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
        padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), DS.s(16)),
        child: WhitePillButton(key: const ValueKey('overview_done_button'), tone: tone, label: label, onTap: onTap),
      ),
    );
  }
}
