import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../trip_strings_map_disc.dart';
import '../widgets/trip_map_controls.dart';
import '../widgets/trip_map_spot_card.dart';
import 'discovery_api.dart';

enum DiscoveryPlacement { top, bottom }

class DiscoveryOverlay extends StatelessWidget {
  final DiscoveryLayerApi layer;
  final DiscoveryMode? mode;
  final DiscoveryPlacement placement;
  final MapLibreMapController? Function()? map;
  final VoidCallback? onLocate;
  final String? Function()? notice;
  final Color Function(int day)? dayColorOf;
  final ListingPalette palette;
  final double side;

  static const double controlsY = 0.14;
  static const double controlsRight = 12;
  static const double chipGap = 8;
  static const double cardGapTop = 16;
  static const double cardGapBottom = 12;

  const DiscoveryOverlay({
    super.key,
    required this.layer,
    this.mode,
    this.placement = DiscoveryPlacement.top,
    this.map,
    this.onLocate,
    this.notice,
    this.dayColorOf,
    this.palette = ListingPalette.indigo,
    this.side = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final empty = Stack(fit: StackFit.expand, children: const []);
      if (!layer.attached.value) return empty;
      final sel = layer.selected.value;
      final plannedDay = layer.selectedPlannedDay.value;
      final eye = layer.eyeOn.value;
      final state = layer.dataState.value;
      final here = layer.hasSpotsHere.value;
      final note = notice?.call();
      final m = mode ?? layer.mode;
      final host = layer.host;
      final loading = state == DiscoveryDataState.loading;
      final chip = loading ? TripMapDiscStrings.loadingPlaces : note;
      final top = host.topInset();
      final s = DS.s(side);
      return Stack(
        fit: StackFit.expand,
        children: [
          if (placement == DiscoveryPlacement.top)
            Align(
              alignment: const Alignment(1, controlsY),
              child: Padding(
                padding: DS.insets(r: controlsRight),
                child: TripMapControls.column(
                  showEye: loading || here,
                  eyeOn: eye,
                  loading: loading,
                  onEye: (on) => layer.setEye(on),
                  map: map,
                  onLocate: onLocate,
                ),
              ),
            ),
          if (chip != null && sel == null)
            Positioned(
              left: s,
              right: s,
              top: top + DS.gv(chipGap),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TripMapLoadingChip(key: const ValueKey('disc-chip'), text: chip, loading: loading, palette: palette),
              ),
            ),
          if (sel != null)
            Positioned(
              left: s,
              right: s,
              top: placement == DiscoveryPlacement.top ? top + DS.gv(cardGapTop) : null,
              bottom: placement == DiscoveryPlacement.bottom ? host.bottomInset() + DS.gv(cardGapBottom) : null,
              child: TripMapSpotCard(
                spot: sel,
                mode: m,
                plannedDay: m == DiscoveryMode.full ? plannedDay : null,
                targetDay: m == DiscoveryMode.full ? host.targetDayFor?.call(sel) : null,
                line: host.lineFor?.call(sel),
                onAdd: host.onAdd == null ? null : () => host.onAdd!(sel),
                onRemove: host.onRemove == null ? null : () => host.onRemove!(sel),
                onDetails: host.onDetails == null ? null : () => host.onDetails!(sel),
                onClose: () => layer.clearSelection(),
                dayColorOf: dayColorOf,
              ),
            ),
        ],
      );
    });
  }
}
