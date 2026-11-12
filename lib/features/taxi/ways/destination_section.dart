import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../models/taxi_browse_item.dart';
import 'models/taxi_ways_models.dart';
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

  const AtDestinationSection({
    super.key,
    required this.cityName,
    required this.date,
    required this.people,
    required this.localTaxis,
    required this.stays,
    required this.reachFirstPlace,
    required this.hasWays,
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
    if (widget.localTaxis.isEmpty && widget.stays.isEmpty && reach == null) return const SizedBox.shrink();
    final blocks = <Widget>[
      _title(),
      if (reach != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: ReachByTrainCard(placeName: reach.name)),
      if (widget.localTaxis.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _subHeading(TaxiWaysStrings.localTaxis(widget.localTaxis.length)),
            const SizedBox(height: 8),
            _taxiRail(context),
          ]),
        ),
      if (widget.stays.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _subHeading(TaxiWaysStrings.stayIn(widget.cityName),
                caption: TaxiWaysStrings.staysCount(widget.stays.length, widget.date)),
            const SizedBox(height: 8),
            _stays(),
          ]),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < blocks.length; i++) _enter(i, blocks.length, blocks[i]),
    ]);
  }

  Widget _title() => Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: PickKit.taxi, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(TaxiWaysStrings.atPlace(widget.cityName),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FitnessAppTheme.title.copyWith(
                  fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: DesignColors.textSecondary)),
        ),
        if (widget.hasWays) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(TaxiWaysStrings.waysAbove,
                maxLines: 2,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.caption.copyWith(fontSize: 11)),
          ),
        ],
      ]);

  Widget _subHeading(String text, {String? caption}) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(text, style: FitnessAppTheme.title.copyWith(fontSize: 14)),
          if (caption != null) Text(caption, style: FitnessAppTheme.caption.copyWith(fontSize: 11)),
        ],
      );

  Widget _taxiRail(BuildContext context) => SizedBox(
        height: LocalTaxiRailCard.heightFor(context),
        child: _HRail(
          count: widget.localTaxis.length,
          builder: (i) => LocalTaxiRailCard(key: ValueKey(widget.localTaxis[i].id), item: widget.localTaxis[i]),
        ),
      );

  Widget _stays() {
    DestinationStayCard card(StayNearbyModel s, double w) => DestinationStayCard(
        key: ValueKey(s.id), stay: s, cityName: widget.cityName, date: widget.date, people: widget.people, width: w);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= _tablet) {
        final w = (c.maxWidth - 24) / 3;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final s in widget.stays) card(s, w)]);
      }
      return SizedBox(
        height: DestinationStayCard.heightFor(context),
        child: _HRail(count: widget.stays.length, builder: (i) => card(widget.stays[i], 190)),
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
      padding: EdgeInsets.zero,
      itemCount: widget.count,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
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
