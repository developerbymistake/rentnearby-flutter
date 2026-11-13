import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../../models/place_result_model.dart';
import '../taxi_ways_navigation.dart';
import '../taxi_ways_strings.dart';

class TaxiWaysEntryCard extends StatelessWidget {
  final PlaceResult from;
  final PlaceResult to;
  final bool empty;
  final bool fromMyLocation;

  const TaxiWaysEntryCard({
    super.key,
    required this.from,
    required this.to,
    this.empty = false,
    this.fromMyLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = empty ? TaxiWaysStrings.entryEmptyTitle : TaxiWaysStrings.entryTitle;
    final body = empty ? TaxiWaysStrings.entryEmptyBody : TaxiWaysStrings.entryBody(to.name);
    void open() => TaxiWaysNavigation.openFeed(from: from, to: to, fromMyLocation: fromMyLocation);
    return WideCard(
      tone: ListingTone.coral,
      art: empty ? 'assets/images/design/travel3d/automobile.png' : ListingArt.taxi,
      tag: TaxiWaysStrings.title,
      title: title,
      subtitle: body,
      reserveChips: false,
      showPrice: false,
      onGo: open,
      onTap: open,
      semanticsLabel: '$title. $body',
    );
  }
}
