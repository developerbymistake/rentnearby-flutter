import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../models/taxi_browse_item.dart';
import 'models/taxi_ways_models.dart';
import '../../trip/trip_strings_city.dart';
import 'taxi_ways_strings.dart';
import 'widgets/destination_stay_card.dart';
import 'widgets/local_taxi_rail_card.dart';
import 'widgets/reach_by_train_card.dart';

class AtDestinationSection extends StatefulWidget {
  final String cityName;
  final DateTime date;
  final int people;
  final List<TaxiBrowseItem> localTaxis;
  final List<StayNearbyModel> stays;
  final WayPlace? reachFirstPlace;
  final bool hasWays;
  final bool citiesUnavailable;

  const AtDestinationSection({
    super.key,
    required this.cityName,
    required this.date,
    required this.people,
    required this.localTaxis,
    required this.stays,
    required this.reachFirstPlace,
    required this.hasWays,
    this.citiesUnavailable = false,
  });

  @override
  State<AtDestinationSection> createState() => _AtDestinationSectionState();
}

class _AtDestinationSectionState extends State<AtDestinationSection> with TickerProviderStateMixin {
  static const double _tablet = 600;

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _enter(int i, int count, Widget child) => TemplateEntrance(
        animation: templateInterval(_c, i, count),
        animationController: _c,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final reach = widget.hasWays ? null : widget.reachFirstPlace;
    if (widget.localTaxis.isEmpty && widget.stays.isEmpty && reach == null) {
      if (widget.cityName.trim().isEmpty && !widget.citiesUnavailable) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title(),
        WideCard(
          kind: WideKind.slim,
          tone: ListingTone.cA,
          art: ListingArt.taxi,
          title: widget.citiesUnavailable ? TripStringsCity.citiesLoadingTitle : TripStringsCity.noTaxisTitle(widget.cityName),
          subtitle: widget.citiesUnavailable ? TripStringsCity.citiesLoadingBody : TripStringsCity.noSupplyBody,
        ),
      ]);
    }
    final blocks = <Widget>[
      _title(),
      if (widget.localTaxis.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _subHeading(TaxiWaysStrings.localTaxis(widget.localTaxis.length)),
          _taxiRail(context),
        ]),
      if (widget.stays.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _subHeading(TaxiWaysStrings.stayIn(widget.cityName),
              caption: TaxiWaysStrings.staysCount(widget.stays.length, widget.date)),
          _stays(),
        ]),
      if (reach != null) ReachByTrainCard(placeName: reach.name),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < blocks.length; i++) _enter(i, blocks.length, blocks[i]),
    ]);
  }

  Widget _title() => TitleRow3D(
        title: TaxiWaysStrings.atPlace(widget.cityName),
        subtitle: widget.hasWays ? TaxiWaysStrings.waysAbove : null,
        tone: ListingTone.coral,
      );

  Widget _subHeading(String text, {String? caption}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Ink3D.body)),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(caption, maxLines: 1, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey)),
            ),
        ]),
      );

  Widget _taxiRail(BuildContext context) => SizedBox(
        height: LocalTaxiRailCard.heightFor(context),
        child: _HRail(
          count: widget.localTaxis.length,
          builder: (i) => LocalTaxiRailCard(key: ValueKey(widget.localTaxis[i].id), item: widget.localTaxis[i], index: i),
        ),
      );

  Widget _stays() {
    DestinationStayCard card(StayNearbyModel s, int i, double w) => DestinationStayCard(
        key: ValueKey(s.id), stay: s, cityName: widget.cityName, date: widget.date, people: widget.people, width: w, index: i);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= _tablet) {
        final w = (c.maxWidth - 40) / 3;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Wrap(children: [for (var i = 0; i < widget.stays.length; i++) card(widget.stays[i], i, w)]),
        );
      }
      return SizedBox(
        height: DestinationStayCard.heightFor(context),
        child: _HRail(count: widget.stays.length, builder: (i) => card(widget.stays[i], i, 160)),
      );
    });
  }
}

class _HRail extends StatefulWidget {
  final int count;
  final Widget Function(int index) builder;

  const _HRail({required this.count, required this.builder});

  @override
  State<_HRail> createState() => _HRailState();
}

class _HRailState extends State<_HRail> with TickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: widget.count,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (_, i) {
        final animation = templateInterval(_c, i < 5 ? i : 5, widget.count < 6 ? widget.count : 6);
        return AnimatedBuilder(
          animation: _c,
          builder: (context, child) => FadeTransition(
            opacity: animation,
            child: Transform(
              transform: Matrix4.translationValues(100 * (1.0 - animation.value), 0.0, 0.0),
              child: child,
            ),
          ),
          child: widget.builder(i),
        );
      },
    );
  }
}
