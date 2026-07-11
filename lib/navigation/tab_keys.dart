import 'package:flutter/material.dart';

/// One NavigatorState key per bottom tab.
/// 0=Rooms, 1=MyRooms, 2=Plots, 3=MyPlots, 4=Profile, 5=Chats
final List<GlobalKey<NavigatorState>> tabKeys = List.generate(
  6,
  (_) => GlobalKey<NavigatorState>(),
);
