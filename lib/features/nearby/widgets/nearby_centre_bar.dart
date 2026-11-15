import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../controllers/nearby_centre_controller.dart';
import '../nearby_strings.dart';

class NearbyCentreBar extends StatelessWidget {
  final NearbyCentreController? controller;
  final bool far;
  const NearbyCentreBar({super.key, this.controller, this.far = false});

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
        far: far,
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
  final bool far;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final VoidCallback onUseMyLocation;
  const NearbyCentreBarView({
    super.key,
    required this.text,
    required this.hasPin,
    this.far = false,
    required this.onSearch,
    required this.onClear,
    required this.onUseMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.gv(8), DS.s(16), DS.gv(4)),
      child: Wrap(
        spacing: DS.gh(8),
        runSpacing: DS.gv(8),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - DS.s(16) * 2),
            child: Container(
              padding: DS.sym(h: 12, v: 8),
              decoration: BoxDecoration(color: DesignColors.primarySoft, borderRadius: DS.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.place_outlined, size: DS.s(16), color: DesignColors.primary),
                Gap.h(6),
                Flexible(child: Text(!hasPin && far ? NearbyStrings.usingMyLocation : text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.label.copyWith(color: DesignColors.primary))),
                if (hasPin)
                  InkWell(
                    onTap: onClear,
                    child: Padding(
                      padding: EdgeInsets.only(left: DS.s(6)),
                      child: Icon(Icons.close_rounded, size: DS.s(18), color: DesignColors.primary),
                    ),
                  ),
              ]),
            ),
          ),
          TextButton.icon(
            onPressed: onSearch,
            icon: Icon(Icons.search_rounded, size: DS.s(18)),
            label: const Text(NearbyStrings.searchAnyPlace),
          ),
          if (hasPin)
            TextButton.icon(
              onPressed: onUseMyLocation,
              icon: Icon(Icons.my_location_rounded, size: DS.s(18)),
              label: const Text(NearbyStrings.useMyLocation),
            ),
        ],
      ),
    );
  }
}
