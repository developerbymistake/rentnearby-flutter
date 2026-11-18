import 'package:bakhli/design/design.dart';
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

  static TripOverviewTaxi of(TripTaxiRequestRef? ref) => switch (ref?.view) {
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
    this.onBack,
  });

  final TripModel trip;
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

  @override
  Widget build(BuildContext context) {
    final taxi = TripOverviewTaxi.of(trip.taxiRequest);
    // Paused blocks only a new request; an existing request or booking can still be opened.
    final taxiBlocked = paused && !taxi.hasRequest;
    final indigo = ListingTone.indigo;
    return Scaffold(
      backgroundColor: DesignColors.surface,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ModuleHeader(
              title: TripStringsOverview.title,
              subtitle: TripStringsOverview.subtitle,
              autoHeight: true,
              tone: KitTone.brand,
              gradient: indigo.gradient,
              onBack: onBack ?? () => Get.back(),
              bottom: _TripLine(trip: trip),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: SingleChildScrollView(
                  padding: DS.sym(h: 18, v: 20),
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
          ),
          // Follows the card: Busy and Ended read Request taxi again, so the label stays Skip.
          _BottomBar(
            label: taxi.hasRequest ? TripStringsOverview.backToTrips : TripStringsOverview.skip,
            tone: indigo,
            onTap: onDone,
          ),
        ],
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
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(14)),
      child: Container(
        padding: DS.sym(h: 16, v: 12),
        decoration: BoxDecoration(color: DesignColors.whiteSoft, borderRadius: DS.br(CardRadius.hero)),
        child: Row(
          children: [
            const Art3D(asset: ListingArt.mountain, size: 44, shadowBlur: 4, shadowOffset: Offset(2, 3)),
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
                    style: Ink3D.text(16, FontWeight.w700, DesignColors.textInverse),
                  ),
                  Text(
                    line,
                    key: const ValueKey('overview_trip_line'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(13, FontWeight.w400, DesignColors.textInverse),
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
    return Container(
      padding: DS.insets(l: 16, t: 16, r: 20, b: 16),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.br(CardRadius.hero), boxShadow: tone.glow(blur: 14, dy: 6)),
      child: Row(
        children: [
          Container(
            width: DS.s(84),
            height: DS.s(84),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: DesignColors.whiteSoft, shape: BoxShape.circle),
            child: Art3D(asset: asset, size: 52, shadowBlur: 4, shadowOffset: const Offset(3, 4)),
          ),
          Gap.h(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: DS.gh(10),
                  runSpacing: DS.gv(4),
                  children: [
                    Text(title, style: Ink3D.text(20, FontWeight.w700, DesignColors.textInverse)),
                    Container(
                      padding: DS.sym(h: 12, v: 3),
                      decoration: BoxDecoration(color: DesignColors.whiteSoft, borderRadius: DS.circular(10)),
                      child: Text(chip, style: Ink3D.text(12, FontWeight.w700, DesignColors.textInverse)),
                    ),
                  ],
                ),
                Gap.v(6),
                Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, DesignColors.textInverse)),
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(16))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(14), DS.s(18), DS.s(20) + MediaQuery.paddingOf(context).bottom),
        child: WhitePillButton(key: const ValueKey('overview_done_button'), tone: tone, label: label, onTap: onTap),
      ),
    );
  }
}
