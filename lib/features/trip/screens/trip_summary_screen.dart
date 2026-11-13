import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_mcd_k1.dart';
import '../trip_strings_steps_a3.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_format.dart';
import '../utils/trip_summary_source.dart';
import '../utils/trip_summary_text.dart';
import '../widgets/trip_journey_compact.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_summary_booking_card.dart';
import '../widgets/trip_summary_day_card.dart';
import '../widgets/trip_summary_hero.dart';
import '../widgets/trip_summary_leg_header.dart';
import '../widgets/trip_summary_stats.dart';
import '../widgets/trip_summary_todo.dart';
import '../trip_navigation.dart';
import '../widgets/trip_summary_travel_card.dart';

class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({super.key, this.tripId, this.loader, this.isGone, this.opener});

  final String? tripId;
  final Future<TripSummarySnapshot> Function(String tripId)? loader;
  final bool Function(Object error)? isGone;
  final Future<void>? Function(String tripId, String row)? opener;

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  late final AnimationController _list = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  late final List<Animation<double>> _slots = List.generate(9, (i) => templateInterval(_list, i, 9));

  @override
  void dispose() {
    _anim.dispose();
    _list.dispose();
    super.dispose();
  }

  Widget _in(int i, Widget child) =>
      TemplateEntrance(animation: _slots[i > 8 ? 8 : i], animationController: _list, child: child);

  List<Widget> _stagger(List<Widget> items) {
    var n = 0;
    return [for (final w in items) w is SizedBox ? w : _in(n++, w)];
  }

  static const double _maxWidth = 640;

  late final String _tripId;
  TripSummaryRecord? _record;
  DateTime? _cachedAt;
  bool _loading = true;
  bool _offline = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _tripId = widget.tripId ?? (args is Map ? (args['tripId'] as String? ?? '') : '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anim.forward();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final snap = await (widget.loader ?? TripSummarySource.load)(_tripId);
      if (!mounted) return;
      final first = _record == null;
      setState(() {
        _record = snap.record;
        _cachedAt = snap.cachedAt;
        _gone = false;
        _loading = false;
      });
      if (first) _list.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gone = (widget.isGone ?? TripSummarySource.isGone)(e);
        _offline = DioErrorMapper.isNetworkError(e);
        _loading = false;
      });
    }
  }

  Future<void> _openRow(TripEasyRowKey k) async {
    final open = widget.opener;
    await (open != null ? open(_tripId, k.id) : TripNavigation.openPlan(tripId: _tripId, row: k.id));
    if (mounted) await _load();
  }

  Future<void> _share() async {
    final r = _record;
    if (r == null) return;
    try {
      await SharePlus.instance.share(ShareParams(text: TripSummaryText.build(r), subject: TripStrings.shareSubject(r.routeLine)));
    } catch (_) {
      AppToast.error(TripStringsA5.shareFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final canShare = r != null && !_gone && TripSummaryText.canShare(r);
    return Container(
      color: DesignColors.scaffold,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            TemplateEntrance(animation: templateInterval(_anim, 0, 2), animationController: _anim, child: _header(context, r)),
            Expanded(child: _body(r)),
            if (canShare) _in(8, _shareBar(context)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, TripSummaryRecord? r) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ModuleHeader(
          title: TripStrings.summary,
          subtitle: r != null && !_gone ? TripSummaryText.headerLine(r) : null,
          subtitleLines: 2,
          autoHeight: true,
          tone: KitTone.brand,
          gradient: ListingTone.indigo.gradient,
          onBack: () => Get.back(),
        ),
      );

  Widget _column(List<Widget> children) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 24), children: children),
      ),
    );
  }

  Widget _body(TripSummaryRecord? r) {
    final tone = ListingTone.indigo;
    if (_gone) return const TripNotFoundView();
    if (_loading && r == null) {
      return _column([for (var i = 0; i < 3; i++) const WideCardSkeleton()]);
    }
    if (r == null) {
      return _column([
        const SizedBox(height: 40),
        StateCard3D(
          tone: tone,
          art: ListingArt.worldMap,
          layout: StateLayout.plain,
          title: _offline ? TripStrings.noNetworkTitle : TripStrings.couldNotLoad,
          message: TripStrings.checkConnection,
          actionLabel: TripStrings.retry,
          onAction: _load,
        ),
      ]);
    }
    if (!TripSummaryText.hasContent(r)) {
      return _column([
        const SizedBox(height: 40),
        StateCard3D(
          tone: tone,
          art: ListingArt.clipboard,
          layout: StateLayout.plain,
          title: TripStringsA5.nothingHere,
          message: TripStringsA5.nothingHereSub,
        ),
      ]);
    }
    final days = r.days.where((d) => d.spots.isNotEmpty).toList();
    return RefreshIndicator(
      color: tone.g2,
      backgroundColor: DesignColors.surface,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _stagger([
                    if (_cachedAt != null) _offlineStrip(_cachedAt!),
                    TripSummaryHero(record: r),
                    TripSummaryStats(record: r),
                    if (r.shownRows.isNotEmpty && !r.isCompleted) TripSummaryTodo(record: r, onOpen: _openRow),
                    if (days.isNotEmpty) ...[
                      _section(TripStringsA5.itinerary),
                      for (final d in days) TripSummaryDayCard(day: d, stay: TripDayChips.stay(r, d), taxi: TripDayChips.taxi(r, d)),
                    ],
                    ..._arrangementSection(r),
                    ..._journeySection(r, TripStepRole.gettingThere),
                    if (r.isMultiCity)
                      for (final leg in r.legs) ..._legSection(leg)
                    else ...[
                      if (r.nights.isNotEmpty) ...[
                        _section(TripStringsA5.staysSection),
                        for (final n in r.nights) _nightCard(n),
                      ],
                      if (r.taxis.isNotEmpty) ...[
                        _section(TripStringsA5.taxisSection),
                        for (final t in r.taxis) _taxiCard(t),
                      ],
                    ],
                    ..._journeySection(r, TripStepRole.comingBack),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(TripSummaryText.footer(r), style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.4)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _legSection(TripSummaryLeg leg) {
    final travel = leg.travel;
    return [
      if (travel != null) TripSummaryTravelCard(travel),
      TripSummaryLegHeader(leg),
      for (final g in TripSummaryText.nightGroups(leg.nights)) g.isRange ? _nightGroupCard(g) : _nightCard(g.first),
      for (final t in leg.taxis) _taxiCard(t),
    ];
  }

  List<Widget> _arrangementSection(TripSummaryRecord r) {
    final rows = TripSummaryText.shownArrangements(r);
    if (rows.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
        child: Text(TripStringsV2Easy.arrangementsHeading,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w700, Ink3D.grey, letterSpacing: 1)),
      ),
      WhiteCard3D(
        child: Column(children: [for (var i = 0; i < rows.length; i++) _arrangementRow(rows[i], i > 0)]),
      ),
    ];
  }

  Widget _arrangementRow(TripSummaryArrangement a, bool divider) {
    final done = a.isDone;
    final detail = a.detailLine ?? '';
    return IconRow3D(
      art: TripSummaryTodo.artOf(a.key.kind),
      title: a.title,
      subtitle: detail.isEmpty ? null : detail,
      divider: divider,
      tone: ListingTone.indigo,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 110),
        child: Text(TripSummaryText.stateWord(a.state),
            maxLines: 2,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: Ink3D.text(12, FontWeight.w700, done ? TripLook.successText : TripLook.warningText)),
      ),
    );
  }

  List<Widget> _journeySection(TripSummaryRecord r, TripStepRole role) {
    final j = TripSummaryText.journeyOf(r, role);
    final status = r.steps.of(role).status;
    if (j == null || status == TripStepStatus.own || status == TripStepStatus.skipped) return const [];
    final going = role == TripStepRole.gettingThere;
    return [
      _section(going ? TripStringsStepsA3.gettingThereCaps : TripStringsStepsA3.comingBackCaps),
      TripSummaryBookingCard(
        tone: ListingTone.coral,
        art: going ? ListingArt.taxi : ListingArt.airplane,
        eyebrow: TripStrings.joinDots([TripFormat.shortDate(j.date), TripStringsStepsA3.carsLine(j.cars)]),
        title: TripStringsStepsA3.routeLine(j.places),
        body: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(14)),
          child: TripJourneyCompact(journey: j),
        ),
        payLine: TripStrings.taxiPayLine,
      ),
    ];
  }

  Widget _section(String text) => TitleRow3D(title: text, tone: ListingTone.indigo);

  Widget _offlineStrip(DateTime at) => Banner3D(
        kind: BannerKind.info,
        tone: ListingTone.indigo,
        art: ListingArt.worldMap,
        title: TripStringsA5.offlineCopy(TripFormat.time12Of(at)),
      );

  Widget _nightGroupCard(TripSummaryNightGroup g) => _nightCard(
        g.first,
        heading: TripStringsMcdK1.nightsRange(g.first.night, g.last.night),
        subtitle: TripStringsMcdK1.baseStayLine(g.first.listingName, TripSummaryText.checkOutOf(g.last.date)),
        agreedTotal: g.agreedTotal,
      );

  Widget _nightCard(TripSummaryNight n, {String? heading, String? subtitle, int? agreedTotal}) {
    final date = n.date == null ? '' : TripFormat.shortDate(n.date!);
    heading ??= TripStringsA5.nightHeading(n.night, date, TripSummaryText.checkOutOf(n.date));
    final agreed = agreedTotal ?? n.agreedTotal;
    final status = n.display;
    final label = n.isCancelled ? TripSummaryText.statusLabel(n.display, n.cancelledBy ?? 'owner') : null;
    return TripSummaryBookingCard(
      tone: ListingTone.forest,
      art: ListingArt.hotel,
      eyebrow: heading,
      title: subtitle ?? n.listingName,
      pill: TripSummaryBookingCard.statusPill(status, label: label),
      rows: [
        for (final room in n.roomLines) (TripStrings.room, TripSummaryText.roomLine(room)),
        if (agreed != null) (TripStrings.agreed, BrowseItem.inr(agreed)),
        (TripStrings.advance, TripSummaryText.advanceLine(n)),
        if ((n.cancellationText ?? '').isNotEmpty) (TripStrings.cancellationTerms, n.cancellationText!),
        if (n.gstInvoice != null) (TripStrings.gstInvoice, n.gstInvoice! ? TripStrings.yes : TripStrings.no),
        (TripStrings.confirmedLabel, n.confirmedLine()),
      ],
      payLine: TripStrings.stayPayLine,
    );
  }

  Widget _taxiCard(TripSummaryTaxi t) {
    final taxiName = t.listingName;
    final vehicle = (t.vehicleTypeName ?? '').isEmpty ? taxiName : '$taxiName · ${t.vehicleTypeName}';
    final status = t.display;
    final label = t.isCancelled ? TripSummaryText.statusLabel(t.display, t.cancelledBy ?? 'owner', taxi: true) : null;
    final fare = TripSummaryText.fareLine(t);
    final pickup = [
      if ((t.pickupTime ?? '').isNotEmpty) TripFormat.time12(t.pickupTime!),
      if ((t.pickupPlace ?? '').isNotEmpty) t.pickupPlace!,
    ].join(', ');
    return TripSummaryBookingCard(
      tone: ListingTone.coral,
      art: ListingArt.taxi,
      eyebrow: TripStrings.taxiCardTitle(TripSummaryText.taxiDays(t)),
      title: vehicle,
      pill: TripSummaryBookingCard.statusPill(status, taxi: true, label: label),
      rows: [
        if (fare.isNotEmpty) (TripStrings.fare, fare),
        if (pickup.isNotEmpty) (TripStrings.pickup, pickup),
        (TripStrings.confirmedLabel, t.confirmedLine()),
      ],
      payLine: TripStrings.taxiPayLine,
    );
  }

  Widget _shareBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: Ink3D.topEdge,
      ),
      padding: EdgeInsets.fromLTRB(18, 14, 18, 8 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientPillButton(tone: ListingTone.indigo, label: TripStringsA5.shareTrip, onTap: _share),
              Center(child: TextLink(label: TripStringsV2Easy.done, onTap: () => Get.back(), tone: KitTone.brand)),
            ],
          ),
        ),
      ),
    );
  }
}
