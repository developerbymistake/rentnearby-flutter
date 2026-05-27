import 'package:flutter/material.dart';

abstract final class AppInsets {
  /// Physical height of the system navigation bar (gesture bar / 3-button bar
  /// / home indicator). Use this as extra bottom padding in any widget that
  /// paints a custom bottom container drawn edge-to-edge.
  ///
  /// Uses [MediaQuery.viewPaddingOf] so the value is unaffected by keyboard
  /// show/hide — keyboard insets are handled by adjustResize at the OS level.
  static double bottomViewPadding(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom;

  /// Physical height of the status bar. Available when a widget needs the raw
  /// value; most screens use [SafeArea] for the top instead.
  static double topViewPadding(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).top;
}
