import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../config/app_insets.dart';
import '../ways/taxi_ways_strings.dart';
import 'journey_actions.dart';
import 'journey_models.dart';
import 'journey_strings.dart';
import 'journeys_controller.dart';
import 'widgets/journey_header.dart';
import 'widgets/journey_list_card.dart';
import 'widgets/journey_status_banner.dart';

class MyJourneysScreen extends StatefulWidget {
  final String? journeyId;

  const MyJourneysScreen({super.key, this.journeyId});

  @override
  State<MyJourneysScreen> createState() => _MyJourneysScreenState();
}

class _MyJourneysScreenState extends State<MyJourneysScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  static const double _maxWidth = 720;
  static const int _count = 6;

  final _ctrl = JourneysController.ensure();
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim.forward();
    _ctrl.load();
    final id = widget.journeyId ?? _argId();
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) JourneyActions.openSaved(id);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.load();
  }

  String? _argId() {
    final a = Get.arguments;
    if (a is Map) return (a['journeyId'] ?? a['id'])?.toString();
    return a is String && a.isNotEmpty ? a : null;
  }

  Future<void> _ask(SavedJourney j) async {
    final ok = await JourneyActions.ask(context, j);
    if (ok && mounted) JourneyActions.openSaved(j.id);
  }

  Widget _enter(int i, Widget child) => TemplateEntrance(
        animation: templateInterval(_anim, math.min(i, _count - 1), _count),
        animationController: _anim,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: Column(children: [
        TemplateEntrance(
          animation: templateInterval(_anim, 0, 2),
          animationController: _anim,
          offset: 0,
          child: const JourneyHeader(title: TaxiWaysStrings.myJourneys),
        ),
        Expanded(child: Obx(_body)),
      ]),
    );
  }

  double _pad(double width) => math.max(0, (width - _maxWidth) / 2);

  Widget _scrollable(List<Widget> children) => RefreshIndicator(
        color: ListingPalette.coral.g2,
        onRefresh: () => _ctrl.load(force: true),
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(_pad(c.maxWidth), 0, _pad(c.maxWidth), 24 + AppInsets.bottomViewPadding(context)),
            children: [
              if (_ctrl.isOffline.value && !(_ctrl.journeys.isEmpty && _ctrl.loadFailed.value)) const JourneyOfflineBanner(),
              for (var i = 0; i < children.length; i++) _enter(i, children[i]),
            ],
          ),
        ),
      );

  Widget _body() {
    final list = _ctrl.journeys.toList();
    if (list.isEmpty) {
      if (_ctrl.isLoading.value) {
        return _scrollable([for (var i = 0; i < 3; i++) const JourneyCardSkeleton()]);
      }
      if (_ctrl.loadFailed.value) {
        final offline = _ctrl.isOffline.value;
        return _scrollable([
          JourneyEmpty3D(
            art: offline ? ListingArt.worldMap : ListingArt.clipboard,
            title: offline ? TaxiWaysStrings.offlineTitle : JourneyStrings.loadFailed,
            body: TaxiWaysStrings.offlineBody,
            actionLabel: TaxiWaysStrings.retry,
            onAction: () => _ctrl.load(force: true),
          ),
        ]);
      }
      return _scrollable(const [
        JourneyEmpty3D(art: ListingArt.compass, title: TaxiWaysStrings.noJourneys, body: TaxiWaysStrings.noJourneysBody),
      ]);
    }
    return _scrollable([
      for (final j in list)
        Obx(() => JourneyListCard(
              journey: j,
              busy: _ctrl.busyIds.contains(j.id),
              onOpen: () => JourneyActions.openSaved(j.id),
              onAsk: () => _ask(j),
              onReplace: (leg, backup) => _ctrl.replaceDriver(j.id, leg.legIndex, backup.taxiId),
            )),
    ]);
  }
}
