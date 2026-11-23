import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../design/design.dart';
import '../../../trip/map/discovery_api.dart';
import '../../../trip/map/trip_discovery_layer.dart';
import '../../../trip/models/trip_spot_model.dart';
import '../../../trip/utils/trip_spots_cache.dart';
import '../../../trip/widgets/trip_map_controls.dart';
import '../../../trip/widgets/trip_map_spot_card.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../../trip/widgets/trip_spot_detail_sheet.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/segment_tabs.dart';
import '../../shared/widgets/view_only_chip.dart';
import '../controllers/viewer_trip_controller.dart';
import '../models/viewer_models.dart';
import '../viewer_look.dart';
import '../viewer_strings.dart';
import '../widgets/viewer_map_scene.dart';
import '../widgets/viewer_route_map.dart';

typedef ViewerMapBuilder = Widget Function(BuildContext context, ViewerMapView view);

class ViewerMapScreen extends StatefulWidget {
  const ViewerMapScreen({super.key, required this.tripId, this.day, this.mapBuilder});

  final String tripId;
  final int? day;
  final ViewerMapBuilder? mapBuilder;

  static const Key mapKey = ValueKey('viewer_route_map');
  static const Key noRoadKey = ValueKey('viewer_no_road');
  static const double side = 12;
  static const double compactCell = 90;

  @override
  State<ViewerMapScreen> createState() => _ViewerMapScreenState();
}

class _ViewerMapScreenState extends State<ViewerMapScreen> {
  late final ViewerTripController _c;
  final _topKey = GlobalKey();
  bool _own = false;
  int _selected = ViewerMapScene.all;
  ViewerMapStop? _picked;
  MapLibreMapController? _map;
  ViewerTrip? _sceneTrip;
  ViewerMapScene _scene = const ViewerMapScene(days: [], stops: []);

  @override
  void initState() {
    super.initState();
    final existing = ViewerTripController.maybeOf(widget.tripId);
    if (existing != null) {
      _c = existing;
    } else {
      _own = true;
      _c = Get.put(ViewerTripController(widget.tripId), tag: widget.tripId);
    }
    _selected = widget.day ?? ViewerMapScene.all;
  }

  @override
  void dispose() {
    if (_own && identical(ViewerTripController.maybeOf(widget.tripId), _c)) Get.delete<ViewerTripController>(tag: widget.tripId, force: true);
    super.dispose();
  }

  ViewerMapScene _sceneOf(ViewerTrip? t) {
    if (!identical(t, _sceneTrip)) {
      _sceneTrip = t;
      _scene = t == null ? const ViewerMapScene(days: [], stops: []) : ViewerMapScene.of(t.days, t.legs);
    }
    return _scene;
  }

  double _topHeight() {
    final box = _topKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : DS.s(140);
  }

  EdgeInsets _cameraPadding() {
    final safe = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
      DS.s(24),
      _topHeight() + DS.gv(24),
      DS.s(TripMapControls.columnSize) + DS.s(ViewerMapScreen.side) * 2,
      safe + DS.gv(24),
    );
  }

  void _pickDay(int day) => setState(() {
        _selected = day;
        _picked = null;
      });

  void _onTap(ViewerMapStop? stop) {
    if (stop == _picked) return;
    setState(() => _picked = stop);
  }

  void _details(ViewerMapStop s) {
    final key = s.cityKey;
    TripSpotDetailSheet.show(
      context,
      spot: TripSpotModel.fromJson({
        'id': s.spot.id,
        'name': s.spot.name,
        'latitude': s.spot.latitude,
        'longitude': s.spot.longitude,
        'category': s.spot.category,
        'rank': 0,
        'imageUrl': s.photoUrl,
        if (s.spot.visitMinutes > 0) 'visitMinutes': s.spot.visitMinutes,
      }),
      selected: false,
      locked: false,
      cityKey: key,
      version: key == null ? null : TripSpotsCache.versionOf(key) ?? '',
      partial: true,
      showAction: false,
      revalidate: true,
    );
  }

  bool _compact(BuildContext context, int cells) {
    final width = MediaQuery.sizeOf(context).width - DS.s(44);
    return width / cells < MediaQuery.textScalerOf(context).scale(DS.s(ViewerMapScreen.compactCell));
  }

  Widget _top(BuildContext context, ViewerTrip? t, ViewerMapScene scene, int selected) {
    final days = scene.days;
    final index = selected == ViewerMapScene.all ? 0 : 1 + days.indexWhere((d) => d.day == selected);
    final labels = [ViewerStrings.allDays, for (final d in days) ViewerStrings.dayChip(d.day)];
    return Column(
      key: _topKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: TripFlowHeader(
            title: t?.title ?? ViewerStrings.map,
            subtitle: t == null ? null : ViewerStrings.mapSubtitle(t.owner.name, t.dayCount, t.spotCount),
            onBack: Get.back,
            trailing: const [ViewOnlyChip()],
          ),
        ),
        if (days.length > 1)
          SegmentTabs(
            labels: labels,
            selected: index,
            tone: BuddyLook.indigo,
            margin: DS.insets(l: 18, t: 12, r: 18),
            dayDots: [Colors.transparent, for (final d in days) d.color],
            compact: _compact(context, labels.length),
            onTap: (i) => _pickDay(i == 0 ? ViewerMapScene.all : days[i - 1].day),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final t = _c.trip.value;
        final scene = _sceneOf(t);
        final selected = scene.days.any((d) => d.day == _selected) ? _selected : ViewerMapScene.all;
        final picked = _picked;
        final safe = MediaQuery.paddingOf(context).bottom;
        final s = DS.s(ViewerMapScreen.side);
        final view = ViewerMapView(scene: scene, selected: selected, picked: picked, onTap: _onTap);
        return Scaffold(
          backgroundColor: DesignColors.scaffold,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              if (scene.days.isEmpty)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: DS.all(24),
                      child: Text(ViewerStrings.noRouteYet, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, ViewerLook.sub, letterSpacing: 0)),
                    ),
                  ),
                )
              else ...[
                Positioned.fill(
                  child: KeyedSubtree(
                    key: ViewerMapScreen.mapKey,
                    child: widget.mapBuilder?.call(context, view) ?? ViewerRouteMap(view: view, padding: _cameraPadding, onMap: (c) => _map = c),
                  ),
                ),
                if (scene.dashedShown(selected))
                  Positioned(
                    left: DS.s(14),
                    bottom: safe + DS.gv(20),
                    child: TripMapLoadingChip(key: ViewerMapScreen.noRoadKey, text: ViewerStrings.noRoadLine),
                  ),
                Positioned(
                  right: s,
                  bottom: safe + DS.gv(24),
                  child: TripMapControls.column(showEye: false, map: () => _map, onLocate: () => DiscoveryCamera.toUser(_map)),
                ),
                if (picked != null)
                  Positioned(
                    left: s,
                    right: s,
                    top: _topHeight() + DS.gv(12),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: DS.s(TripMapSpotCard.maxWidth)),
                        child: TripMapSpotCard(
                          key: ValueKey('viewer_card_${picked.spot.id}'),
                          spot: picked.disc,
                          mode: DiscoveryMode.readOnly,
                          line: picked.line,
                          onDetails: () => _details(picked),
                          onClose: () => _onTap(null),
                        ),
                      ),
                    ),
                  ),
              ],
              Positioned(left: 0, right: 0, top: 0, child: _top(context, t, scene, selected)),
            ],
          ),
        );
      });
}
