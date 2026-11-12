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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(NearbyStrings.featuredTitle, style: TypeTokens.title.copyWith(color: DesignColors.textStrong)),
        ),
        for (final x in shown)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: builder(context, x)),
      ],
    );
  }
}
