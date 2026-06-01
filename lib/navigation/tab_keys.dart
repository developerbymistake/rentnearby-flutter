import 'package:flutter/material.dart';

/// One NavigatorState key per bottom tab.
/// 0=Rooms, 1=MyRooms, 2=Plots, 3=MyPlots, 4=Profile
final List<GlobalKey<NavigatorState>> tabKeys = List.generate(
  5,
  (_) => GlobalKey<NavigatorState>(),
);
