import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../controllers/nearby_centre_controller.dart';
import '../nearby_strings.dart';

class NearbyCentreBar extends StatelessWidget {
  final NearbyCentreController? controller;
  const NearbyCentreBar({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller ?? NearbyCentreController.to;
    return Obx(() {
      c.centreVersion.value;
      final label = c.pinLabel;
      final text = c.hasPin && label != null ? NearbyStrings.usingPin(label) : NearbyStrings.usingGps;
      return NearbyCentreBarView(
        text: text,
        hasPin: c.hasPin,
        onSearch: () => c.pickPlace(context),
        onClear: c.clearPin,
        onUseMyLocation: c.useMyLocation,
      );
    });
  }
}

class NearbyCentreBarView extends StatelessWidget {
  final String text;
  final bool hasPin;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final VoidCallback onUseMyLocation;
  const NearbyCentreBarView({
    super.key,
    required this.text,
    required this.hasPin,
    required this.onSearch,
    required this.onClear,
    required this.onUseMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: DesignColors.primarySoft, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place_outlined, size: 16, color: DesignColors.primary),
                const SizedBox(width: 6),
                Flexible(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.label.copyWith(color: DesignColors.primary))),
                if (hasPin)
                  InkWell(
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.close_rounded, size: 18, color: DesignColors.primary),
                    ),
                  ),
              ]),
            ),
          ),
          TextButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text(NearbyStrings.searchAnyPlace),
          ),
          if (hasPin)
            TextButton.icon(
              onPressed: onUseMyLocation,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text(NearbyStrings.useMyLocation),
            ),
        ],
      ),
    );
  }
}
