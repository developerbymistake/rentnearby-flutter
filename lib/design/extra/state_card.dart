import 'package:flutter/material.dart';
import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'kit_tone.dart';
import 'state_card_3d.dart';
import 'travel_icon.dart';

enum StateTone { empty, error }

ListingTone listingToneOf(KitTone kit) {
  if (identical(kit, KitTone.stay) || identical(kit, KitTone.stayOwner)) return ListingTone.forest;
  if (identical(kit, KitTone.taxi) || identical(kit, KitTone.taxiDriver)) return ListingTone.coral;
  return ListingTone.indigo;
}

class StateCard extends StatelessWidget {
  const StateCard({
    super.key,
    required this.title,
    this.message,
    this.tone = StateTone.empty,
    this.kit = KitTone.brand,
    this.asset = TravelIcon.route,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    this.layout = StateLayout.wide,
  });

  const StateCard.error({
    super.key,
    required this.title,
    this.message,
    this.kit = KitTone.brand,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    this.layout = StateLayout.wide,
  })  : tone = StateTone.error,
        asset = ListingArt.worldMap;

  final String title;
  final String? message;
  final StateTone tone;
  final KitTone kit;
  final String asset;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  final StateLayout layout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StateCard3D(
        tone: listingToneOf(kit),
        art: asset,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        layout: layout,
      ),
    );
  }
}
