import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../widgets/empty_state_view.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../taxi_option_sets.dart';
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

class _MyJourneysScreenState extends State<MyJourneysScreen> with WidgetsBindingObserver {
  static const double _maxWidth = 720;

  final _ctrl = JourneysController.ensure();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        const JourneyHeader(title: TaxiWaysStrings.myJourneys),
        Obx(() => _ctrl.isOffline.value ? const JourneyOfflineBanner() : const SizedBox.shrink()),
        Expanded(child: Obx(_body)),
      ]),
    );
  }

  double _pad(double width) => math.max(14, (width - _maxWidth) / 2);

  Widget _scrollable(Widget child) => RefreshIndicator(
        color: TaxiColors.accent,
        onRefresh: () => _ctrl.load(force: true),
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(_pad(c.maxWidth), 14, _pad(c.maxWidth), 24 + AppInsets.bottomViewPadding(context)),
            children: [child],
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
            TripShimmers.rowBox(height: 120, radius: 18),
          ],
        ]));
      }
      if (_ctrl.loadFailed.value) {
        final offline = _ctrl.isOffline.value;
        return _scrollable(EmptyStateView(
          icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          title: offline ? TaxiWaysStrings.offlineTitle : JourneyStrings.loadFailed,
          subtitle: TaxiWaysStrings.offlineBody,
          palette: TaxiColors.palette,
          retryLabel: TaxiWaysStrings.retry,
          onRetry: () => _ctrl.load(force: true),
        ));
      }
      return _scrollable(const EmptyStateView(
        icon: Icons.alt_route_rounded,
        title: TaxiWaysStrings.noJourneys,
        subtitle: TaxiWaysStrings.noJourneysBody,
        palette: TaxiColors.palette,
      ));
    }
    return RefreshIndicator(
      color: TaxiColors.accent,
      onRefresh: () => _ctrl.load(force: true),
      child: LayoutBuilder(
        builder: (context, c) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(_pad(c.maxWidth), 14, _pad(c.maxWidth), 24 + AppInsets.bottomViewPadding(context)),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final j = list[i];
            return Obx(() => JourneyListCard(
                  journey: j,
                  busy: _ctrl.busyIds.contains(j.id),
                  onOpen: () => JourneyActions.openSaved(j.id),
                  onAsk: () => _ask(j),
                  onReplace: (leg, backup) => _ctrl.replaceDriver(j.id, leg.legIndex, backup.taxiId),
                ));
          },
        ),
      ),
    );
  }
}
