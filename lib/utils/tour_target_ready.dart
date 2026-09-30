import 'package:flutter/material.dart';

/// The one and only "is this tour step's target actually showing right now"
/// check — mounted alone isn't enough (LocationPill
/// renders zero-size while its data is still resolving).
bool isTourTargetReady(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return false;
  final renderObject = ctx.findRenderObject();
  if (renderObject is! RenderBox) return false;
  if (!renderObject.attached || !renderObject.hasSize) return false;
  return renderObject.size.width > 0 && renderObject.size.height > 0;
}

/// Jumps any scrollable ancestor so an off-screen target comes into view.
/// Returns true if it scrolled (positions are stale until the next frame).
bool ensureTourTargetVisible(GlobalKey key) {
  if (!isTourTargetReady(key)) return false;
  final ctx = key.currentContext!;
  if (Scrollable.maybeOf(ctx) == null) return false;
  final box = ctx.findRenderObject() as RenderBox;
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final screenHeight = view.physicalSize.height / view.devicePixelRatio;
  final top = box.localToGlobal(Offset.zero).dy;
  if (box.size.height > screenHeight * 0.6) return false;
  if (top >= 80 && top + box.size.height <= screenHeight - 100) return false;
  Scrollable.ensureVisible(ctx, alignment: 0.3, duration: Duration.zero);
  return true;
}
