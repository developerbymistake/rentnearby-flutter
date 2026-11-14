import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../trip_strings_tab.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_bar_rules.dart';
import '../utils/trip_clock.dart';
import 'trip_card.dart';

class TripContinueRail extends StatefulWidget {
  const TripContinueRail({
    super.key,
    required this.trips,
    required this.tone,
    required this.onOpen,
  });

  final List<TripSummaryModel> trips;
  final ListingTone tone;
  final ValueChanged<TripSummaryModel> onOpen;

  static const double cardWidth = 292;
  static const double gap = 12;
  static const double inset = 18;
  static const double _cardSide = 14;

  @override
  State<TripContinueRail> createState() => _TripContinueRailState();
}

class _TripContinueRailState extends State<TripContinueRail> {
  final _scroll = ScrollController();
  int _page = 0;
  double _extent = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = (_scroll.offset / _extent).round().clamp(
      0,
      widget.trips.length - 1,
    );
    if (p != _page) setState(() => _page = p);
  }

  Widget _card(TripSummaryModel t) {
    final name = t.title.trim().isEmpty
        ? TripCard.routeTitle(t)
        : t.title.trim();
    final dates = TripCard.lineBreakDates(
      TripBarRules.datesLine(t, TripClock.today()),
    );
    final next = TripBarRules.nextTitle(t);
    final p = t.progress;
    final needs = TripBarRules.needCount(t);
    return WideCard(
      key: ValueKey('continue-${t.id}'),
      tone: ListingTone.cB,
      art: ListingArt.luggage,
      title: name,
      subtitle: next == null ? dates : '$dates\n$next',
      chips: [
        if (p.total > 0) TripStringsTab.doneShort(p.done, p.total),
        if (needs > 0)
          TripStringsV2Plan.needsYou(needs)
        else if (p.inProgress > 0)
          TripStringsTab.waitingShort(p.inProgress),
      ],
      showPrice: false,
      progress: p.percent / 100,
      onTap: () => widget.onOpen(t),
    );
  }

  Widget _railItem(TripSummaryModel t) {
    const side = TripContinueRail._cardSide;
    const full = TripContinueRail.cardWidth + side * 2;
    const shown = TripContinueRail.cardWidth + TripContinueRail.gap;
    return Align(
      alignment: const Alignment(2 * side / (full - shown) - 1, 0),
      widthFactor: shown / full,
      child: SizedBox(width: full, child: _card(t)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = widget.trips;
    if (trips.length == 1) return _card(trips.first);
    const itemW = TripContinueRail.cardWidth + TripContinueRail.gap;
    _extent = itemW;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const _RailSnapPhysics(itemW),
          padding: const EdgeInsets.only(left: TripContinueRail.inset),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in trips) _railItem(t),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _RailDots(count: trips.length, index: _page, tone: widget.tone),
      ],
    );
  }
}

class _RailDots extends StatelessWidget {
  const _RailDots({
    required this.count,
    required this.index,
    required this.tone,
  });

  final int count;
  final int index;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        key: const ValueKey('continue-dots'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: KitMotion.reduce(context)
                  ? Duration.zero
                  : templateTransitionDuration,
              curve: Curves.fastOutSlowIn,
              width: i == index ? 20 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == index
                    ? tone.g2
                    : tone.g2.withValues(alpha: Alpha.soft),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailSnapPhysics extends ScrollPhysics {
  const _RailSnapPhysics(this.extent, {super.parent});

  final double extent;

  @override
  _RailSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _RailSnapPhysics(extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final projected = position.pixels + velocity * 0.12;
    final target = ((projected / extent).round() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < toleranceFor(position).distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
