import 'package:flutter/material.dart';
import '../design/design.dart';
import 'location_switch_sheet.dart';

class AppLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String message;
  final Color indicatorColor;

  const AppLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message = 'Loading...',
    this.indicatorColor = FitnessAppTheme.nearlyDarkBlue,
  });

  static Widget stackChild({
    String message = 'Loading...',
    Color indicatorColor = FitnessAppTheme.nearlyDarkBlue,
  }) {
    return Positioned.fill(child: _LoadingBody(message: message));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) Positioned.fill(child: _LoadingBody(message: message)),
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  final String message;
  const _LoadingBody({required this.message});

  static String _artFor(ListingTone tone) {
    if (identical(tone, ListingTone.forest)) return ListingArt.hotel;
    if (identical(tone, ListingTone.coral)) return ListingArt.taxi;
    return ListingArt.airplane;
  }

  @override
  Widget build(BuildContext context) {
    final tone = moduleToneFor();
    return BusyOverlay3D(tone: tone, art: _artFor(tone), message: message);
  }
}
