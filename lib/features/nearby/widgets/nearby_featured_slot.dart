import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../nearby_strings.dart';

class NearbyFeaturedSlot<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) builder;
  const NearbyFeaturedSlot({super.key, required this.items, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TitleRow3D(title: NearbyStrings.featuredTitle),
        for (final x in shown) builder(context, x),
      ],
    );
  }
}
