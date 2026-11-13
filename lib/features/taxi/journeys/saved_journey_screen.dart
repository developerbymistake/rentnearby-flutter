import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../config/app_insets.dart';
import '../../trip/trip_strings_mcb_a3.dart';
import '../../trip/trip_strings_steps_a3.dart';
import '../../trip/utils/trip_format.dart';
import '../ways/taxi_ways_strings.dart';
import 'journey_actions.dart';
import 'journey_models.dart';
import 'journey_strings.dart';
import 'journeys_controller.dart';
import 'widgets/journey_header.dart';
import 'widgets/journey_leg_card.dart';
import 'widgets/journey_status_banner.dart';
import 'widgets/journey_trip_strip.dart';

class SavedJourneyScreen extends StatefulWidget {
  final String? journeyId;

  const SavedJourneyScreen({super.key, this.journeyId});

  @override
  State<SavedJourneyScreen> createState() => _SavedJourneyScreenState();
}

class _SavedJourneyScreenState extends State<SavedJourneyScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  static const double _maxWidth = 720;
  static const int _count = 8;

  final _ctrl = JourneysController.ensure();
  String? _id;
  bool _idRead = false;
  bool _wasMissing = false;
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim.forward();
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
    _anim.dispose();
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

  Color _color(int legIndex) => journeyLegColor(legIndex);

  Widget _enter(int k, Widget child) => TemplateEntrance(
        animation: templateInterval(_anim, math.min(k, _count - 1), _count),
        animationController: _anim,
        child: child,
      );

  double _pad(double width) => math.max(0, (width - _maxWidth) / 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: Obx(() {
        final id = _id;
        final j = id == null ? null : _ctrl.byId(id);
        final busy = id != null && _ctrl.busyIds.contains(id);
        final offline = _ctrl.isOffline.value;
        final loading = _ctrl.isLoading.value;
        if (j == null) {
          _wasMissing = true;
        } else if (_wasMissing) {
          _wasMissing = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _anim.forward(from: 0);
          });
        }
        return Column(children: [
          if (j == null)
            TemplateEntrance(
              animation: templateInterval(_anim, 0, 2),
              animationController: _anim,
              offset: 0,
              child: _header(j, id, busy),
            ),
          Expanded(child: j == null ? _missing(loading, offline) : _content(j, busy, offline)),
          if (j != null && !j.isCompleted) _enter(_count - 2, _askBar(j, busy)),
        ]);
      }),
    );
  }

  Widget _header(SavedJourney? j, String? id, bool busy) {
    return JourneyHeader(
      title: TaxiWaysStrings.savedJourney,
      subtitle: j == null ? null : '${JourneyFormat.route(j)} · ${TripFormat.shortDate(j.date)}',
      bottom: j == null || id == null
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (j.tripId != null) ...[
                JourneyChip3D(label: _tripChip(j)),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(
                  child: Text(
                    TaxiWaysStrings.savedOnPhone,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12.5, FontWeight.w500, Ink3D.sub),
                  ),
                ),
                const SizedBox(width: 10),
                JourneyChip3D(
                  label: TaxiWaysStrings.refresh,
                  filled: true,
                  icon: Icons.refresh_rounded,
                  busy: busy,
                  onTap: () => _ctrl.refreshOne(id),
                ),
              ]),
            ]),
    );
  }

  static String _tripChip(SavedJourney j) {
    final day = j.tripTravelDay;
    return j.isSegment && day != null ? TripStringsMcbA3.inYourTrip(day) : TripStringsStepsA3.inYourTrip;
  }

  Widget _missing(bool loading, bool offline) {
    if (loading) {
      return ListView(padding: EdgeInsets.zero, children: [
        if (offline) const JourneyOfflineBanner(),
        const JourneyPillSkeleton(),
        const JourneyCardSkeleton(),
        const JourneyCardSkeleton(),
      ]);
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (offline) const JourneyOfflineBanner(),
        _enter(
          0,
          JourneyEmpty3D(
            art: ListingArt.compass,
            title: JourneyStrings.notFoundTitle,
            body: JourneyStrings.notFoundBody,
            actionLabel: _id == null ? null : TaxiWaysStrings.retry,
            onAction: _id == null ? null : () => _ctrl.load(force: true).then((_) => _autoRefresh()),
          ),
        ),
      ],
    );
  }

  Widget _content(SavedJourney j, bool busy, bool offline) {
    final legs = j.legs;
    final total = j.listedTotal ?? legs.fold<int>(0, (sum, l) => sum + (l.listedFare ?? 0));
    final checked = JourneyFormat.checked(j, DateTime.now());
    final footer = [?checked, TaxiWaysStrings.worksOffline].join(' · ');
    final canChange = !j.isCompleted;
    final rows = <Widget>[];
    Color line(SavedJourneyLeg l) => JourneyInk.lineFor(JourneyLegCard.toneOf(l));
    if (legs.isNotEmpty) {
      rows.add(JourneyStop3D(
        title: legs.first.fromName,
        subtitle: '${TaxiWaysStrings.youStart} · ${TripFormat.shortDate(j.date)}',
      ));
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        rows.add(JourneyLink3D(color: line(leg)));
        rows.add(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          JourneyLegCard(
            leg: leg,
            people: j.people,
            color: _color(leg.legIndex),
            legCount: legs.length,
            busy: busy,
            canChange: canChange,
            onChangeDriver: () => JourneyActions.changeDriver(context, j, leg),
            onReplace: (backup) => _ctrl.replaceDriver(j.id, leg.legIndex, backup.taxiId),
          ),
          if (j.tripId != null) JourneyCarBookRow(journey: j, leg: leg),
        ]));
        rows.add(Padding(padding: const EdgeInsets.only(top: 10), child: JourneyLink3D(color: line(leg))));
        if (i < legs.length - 1) {
          final next = legs[i + 1];
          rows.add(JourneyStop3D(
            top: 0,
            change: true,
            title: next.meetingPlace ?? leg.toName,
            tag: TaxiWaysStrings.changeCarHere,
            subtitle: TaxiWaysStrings.meetNext,
          ));
        }
      }
      rows.add(JourneyStop3D(top: 0, art: ListingArt.pushpin, title: legs.last.toName, subtitle: TaxiWaysStrings.youArrive));
    }

    return RefreshIndicator(
      color: ListingPalette.coral.g2,
      onRefresh: () => _ctrl.refreshOne(j.id),
      child: LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 24 + (j.isCompleted ? AppInsets.bottomViewPadding(context) : 0)),
          children: [
            TemplateEntrance(
              animation: templateInterval(_anim, 0, 2),
              animationController: _anim,
              offset: 0,
              child: _header(j, _id, busy),
            ),
            for (final w in _body(j, busy, offline, rows, total, footer, legs))
              Padding(padding: EdgeInsets.symmetric(horizontal: _pad(c.maxWidth)), child: w),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(SavedJourney j, bool busy, bool offline, List<Widget> rows, int total, String footer, List<SavedJourneyLeg> legs) => [
            if (offline) const JourneyOfflineBanner(),
            if (j.isSegment) _enter(0, JourneyTripStrip(journey: j)),
            if (j.hasUnavailable && !j.isCompleted)
              _enter(
                1,
                JourneyStatusBanner(
                  journey: j,
                  busy: busy,
                  onReplace: (leg, backup) => _ctrl.replaceDriver(j.id, leg.legIndex, backup.taxiId),
                  onChange: (leg) => JourneyActions.changeDriver(context, j, leg),
                ),
              ),
            for (var k = 0; k < rows.length; k++) _enter(k + 2, rows[k]),
            if (total > 0)
              _enter(
                _count - 3,
                JourneyTotalCard3D(
                  title: TaxiWaysStrings.carsAbout(legs.fold(0, (sum, l) => sum + l.carsOf(j.people)), total),
                  caption: TaxiWaysStrings.listedFares,
                ),
              ),
            _enter(
              _count - 2,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(footer, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.45)),
              ),
            ),
            _enter(_count - 1, Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _manage(j, busy))),
          ];

  Widget _manage(SavedJourney j, bool busy) {
    final tone = ListingTone.coral;
    final delete = WhitePillButton(
      tone: tone,
      label: TaxiWaysStrings.deleteJourney,
      danger: true,
      height: 52,
      fontSize: 15,
      onTap: busy ? null : () => _delete(j),
    );
    if (j.isCompleted) return delete;
    return PillButtonRow(children: [
      WhitePillButton(
        tone: tone,
        label: TaxiWaysStrings.markDone,
        height: 52,
        fontSize: 15,
        onTap: busy ? null : () => _ctrl.complete(j.id),
      ),
      delete,
    ]);
  }

  Future<void> _delete(SavedJourney j) async {
    final removed = await JourneyActions.confirmDelete(context, j);
    if (removed && mounted) Get.back();
  }

  Widget _askBar(SavedJourney j, bool busy) {
    final enabled = !j.hasUnavailable && !busy && j.legs.isNotEmpty;
    return JourneyDock3D(
      maxWidth: _maxWidth,
      children: [
        GradientPillButton(
          tone: ListingTone.coral,
          label: JourneyFormat.askLabel(j),
          height: 52,
          fontSize: 15,
          onTap: enabled ? () => JourneyActions.ask(context, j) : null,
        ),
        const JourneyPayLine(TaxiWaysStrings.payLine),
      ],
    );
  }
}
