import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
import '../controllers/nearby_centre_controller.dart';
import '../nearby_strings.dart';

class PlaceSearchBar extends StatelessWidget {
  const PlaceSearchBar({super.key, this.controller, this.compact = false, this.margin = EdgeInsets.zero});

  final NearbyCentreController? controller;
  final bool compact;
  final EdgeInsets margin;

  static void clear(NearbyCentreController c) {
    c.clearPin();
    final loc = Get.isRegistered<LocationController>() ? Get.find<LocationController>() : null;
    if (loc != null && loc.searchPinOverride.value != null) loc.endSearchOverride();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller ?? NearbyCentreController.to;
    return Obx(() {
      c.centreVersion.value;
      final loc = Get.isRegistered<LocationController>() ? Get.find<LocationController>() : null;
      final label = c.hasPin ? c.pinLabel : null;
      return PlaceSearchBarView(
        label: label,
        compact: compact,
        margin: margin,
        busy: loc?.searchResolving.value ?? false,
        onTap: () => c.pickPlace(context),
        onClear: () => clear(c),
      );
    });
  }
}

class PlaceSearchBarView extends StatelessWidget {
  const PlaceSearchBarView({
    super.key,
    required this.onTap,
    this.onClear,
    this.label,
    this.caption,
    this.hint,
    this.art,
    this.clearLabel,
    this.compact = false,
    this.busy = false,
    this.margin = EdgeInsets.zero,
  });

  final String? label;
  final String? caption;
  final String? hint;
  final String? art;
  final String? clearLabel;
  final bool compact;
  final bool busy;
  final EdgeInsets margin;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  static Widget _grow(bool on, Widget child) => on ? IntrinsicHeight(child: child) : child;

  @override
  Widget build(BuildContext context) {
    final has = label != null && label!.isNotEmpty;
    final height = compact ? KitMetrics.touch : 56.0;
    final hintText = hint ?? NearbyStrings.searchPlaceHint;
    final cap = caption;
    final valueText = Text(
      has ? label! : hintText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Ink3D.text(15, has ? FontWeight.w600 : FontWeight.w400, has ? Ink3D.body : Ink3D.hint, letterSpacing: 0, height: cap == null ? null : 1.15),
    );
    return Padding(
      padding: margin,
      child: Container(
        height: cap == null ? height : null,
        constraints: cap == null ? null : BoxConstraints(minHeight: height),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(38), boxShadow: ShadowTokens.elev2),
        child: _grow(
          cap != null,
          Row(
            crossAxisAlignment: cap == null ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: cap == null ? (has ? label : hintText) : '$cap, ${has ? label : hintText}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(38),
                    onTap: busy ? null : onTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          ExcludeSemantics(child: Art3D(asset: art ?? TravelIcon.search, size: compact ? 30 : 36, shadowBlur: 3, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ExcludeSemantics(
                              child: cap == null
                                  ? valueText
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(cap, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w400, Ink3D.hint, letterSpacing: 0, height: 1.15)),
                                        valueText,
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (busy)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: KitDots(color: DesignColors.primary, size: 6))
              else if (has && onClear != null)
                Center(
                  child: Semantics(
                    button: true,
                    label: clearLabel ?? NearbyStrings.backToMyLocation,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onClear,
                      child: SizedBox(
                        width: KitMetrics.touch,
                        height: KitMetrics.touch,
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(color: DesignColors.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, size: 14, color: DesignColors.onPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
