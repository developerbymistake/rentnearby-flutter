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
import '../widgets/trip_card.dart';
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
    _ctrl.pastOpen.value = false;
    _ctrl.load();
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

  static final ListingTone _tone = ListingTone.indigo;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final page = Scaffold(
      backgroundColor: ListingPalette.indigo.page,
      body: KitStatusBar(
        lightIcons: false,
        child: Column(
          children: [
            SizedBox(height: top),
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                color: _tone.g2,
                onRefresh: _ctrl.load,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildOfflineStrip(context),
                    _buildBody(context),
                    SliverToBoxAdapter(child: _buildFooter()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return widget.root ? TabEntrance(tab: AppTabs.trips, child: page) : page;
  }

  Widget _buildHeader(BuildContext context) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: widget.root
            ? ModuleTitleBar(tone: _tone, art: ListingArt.luggage, title: TripStrings.myTrips)
            : Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TopBar3D(tone: _tone, title: TripStrings.myTrips, onBack: () => Get.back()),
              ),
      );

  Widget _enter(int i, Widget child, [int total = _cap]) {
    final count = total < _cap ? total : _cap;
    return TemplateEntrance(
      animation: templateInterval(_anim, i < count ? i : count - 1, count),
      animationController: _anim,
      child: child,
    );
  }

  Widget _card(TripSummaryModel t, {bool past = false, Animation<double>? animation}) => TripCard(
        animation: animation,
        key: ValueKey('${past ? 'p' : 'a'}${t.id}'),
        trip: t,
        past: past,
        onOpen: () => _openPlan(t),
        onAction: () => _onAction(t, past: past),
        onShare: t.spotCount > 0 ? () => _share(t) : null,
        onDelete: () => _delete(t),
        onMarkComplete: past && !t.isCompleted ? () => TripLifecycleActions.markCompleteFromList(context, t) : null,
      );

  Widget _groupLabel(String text) => TitleRow3D(title: text, tone: _tone);

  Widget _pad(Widget child, [double top = 0]) =>
      Padding(padding: EdgeInsets.fromLTRB(18, top, 18, 0), child: child);

  Widget _pastToggle(int n) => _pad(InkWell(
        onTap: _ctrl.togglePast,
        borderRadius: CardRadius.chip,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  TripStringsBar.pastTrips(n),
                  style: Ink3D.text(16, FontWeight.w600, _tone.text, letterSpacing: 0.4),
                ),
              ),
              AnimatedRotation(
                turns: _ctrl.pastOpen.value ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.chevron_right_rounded, color: _tone.text),
              ),
            ],
          ),
        ),
      ));

  List<Widget> _pastSection() {
    final known = _ctrl.counts.value.completed;
    final n = known > _ctrl.past.length ? known : _ctrl.past.length;
    if (n == 0 && !_ctrl.pastOpen.value) return const [];
    final out = <Widget>[const SizedBox(height: 12), _pastToggle(n)];
    if (!_ctrl.pastOpen.value) return out;
    if (_ctrl.past.isEmpty) {
      if (_ctrl.pastLoading.value) {
        out.add(const WideCardSkeleton());
      } else if (_ctrl.pastFailed.value) {
        out.add(StateCard.error(
          title: TripStrings.tripsFailed,
          message: TripStrings.checkConnection,
          kit: KitTone.brand,
          actionLabel: TripStrings.retry,
          onAction: _ctrl.loadPast,
        ));
      } else {
        out.add(const StateCard(
          title: TripStringsBar.noPastTrips,
          message: TripStringsBar.noPastSub,
          kit: KitTone.brand,
          asset: ListingArt.luggage,
        ));
      }
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
        return SliverToBoxAdapter(
          child: const StateCard(
            title: TripStrings.plannerOff,
            message: TripStrings.plannerOffSubtitle,
            kit: KitTone.brand,
            asset: ListingArt.calendar,
          ),
        );
      }
      final side = _sidePad(context);
      if (_ctrl.active.isEmpty && _ctrl.isLoading.value) {
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 4, side, 0),
          sliver: SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, _) => const WideCardSkeleton(),
          ),
        );
      }
      final groups = _ctrl.groups;
      final children = <Widget>[];
      var idx = 0;
      if (groups.inProgress.isEmpty && groups.ready.isEmpty) {
        children.add(_enter(idx++, _groupLabel(TripStringsBar.inProgress)));
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
      for (final (label, list) in [
        (TripStringsBar.inProgress, groups.inProgress),
        (TripStringsBar.ready, groups.ready),
      ]) {
        if (list.isEmpty) continue;
        children.add(_enter(idx++, _groupLabel(TripStringsBar.groupHeader(label, list.length))));
        for (final t in list) {
          final a = templateInterval(_anim, idx < _cap ? idx : _cap - 1, _cap);
          idx++;
          children.add(TemplateEntrance(animation: a, animationController: _anim, child: _card(t, animation: a)));
        }
      }
      children.addAll(_pastSection());
      return SliverPadding(padding: EdgeInsets.fromLTRB(side, 4, side, 0), sliver: SliverList.list(children: children));
    });
  }

  Widget _buildOfflineStrip(BuildContext context) {
    return Obx(() {
      final at = _ctrl.offlineCopyAt.value;
      if (at == null || _ctrl.active.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _sidePad(context)),
          child: _enter(0, DisclaimerBanner(text: TripStringsA5.offlineCopy(TripFormat.time12Of(at)))),
        ),
      );
    });
  }

  static double _sidePad(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > 640 ? (w - 640) / 2 : 0;
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
