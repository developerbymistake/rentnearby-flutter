import 'package:flutter/material.dart';
import '../config/app_tabs.dart';

/// One NavigatorState key per bottom tab — see AppTabs for the index mapping.
final List<GlobalKey<NavigatorState>> tabKeys = List.generate(
  AppTabs.count,
  (_) => GlobalKey<NavigatorState>(),
);
