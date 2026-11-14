import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../controllers/my_trips_controller.dart';
import '../models/trip_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_bar.dart';
import '../utils/trip_bar_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_summary_source.dart';
import '../utils/trip_summary_text.dart';
import '../trip_strings_hub_trips.dart';
import '../widgets/hub/hub_header.dart';
import '../widgets/hub/hub_page_background.dart';
import '../widgets/hub/hub_section_title.dart';
import '../widgets/hub/hub_tokens.dart';
import '../widgets/hub/hub_trip_card.dart';
import '../widgets/trip_lifecycle_actions.dart';

class MyTripsScreen extends StatefulWidget {
  final bool root;
  const MyTripsScreen({this.root = false, super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with TickerProviderStateMixin {
  late final MyTripsController _ctrl;
  final _scroll = ScrollController();
  Worker? _tabWorker;
  Worker? _loadWorker;
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  bool _played = false;
  bool _seen = false;

  void _play() {
    if (KitMotion.reduce(context)) {
      _anim.value = 1;
    } else {
      _anim.forward(from: 0);
    }
  }
  static const int _cap = 10;

  @override
  void initState() {
    super.initState();
    _ctrl = MyTripsController.to;
    _ctrl.load();
    _ctrl.pastOpen.value = true;
    if (_ctrl.past.isEmpty) _ctrl.loadPast();
    _scroll.addListener(_onScroll);
    _loadWorker = ever<bool>(_ctrl.isLoading, (loading) {
      if (!loading && !_played && mounted) {
        _played = true;
        _seen = !widget.root || TabEntrance.isActive(context);
        _play();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_played && !_ctrl.isLoading.value) {
        _played = true;
        _seen = !widget.root || TabEntrance.isActive(context);
        _play();
      }
    });
    if (widget.root) {
      _tabWorker = ever<int>(Get.find<AuthController>().tabIndex, (i) {
        if (i != AppTabs.trips) return;
        _ctrl.load();
        if (!_seen && _played && mounted) _play();
        _seen = true;
      });
    }
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _loadWorker?.dispose();
    _anim.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _ctrl.loadMore();
  }

  void _openPlan(TripSummaryModel t) {
    TripNavigation.openPlan(tripId: t.id)?.then((_) {
      if (mounted) _ctrl.load();
    });
  }

  void _onAction(TripSummaryModel t, {bool past = false}) {
    if (past || TripBarRules.isReady(t)) {
      TripNavigation.openSummary(t.id);
      return;
    }
    Get.toNamed(AppRoutes.tripPlan, arguments: TripBarRules.continueArgs(t))?.then((_) {
      if (mounted) _ctrl.load();
    });
  }

  Future<void> _share(TripSummaryModel t) async {
    try {
      final snap = await TripSummarySource.load(t.id);
      await SharePlus.instance
          .share(ShareParams(text: TripSummaryText.build(snap.record), subject: TripStrings.shareSubject(t.routeLine)));
    } catch (e) {
      if (TripSummarySource.isGone(e)) {
        _ctrl.removeLocal(t.id);
        AppToast.error(TripStringsA5.tripNotFoundShare);
      } else {
        AppToast.error(TripStringsA5.shareFailed);
      }
    }
  }

  Future<void> _delete(TripSummaryModel t) async {
    final rows = t.progress.rows;
    final stays = rows.where((r) => (r.state == TripRowState.confirmed || r.state == TripRowState.booked) && r.key.kind == TripEasyRowKind.stay).length;
    final taxis = rows.where((r) => (r.state == TripRowState.confirmed || r.state == TripRowState.booked) && r.key.kind == TripEasyRowKind.taxi).length;
    final ok = await TripLifecycleActions.confirmDelete(
      context,
      open: rows.fold<int>(0, (n, r) => n + r.askedCount),
      confirmed: stays,
      confirmedTaxis: taxis,
    );
    if (ok) await _ctrl.delete(t.id);
  }

  static const double _skeletonHeight = 250;

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: const Color(0xFFEEF1FD),
      body: KitStatusBar(
        lightIcons: false,
        child: LayoutBuilder(
          builder: (context, box) => RefreshIndicator(
            color: HubTokens.accent,
            onRefresh: _ctrl.load,
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              child: HubPageBackground(
                minHeight: box.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HubHeader(title: TripStrings.myTrips, back: true, minHeight: 96, titleTop: 26, onBack: Get.back),
                    _buildOfflineStrip(context),
                    _buildBody(context),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.root ? TabEntrance(tab: AppTabs.trips, child: page) : page;
  }

  Widget _enter(int i, Widget child, [int total = _cap]) {
    final count = total < _cap ? total : _cap;
    return TemplateEntrance(
      animation: templateInterval(_anim, i < count ? i : count - 1, count),
      animationController: _anim,
      child: child,
    );
  }

  Widget _card(TripSummaryModel t, {bool past = false}) => HubTripCard(
        key: ValueKey('${past ? 'p' : 'a'}${t.id}'),
        trip: t,
        past: past,
        onOpen: () => _openPlan(t),
        onAction: () => _onAction(t, past: past),
        onShare: t.spotCount > 0 ? () => _share(t) : null,
        onDelete: () => _delete(t),
        onMarkComplete: past && !t.isCompleted ? () => TripLifecycleActions.markCompleteFromList(context, t) : null,
      );

  Widget _pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 0), child: child);

  Widget _skeleton() => _pad(Container(
        height: _skeletonHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: HubTokens.cardRadius(68),
          boxShadow: HubTokens.cardShadow,
        ),
      ));

  List<Widget> _pastSection() {
    if (_ctrl.past.isEmpty && !_ctrl.pastLoading.value && !_ctrl.pastFailed.value) return const [];
    final out = <Widget>[const HubSectionTitle(title: TripStringsHubTrips.past, top: 28)];
    if (_ctrl.past.isEmpty) {
      out.add(_ctrl.pastLoading.value
          ? _skeleton()
          : StateCard.error(
              title: TripStrings.tripsFailed,
              message: TripStrings.checkConnection,
              kit: KitTone.brand,
              actionLabel: TripStrings.retry,
              onAction: _ctrl.loadPast,
            ));
      return out;
    }
    for (final t in _ctrl.past) {
      out.add(_card(t, past: true));
    }
    return out;
  }

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      if (_ctrl.plannerOff.value) {
        return const StateCard(
          title: TripStrings.plannerOff,
          message: TripStrings.plannerOffSubtitle,
          kit: KitTone.brand,
          asset: ListingArt.calendar,
        );
      }
      if (_ctrl.active.isEmpty && _ctrl.isLoading.value) {
        return Column(children: [_skeleton(), _skeleton(), _skeleton()]);
      }
      final groups = _ctrl.groups;
      final children = <Widget>[];
      var idx = 0;
      children.add(_enter(idx++, const HubSectionTitle(title: TripStringsHubTrips.active, top: 14)));
      if (groups.inProgress.isEmpty && groups.ready.isEmpty) {
        children.add(_enter(idx++, _ctrl.loadFailed.value
            ? StateCard.error(
                title: TripStrings.tripsFailed,
                message: TripStrings.checkConnection,
                kit: KitTone.brand,
                actionLabel: TripStrings.retry,
                onAction: _ctrl.load,
              )
            : StateCard(
                title: TripStringsBar.noActiveTrips,
                message: TripStrings.noTripsSubtitle,
                kit: KitTone.brand,
                asset: ListingArt.luggage,
                onAction: () => TripNavigation.openTripsTab(),
                actionLabel: TripStrings.planATrip,
              )));
      }
      for (final t in [...groups.inProgress, ...groups.ready]) {
        final i = idx++;
        children.add(_enter(i, _card(t)));
      }
      children.addAll(_pastSection());
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    });
  }

  Widget _buildOfflineStrip(BuildContext context) {
    return Obx(() {
      final at = _ctrl.offlineCopyAt.value;
      if (at == null || _ctrl.active.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _enter(0, DisclaimerBanner(text: TripStringsA5.offlineCopy(TripFormat.time12Of(at)))),
      );
    });
  }

  Widget _buildFooter() {
    return Obx(() => Padding(
          padding: EdgeInsets.only(top: 12, bottom: widget.root ? BarMetrics.bodyBottomOf(context) : 24),
          child: SizedBox(
            height: 24,
            child: _ctrl.isLoadingMore.value
                ? const Center(child: TemplatePlaceholder(height: 8, width: 60, radius: 4))
                : null,
          ),
        ));
  }
}
