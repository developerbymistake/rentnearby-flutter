import 'package:flutter/material.dart';

/// The one and only "is this tour step's target actually showing right now"
/// check — mounted alone isn't enough (LocationPill/ServiceCategoryRail both
/// render zero-size while their data is still resolving).
bool isTourTargetReady(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return false;
  final renderObject = ctx.findRenderObject();
  if (renderObject is! RenderBox) return false;
  if (!renderObject.attached || !renderObject.hasSize) return false;
  return renderObject.size.width > 0 && renderObject.size.height > 0;
}
