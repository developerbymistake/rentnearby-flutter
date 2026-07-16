import 'package:flutter/material.dart';

/// Caps content at a comfortable width and centers it — the standard way
/// phone-first UI adapts to tablet/wide screens without a dedicated tablet
/// redesign (matches Material's compact/medium window-size-class guidance).
/// A no-op on phone widths (the constraint never binds below [maxWidth]);
/// on wider screens, content keeps its designed phone proportions inside a
/// centered column instead of stretching to fill the extra width.
class MaxWidthContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const MaxWidthContent({super.key, required this.child, this.maxWidth = 600});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
