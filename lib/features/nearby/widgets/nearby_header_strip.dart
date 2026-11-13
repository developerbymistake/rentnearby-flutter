import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../models/nearby_models.dart';
import '../nearby_strings.dart';

class NearbyHeaderStrip extends StatelessWidget {
  final NearbyHeader? header;
  final bool hasPin;
  const NearbyHeaderStrip({super.key, required this.header, this.hasPin = false});

  @override
  Widget build(BuildContext context) {
    final h = header;
    if (h == null) return const SizedBox.shrink();
    final lines = <String>[];
    final city = h.centreCityName;
    final km = h.centreCityKm;
    if (hasPin && city != null && km != null && km > 2) lines.add(NearbyStrings.nearestTown(city, km));
    if (h.citiesUnavailable) lines.add('${NearbyStrings.citiesLoadingTitle}. ${NearbyStrings.citiesLoadingBody}');
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines) Text(l, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.sub, height: 1.45)),
        ],
      ),
    );
  }
}
