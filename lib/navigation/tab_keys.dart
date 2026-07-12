import 'package:flutter/material.dart';

/// One NavigatorState key per bottom tab.
/// 0=Rooms, 1=Plots, 2=Chats, 3=Profile
/// (My Rooms/My Plots are no longer tabs — reached via a header button on
/// Rooms/Plots that pushes a named route instead.)
final List<GlobalKey<NavigatorState>> tabKeys = List.generate(
  4,
  (_) => GlobalKey<NavigatorState>(),
);
