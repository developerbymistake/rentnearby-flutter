import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import 'card_kit.dart';
import 'travel_icon.dart';
import 'trip_pick_kit.dart';

class StayGridCard extends StatelessWidget {
  static const double height = RailCard.height;

  const StayGridCard({
    super.key,
    required this.thumbnailUrl,
    required this.tagLabel,
    required this.title,
    required this.locationLabel,
    required this.facts,
    required this.priceCaption,
    required this.priceValue,
    required this.priceUnit,
    required this.onViewDetails,
    this.isFeatured = false,
  });

  final String? thumbnailUrl;
  final String tagLabel;
  final String title;
  final String locationLabel;
  final List<CardFact> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;
  final bool isFeatured;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return RailCard(
      thumbnailUrl: thumbnailUrl,
      tagLabel: tagLabel,
      title: title,
      locationLabel: locationLabel,
      facts: facts,
      priceCaption: priceCaption,
      priceValue: priceValue,
      priceUnit: priceUnit,
      isFeatured: isFeatured,
      onTap: onViewDetails,
    );
  }
}

class StayFloatingPill extends StatelessWidget {
  const StayFloatingPill({
    super.key,
    required this.label,
    required this.onTap,
    this.iconAsset = TravelIcon.map,
    this.gradient = PickKit.stayGradient,
    this.shadowColor = PickKit.stay,
  });

  final String label;
  final VoidCallback onTap;
  final String iconAsset;
  final Gradient gradient;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(24));
    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius, boxShadow: PickKit.shadow(shadowColor)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TravelIcon(iconAsset, size: 22),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: FitnessAppTheme.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
