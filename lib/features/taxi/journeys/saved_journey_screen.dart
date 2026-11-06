import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../widgets/empty_state_view.dart';
import '../../trip/trip_strings_mcb_a3.dart';
import '../../trip/trip_strings_steps_a3.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_payment_line.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../taxi_option_sets.dart';
import '../ways/taxi_ways_strings.dart';
import 'journey_actions.dart';
import 'journey_models.dart';
import 'journey_strings.dart';
import 'journeys_controller.dart';
import 'widgets/journey_header.dart';
import 'widgets/journey_leg_card.dart';
import 'widgets/journey_rail_row.dart';
import 'widgets/journey_status_banner.dart';
import 'widgets/journey_trip_strip.dart';

class SavedJourneyScreen extends StatefulWidget {
  final String? journeyId;

  const SavedJourneyScreen({super.key, this.journeyId});

  @override
  State<SavedJourneyScreen> createState() => _SavedJourneyScreenState();
}

class _SavedJourneyScreenState extends State<SavedJourneyScreen> with WidgetsBindingObserver {
  static const double _maxWidth = 720;
  static const List<Color> _legColors = [AppColors.tripDark, AppColors.taxiDark, AppColors.primary];

  final _ctrl = JourneysController.ensure();
  String? _id;
  bool _idRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_idRead) return;
    _idRead = true;
    _id = widget.journeyId ?? _argId(ModalRoute.of(context)?.settings.arguments);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoRefresh();
  }

  static String? _argId(Object? a) {
    if (a is Map) return (a['journeyId'] ?? a['id'])?.toString();
    return a is String && a.isNotEmpty ? a : null;
  }

  Future<void> _open() async {
    final id = _id;
    if (id == null) return;
    if (_ctrl.byId(id) == null) await _ctrl.load(force: true);
    if (!mounted) return;
    _autoRefresh();
  }

  void _autoRefresh() {
    final id = _id;
    final j = id == null ? null : _ctrl.byId(id);
    if (id == null || j == null || j.isCompleted) return;
    final at = j.lastRefreshedAt;
    if (at == null || DateTime.now().difference(at) > JourneysController.staleAfter) {
      _ctrl.refreshOne(id, silent: true);
    }
  }

  Color _color(int legIndex) => _legColors[(legIndex - 1).abs() % _legColors.length];

  double _pad(double width) => math.max(14, (width - _maxWidth) / 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Obx(() {
        final id = _id;
        final j = id == null ? null : _ctrl.byId(id);
        final busy = id != null && _ctrl.busyIds.contains(id);
        final offline = _ctrl.isOffline.value;
        final loading = _ctrl.isLoading.value;
        return Column(children: [
          _header(j, id, busy),
          if (offline) const JourneyOfflineBanner(),
          Expanded(child: j == null ? _missing(loading) : _content(j, busy)),
          if (j != null && !j.isCompleted) _askBar(j, busy),
        ]);
      }),
    );
  }

  Widget _header(SavedJourney? j, String? id, bool busy) {
    return JourneyHeader(
      title: TaxiWaysStrings.savedJourney,
      subtitle: j == null ? null : '${JourneyFormat.route(j)} · ${TripFormat.shortDate(j.date)}',
      chips: [
        Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.phone_android_rounded, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                TaxiWaysStrings.savedOnPhone,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ]),
        ),
        if (j?.tripId != null)
          Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
            child: Text(
              _tripChip(j!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        if (j != null && id != null)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: busy ? null : () => _ctrl.refreshOne(id),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: TaxiColors.accentDark),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16, color: TaxiColors.accentDark),
                const SizedBox(width: 6),
                const Text(
                  TaxiWaysStrings.refresh,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TaxiColors.accentDark),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  static String _tripChip(SavedJourney j) {
    final day = j.tripTravelDay;
    return j.isSegment && day != null ? TripStringsMcbA3.inYourTrip(day) : TripStringsStepsA3.inYourTrip;
  }

  Widget _missing(bool loading) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          TripShimmers.rowBox(height: 56, radius: 14),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 150, radius: 16),
        ]),
      );
    }
    return SingleChildScrollView(
      child: EmptyStateView(
        icon: Icons.alt_route_rounded,
        title: JourneyStrings.notFoundTitle,
        subtitle: JourneyStrings.notFoundBody,
        onRetry: _id == null ? null : () => _ctrl.load(force: true).then((_) => _autoRefresh()),
        palette: TaxiColors.palette,
      ),
    );
  }

  Widget _content(SavedJourney j, bool busy) {
    final legs = j.legs;
    final total = j.listedTotal ?? legs.fold<int>(0, (sum, l) => sum + (l.listedFare ?? 0));
    final checked = JourneyFormat.checked(j, DateTime.now());
    final footer = [if (checked != null) checked, TaxiWaysStrings.worksOffline].join(' · ');
    final canChange = !j.isCompleted;
    final rows = <Widget>[];
    if (legs.isNotEmpty) {
      final first = _color(legs.first.legIndex);
      rows.add(JourneyRailRow(
        marker: JourneyDot(color: first),
        bottomColor: first,
        child: JourneyStop(
          title: legs.first.fromName,
          subtitle: '${TaxiWaysStrings.youStart} · ${TripFormat.shortDate(j.date)}',
        ),
      ));
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final c = _color(leg.legIndex);
        rows.add(JourneyRailRow(
          marker: const SizedBox.shrink(),
          topColor: c,
          bottomColor: c,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              JourneyLegCard(
                leg: leg,
                people: j.people,
                color: c,
                busy: busy,
                canChange: canChange,
                onChangeDriver: () => JourneyActions.changeDriver(context, j, leg),
                onReplace: (backup) => _ctrl.replaceDriver(j.id, leg.legIndex, backup.taxiId),
              ),
              if (j.tripId != null) JourneyCarBookRow(journey: j, leg: leg),
            ]),
          ),
        ));
        if (i < legs.length - 1) {
          final next = legs[i + 1];
          rows.add(JourneyRailRow(
            marker: const JourneyChangeDot(),
            topColor: c,
            bottomColor: _color(next.legIndex),
            child: JourneyStop(
              title: next.meetingPlace ?? leg.toName,
              subtitle: TaxiWaysStrings.meetNext,
              tag: TaxiWaysStrings.changeCarHere,
            ),
          ));
        }
      }
      final last = _color(legs.last.legIndex);
      rows.add(JourneyRailRow(
        marker: JourneyDot(color: last),
        topColor: last,
        child: JourneyStop(title: legs.last.toName, subtitle: TaxiWaysStrings.youArrive),
      ));
    }

    return RefreshIndicator(
      color: TaxiColors.accent,
      onRefresh: () => _ctrl.refreshOne(j.id),
      child: LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(_pad(c.maxWidth), 12, _pad(c.maxWidth), 24 + AppInsets.bottomViewPadding(context)),
          children: [
            if (j.isSegment) ...[
              JourneyTripStrip(journey: j),
              const SizedBox(height: 12),
            ],
            if (j.hasUnavailable && !j.isCompleted) ...[
              JourneyStatusBanner(
                journey: j,
                busy: busy,
                onReplace: (leg, backup) => _ctrl.replaceDriver(j.id, leg.legIndex, backup.taxiId),
                onChange: (leg) => JourneyActions.changeDriver(context, j, leg),
              ),
              const SizedBox(height: 12),
            ],
            ...rows,
            if (total > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TaxiColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    TaxiWaysStrings.carsAbout(legs.fold(0, (sum, l) => sum + l.carsOf(j.people)), total),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  const Text(TaxiWaysStrings.listedFares, style: TextStyle(fontSize: 11.5, color: AppColors.textLight)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Text(footer, style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textLight)),
            const SizedBox(height: 16),
            _manage(j, busy),
          ],
        ),
      ),
    );
  }

  Widget _manage(SavedJourney j, bool busy) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
    );
    return Row(children: [
      if (!j.isCompleted) ...[
        Expanded(
          child: OutlinedButton(
            style: style.copyWith(
              foregroundColor: const WidgetStatePropertyAll(TaxiColors.accentDark),
              side: const WidgetStatePropertyAll(BorderSide(color: AppColors.divider)),
            ),
            onPressed: busy ? null : () => _ctrl.complete(j.id),
            child: const Text(TaxiWaysStrings.markDone, maxLines: 2, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: OutlinedButton(
          style: style.copyWith(
            foregroundColor: const WidgetStatePropertyAll(AppColors.error),
            side: const WidgetStatePropertyAll(BorderSide(color: AppColors.errorSurface)),
          ),
          onPressed: busy ? null : () => _delete(j),
          child: const Text(TaxiWaysStrings.deleteJourney, maxLines: 2, textAlign: TextAlign.center),
        ),
      ),
    ]);
  }

  Future<void> _delete(SavedJourney j) async {
    final removed = await JourneyActions.confirmDelete(context, j);
    if (removed && mounted) Get.back();
  }

  Widget _askBar(SavedJourney j, bool busy) {
    final enabled = !j.hasUnavailable && !busy && j.legs.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + AppInsets.bottomViewPadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: TaxiColors.accentDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.divider,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              onPressed: enabled ? () => JourneyActions.ask(context, j) : null,
              child: Text(JourneyFormat.askLabel(j), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 6),
            const TripPaymentLine(text: TaxiWaysStrings.payLine),
          ]),
        ),
      ),
    );
  }
}
