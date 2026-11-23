import 'package:flutter/material.dart';
import '../features/trip/trip_strings_hub.dart';
import '../features/trip/trips_tour_steps.dart';
import 'shell_kind.dart';
import 'app_constants.dart';
import 'app_tabs.dart';

class TourStep {
  final GlobalKey key;
  final String title;
  final String body;
  final IconData icon;

  const TourStep({
    required this.key,
    required this.title,
    required this.body,
    required this.icon,
  });
}

class TourDefinition {
  final int tabIndex;
  final String storageKey;
  final String label;
  final List<TourStep> Function() stepsBuilder;
  final ShellKind? shell;

  const TourDefinition({
    required this.tabIndex,
    this.shell,
    required this.storageKey,
    required this.label,
    required this.stepsBuilder,
  });

  List<TourStep> get steps => stepsBuilder();
}

/// The guide lives only on the Trips tab of the seeker shell.
final Map<int, TourDefinition> tourRegistry = {
  AppTabs.trips: TourDefinition(
    tabIndex: AppTabs.trips,
    shell: ShellKind.seeker,
    storageKey: AppConstants.tourTripsSeenKey,
    label: TripStringsHub.tourLabel,
    stepsBuilder: tripsTourSteps,
  ),
};

TourDefinition? tourForTab(int tabIndex, ShellKind shell) {
  final tour = tourRegistry[tabIndex];
  if (tour == null) return null;
  if (tour.shell != null && tour.shell != shell) return null;
  return tour;
}
