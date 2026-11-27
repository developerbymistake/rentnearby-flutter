import 'package:bakhli/design/design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../trip_strings_map_disc.dart';
import '../widgets/map_spot_card_host.dart';
import '../widgets/trip_map_controls.dart';
import '../widgets/trip_map_scale_bar.dart';
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
  final ValueListenable<double?>? metersPerDp;

  static const double controlsY = 0.14;
  static const double controlsRight = 12;
  static const double chipGapTop = 36;
  static const double chipGapBottomPlacement = 10;
  static const double chipLeftTop = 18;
  static const double cardGapTop = 52;
  static const double cardGapBottom = 12;
  static const double scaleRight = 14;
  static const double scaleBottom = 20;

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
    this.metersPerDp,
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
      final isTop = placement == DiscoveryPlacement.top;
      final tipX = isTop ? layer.selectedScreenX.value : null;
      final band = MediaQuery.sizeOf(context).width - 2 * s;
      final cardMax = DS.s(TripMapSpotCard.maxWidth);
      final cardShift = band > cardMax ? (band - cardMax) / 2 : 0.0;
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
          if (m == DiscoveryMode.full && metersPerDp != null)
            Positioned(
              right: DS.s(scaleRight),
              bottom: host.bottomInset() + DS.s(scaleBottom),
              child: ValueListenableBuilder<double?>(
                valueListenable: metersPerDp!,
                builder: (_, v, _) => TripMapScaleBar(metersPerDp: v),
              ),
            ),
          if (chip != null && sel == null)
            Positioned(
              left: isTop ? DS.s(chipLeftTop) : s,
              right: s,
              top: top + DS.gv(isTop ? chipGapTop : chipGapBottomPlacement),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TripMapLoadingChip(key: const ValueKey('disc-chip'), text: chip, loading: loading, palette: palette),
              ),
            ),
          Positioned(
            key: const ValueKey('disc-card-slot'),
            left: s,
            right: s,
            top: isTop ? top + DS.gv(cardGapTop) : null,
            bottom: isTop ? null : host.bottomInset() + DS.gv(cardGapBottom),
            child: Align(
              alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardMax),
                child: MapSpotCardHost(
                  id: sel?.id,
                  label: sel?.name,
                  edge: isTop ? MapSpotCardEdge.top : MapSpotCardEdge.bottom,
                  onClose: () => layer.clearSelection(),
                  child: sel == null
                      ? null
                      : TripMapSpotCard(
                          spot: sel,
                          mode: m,
                          tone: ListingTone.palette(palette),
                          plannedDay: m == DiscoveryMode.full ? plannedDay : null,
                          targetDay: m == DiscoveryMode.full ? host.targetDayFor?.call(sel) : null,
                          line: host.lineFor?.call(sel),
                          onAdd: host.onAdd == null ? null : () => host.onAdd!(sel),
                          onRemove: host.onRemove == null ? null : () => host.onRemove!(sel),
                          onDetails: host.onDetails == null ? null : () => host.onDetails!(sel),
                          onClose: () => layer.clearSelection(),
                          dayColorOf: dayColorOf,
                          tipX: tipX == null ? null : tipX - s - cardShift,
                        ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
