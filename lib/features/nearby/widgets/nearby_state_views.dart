import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_shared.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../nearby_strings.dart';

String _artFor(ListingTone tone, String title) {
  if (title == NearbyStrings.jobsEmptyTitle) return ListingArt.clipboard;
  if (identical(tone, ListingTone.coral)) return ListingArt.taxi;
  return ListingArt.hotel;
}

class NearbyEmpty extends StatelessWidget {
  final String title;
  final String body;
  final ListingTone? tone;
  final String? art;
  const NearbyEmpty({super.key, required this.title, required this.body, this.tone, this.art});

  @override
  Widget build(BuildContext context) {
    final t = tone ?? moduleToneFor();
    return StateCard3D(tone: t, art: art ?? _artFor(t, title), title: title, message: body);
  }
}

class NearbyThin extends StatelessWidget {
  const NearbyThin({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: ThinNote3D(NearbyStrings.thin),
      );
}

class NearbyError extends StatelessWidget {
  final VoidCallback onRetry;
  final ListingTone? tone;
  const NearbyError({super.key, required this.onRetry, this.tone});

  @override
  Widget build(BuildContext context) => StateCard3D(
        tone: tone ?? moduleToneFor(),
        art: ListingArt.worldMap,
        title: NearbyStrings.errorTitle,
        message: NearbyStrings.errorBody,
        actionLabel: NearbyStrings.tryAgain,
        onAction: onRetry,
      );
}
