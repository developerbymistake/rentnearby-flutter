import 'dart:math' as math;

import 'package:flutter/material.dart';

class DockInset extends InheritedWidget {
  const DockInset({super.key, required this.height, required super.child});

  final double height;

  // Latest dock height, for overlays (toasts) that live outside the body subtree.
  static double lastHeight = 0;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DockInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(DockInset oldWidget) => oldWidget.height != height;
}

// Place as the Scaffold body: its MediaQuery.padding.bottom is the dock height there.
class DockInsetScope extends StatelessWidget {
  const DockInsetScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.paddingOf(context).bottom;
    DockInset.lastHeight = h;
    return DockInset(height: h, child: child);
  }
}

class _Lifted extends InheritedWidget {
  const _Lifted({required this.dock, required this.lift, required super.child});

  final double dock;
  final double lift;

  static _Lifted? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Lifted>();

  @override
  bool updateShouldNotify(_Lifted oldWidget) => oldWidget.dock != dock || oldWidget.lift != lift;
}

class SheetInsets {
  const SheetInsets._();

  static double dock(BuildContext context) => _Lifted.maybeOf(context)?.dock ?? DockInset.of(context);

  static double lift(BuildContext context) {
    final lifted = _Lifted.maybeOf(context);
    if (lifted != null) return lifted.lift;
    return math.max(DockInset.of(context), MediaQuery.viewInsetsOf(context).bottom);
  }
}

// Lifts a sheet so its bottom edge sits on the dock (or the keyboard, whichever is higher)
// and consumes those insets so nothing inside counts them twice. Idempotent.
class DockLift extends StatelessWidget {
  const DockLift({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_Lifted.maybeOf(context) != null) return child;
    final mq = MediaQuery.of(context);
    final dock = DockInset.of(context);
    final lift = math.max(dock, mq.viewInsets.bottom);
    return _Lifted(
      dock: dock,
      lift: lift,
      child: Padding(
        padding: EdgeInsets.only(bottom: lift),
        child: MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(bottom: math.max(0, mq.padding.bottom - dock)),
            viewPadding: mq.viewPadding.copyWith(bottom: math.max(0, mq.viewPadding.bottom - dock)),
            viewInsets: mq.viewInsets.copyWith(bottom: 0),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Same as showModalBottomSheet, always on the nearest (tab) navigator and dock-aware.
Future<T?> showDockSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  Color? barrierColor,
  double? elevation,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  ShapeBorder? shape,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: false,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      elevation: elevation,
      clipBehavior: clipBehavior,
      constraints: constraints,
      shape: shape,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      builder: (c) => DockLift(child: builder(c)),
    );
