import 'package:flutter/material.dart';
import '../config/app_tabs.dart';

/// One NavigatorState key per bottom tab — see AppTabs for the index mapping.
/// (My Rooms/My Plots are no longer tabs — reached via a header button on
/// Rooms/Plots that pushes a named route instead.)
final List<GlobalKey<NavigatorState>> tabKeys = List.generate(
  AppTabs.count,
  (_) => GlobalKey<NavigatorState>(),
);
