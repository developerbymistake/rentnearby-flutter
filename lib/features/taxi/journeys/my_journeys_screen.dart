import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        TemplateEntrance(
          animation: templateInterval(_anim, 0, 2),
          animationController: _anim,
          offset: 0,
          child: const JourneyHeader(title: TaxiWaysStrings.myJourneys),
        ),
        Obx(() => _ctrl.isOffline.value ? const JourneyOfflineBanner() : const SizedBox.shrink()),
        Expanded(child: Obx(_body)),
      ]),
    );
  }

  double _pad(double width) => math.max(14, (width - _maxWidth) / 2);

  Widget _scrollable(Widget child) => RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () => _ctrl.load(force: true),
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(_pad(c.maxWidth), 14, _pad(c.maxWidth), 24 + AppInsets.bottomViewPadding(context)),
            children: [_enter(0, child)],
          ),
        ),
      );

  Widget _body() {
    final list = _ctrl.journeys.toList();
    if (list.isEmpty) {
      if (_ctrl.isLoading.value) {
        return _scrollable(Column(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            const JourneySkeletonCard(),
          ],
        ]));
      }
      if (_ctrl.loadFailed.value) {
        final offline = _ctrl.isOffline.value;
        return _scrollable(TripPlanEmpty(
          image: offline ? TravelIcon.map : TravelIcon.note,
          title: offline ? TaxiWaysStrings.offlineTitle : JourneyStrings.loadFailed,
          subtitle: TaxiWaysStrings.offlineBody,
          retryLabel: TaxiWaysStrings.retry,
          onRetry: () => _ctrl.load(force: true),
        ));
      }
      return _scrollable(const TripPlanEmpty(
        image: TravelIcon.route,
        title: TaxiWaysStrings.noJourneys,
        subtitle: TaxiWaysStrings.noJourneysBody,
      ));
    }
    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: () => _ctrl.load(force: true),
      child: LayoutBuilder(
        builder: (context, c) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(_pad(c.maxWidth), 14, _pad(c.maxWidth), 24 + AppInsets.bottomViewPadding(context)),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final j = list[i];
            return _enter(
              i,
              Obx(() => JourneyListCard(
                    journey: j,
                    busy: _ctrl.busyIds.contains(j.id),
                    onOpen: () => JourneyActions.openSaved(j.id),
                    onAsk: () => _ask(j),
                    onReplace: (leg, backup) => _ctrl.replaceDriver(j.id, leg.legIndex, backup.taxiId),
                  )),
            );
          },
        ),
      ),
    );
  }
}
