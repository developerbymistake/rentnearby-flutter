import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../controllers/my_trips_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_hub.dart';
import '../utils/trip_bar_rules.dart';
import '../widgets/hub/hub_continue_bar.dart';
import '../widgets/hub/hub_header.dart';
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
  final _scrolled = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _trips = MyTripsController.to;
    _scroll.addListener(() => _scrolled.value = _scroll.hasClients && _scroll.offset > 0);
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
    _scrolled.dispose();
    super.dispose();
  }

  Future<void> _warmCatalog({bool force = false}) async {
    final catalog = TripCityCatalog.to;
    catalog.warmFromDisk();
    try {
      await catalog.load(force: force);
    } catch (_) {}
  }

  void _continue(TripSummaryModel t) {
    Get.toNamed(AppRoutes.tripPlan, arguments: TripBarRules.continueArgs(t))?.then((_) {
      if (mounted) _trips.load();
    });
  }

  void _open(HubTileConfig c) {
    if (c.route == AppRoutes.tripWhere) TripNavigation.openWhereToNext();
  }

  Widget _center(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    final page = Scaffold(
      backgroundColor: HubTokens.statusStrip,
      resizeToAvoidBottomInset: false,
      body: KitStatusBar(
        lightIcons: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: HubTokens.accent,
              edgeOffset: top,
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
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: top,
              child: ValueListenableBuilder<bool>(
                valueListenable: _scrolled,
                builder: (_, on, _) => on ? const ColoredBox(color: HubTokens.statusStrip) : const SizedBox.shrink(),
              ),
            ),
          ],
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
          const HubHeader(title: TripStringsHub.title, lead: TripStringsHub.lead),
          Obx(() {
            final trips = _trips.continueTrips;
            return trips.isEmpty
                ? const SizedBox.shrink()
                : HubContinueBar(trips: trips.toList(), onContinue: _continue);
          }),
          const HubSectionTitle(title: TripStringsHub.needTitle, sub: TripStringsHub.needSub, top: 22),
          for (final t in tiles)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
              child: HubTile(key: ValueKey('hub-tile-${t.id}'), config: t, onTap: () => _open(t)),
            ),
          SizedBox(height: BarMetrics.bodyBottomOf(context)),
        ],
      ),
    );
  }
}
