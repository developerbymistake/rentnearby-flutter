import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../widgets/tab_header.dart';
import '../controllers/my_trips_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_hub.dart';
import '../widgets/hub/hub_continue_bar.dart';
import '../widgets/hub/hub_page_background.dart';
import '../widgets/hub/hub_section_title.dart';
import '../widgets/hub/hub_tile.dart';
import '../widgets/hub/hub_tile_config.dart';
import '../widgets/hub/hub_tokens.dart';

class TripsDiscoveryScreen extends StatefulWidget {
  const TripsDiscoveryScreen({super.key});

  @override
  State<TripsDiscoveryScreen> createState() => _TripsDiscoveryScreenState();
}

class _TripsDiscoveryScreenState extends State<TripsDiscoveryScreen> {
  static const double _maxWidth = 640;

  late final MyTripsController _trips;
  Worker? _tabWorker;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _trips = MyTripsController.to;
    _warmCatalog();
    _trips.ensureLoaded();
    if (Get.isRegistered<AuthController>()) {
      _tabWorker = ever<int>(Get.find<AuthController>().tabIndex, (i) {
        if (i != AppTabs.trips || !mounted) return;
        _trips.refreshIfStale();
        _warmCatalog();
      });
    }
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _warmCatalog({bool force = false}) async {
    final catalog = TripCityCatalog.to;
    catalog.warmFromDisk();
    try {
      await catalog.load(force: force);
    } catch (_) {}
  }

  void _continue(TripSummaryModel t) => TripNavigation.continueTrip(t.id);

  void _open(HubTileConfig c) {
    if (c.route == AppRoutes.tripWhere) TripNavigation.openWhereToNext();
  }

  Widget _center(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: HubTokens.statusStrip,
      resizeToAvoidBottomInset: false,
      body: TabHeaderFrame(
        title: TripStringsHub.title,
        subtitle: TripStringsHub.headerSub,
        color: HubTokens.statusStrip,
        child: RefreshIndicator(
          color: HubTokens.accent,
          onRefresh: () async {
            _trips.load();
            await _warmCatalog(force: true);
          },
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              child: HubPageBackground(
                minHeight: box.maxHeight,
                child: _content(context),
              ),
            ),
          ),
        ),
      ),
    );
    return TabEntrance(tab: AppTabs.trips, child: page);
  }

  Widget _content(BuildContext context) {
    final tiles = HubTiles.visible();
    return _center(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final trips = _trips.continueTrips;
            return trips.isEmpty
                ? const SizedBox.shrink()
                : HubContinueBar(trips: trips.toList(), onContinue: _continue);
          }),
          Obx(() => HubSectionTitle(
                title: TripStringsHub.needTitle,
                sub: TripStringsHub.needSub,
                top: _trips.continueTrips.isEmpty ? 2 : 22,
              )),
          for (final (i, t) in tiles.indexed)
            Padding(
              padding: EdgeInsets.fromLTRB(DS.s(16), DS.gv(i == 0 ? 20 : 34), DS.s(16), 0),
              child: HubTile(
                key: ValueKey('hub-tile-${t.id}'),
                config: t,
                onTap: () => _open(t),
              ),
            ),
          SizedBox(height: BarMetrics.bodyBottomOf(context)),
        ],
      ),
    );
  }
}
