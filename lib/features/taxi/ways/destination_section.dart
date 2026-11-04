import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_strings.dart';
import 'widgets/destination_stay_card.dart';
import 'widgets/local_taxi_rail_card.dart';
import 'widgets/reach_by_train_card.dart';

class AtDestinationSection extends StatelessWidget {
  static const double _tablet = 600;

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
  Widget build(BuildContext context) {
    final reach = hasWays ? null : reachFirstPlace;
    if (localTaxis.isEmpty && stays.isEmpty && reach == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(),
      if (reach != null) ...[
        const SizedBox(height: 12),
        ReachByTrainCard(placeName: reach.name),
      ],
      if (localTaxis.isNotEmpty) ...[
        const SizedBox(height: 16),
        _subHeading(TaxiWaysStrings.localTaxis(localTaxis.length)),
        const SizedBox(height: 8),
        _taxiRail(context),
      ],
      if (stays.isNotEmpty) ...[
        const SizedBox(height: 16),
        _subHeading(TaxiWaysStrings.stayIn(cityName), caption: TaxiWaysStrings.staysCount(stays.length, date)),
        const SizedBox(height: 8),
        _stays(),
      ],
    ]);
  }

  Widget _title() => Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: TaxiColors.accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(TaxiWaysStrings.atPlace(cityName),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ),
        if (hasWays) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(TaxiWaysStrings.waysAbove,
                maxLines: 2,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ),
        ],
      ]);

  Widget _subHeading(String text, {String? caption}) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          if (caption != null)
            Text(caption, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
        ],
      );

  Widget _taxiRail(BuildContext context) => SizedBox(
        height: LocalTaxiRailCard.heightFor(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: localTaxis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => LocalTaxiRailCard(key: ValueKey(localTaxis[i].id), item: localTaxis[i]),
        ),
      );

  Widget _stays() {
    DestinationStayCard card(StayNearbyModel s, double w) =>
        DestinationStayCard(key: ValueKey(s.id), stay: s, cityName: cityName, date: date, people: people, width: w);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= _tablet) {
        final w = (c.maxWidth - 24) / 3;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final s in stays) card(s, w)]);
      }
      return SizedBox(
        height: DestinationStayCard.heightFor(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: stays.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => card(stays[i], 190),
        ),
      );
    });
  }
}
