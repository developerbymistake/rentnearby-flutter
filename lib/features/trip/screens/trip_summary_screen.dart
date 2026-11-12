import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
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
import '../widgets/trip_payment_line.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_status_card.dart';
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
      color: FitnessAppTheme.background,
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

  Widget _header(BuildContext context, TripSummaryRecord? r) => ModuleHeader(
        title: TripStrings.summary,
        subtitle: r != null && !_gone ? TripSummaryText.headerLine(r) : null,
        subtitleLines: 2,
        autoHeight: true,
        tone: KitTone.trip,
        onBack: () => Get.back(),
      );

  Widget _column(List<Widget> children, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 16, 16, 24)}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: ListView(padding: padding, children: children),
      ),
    );
  }

  Widget _body(TripSummaryRecord? r) {
    if (_gone) return const TripNotFoundView();
    if (_loading && r == null) {
      return _column([for (var i = 0; i < 3; i++) const TripSkeletonCard()]);
    }
    if (r == null) {
      return _column([
        TripEmpty(
          asset: TravelIcon.map,
          title: _offline ? TripStrings.noNetworkTitle : TripStrings.couldNotLoad,
          subtitle: TripStrings.checkConnection,
          onRetry: _load,
        ),
      ]);
    }
    if (!TripSummaryText.hasContent(r)) {
      return _column([
        const TripEmpty(
          asset: TravelIcon.note,
          title: TripStringsA5.nothingHere,
          subtitle: TripStringsA5.nothingHereSub,
        ),
      ]);
    }
    final days = r.days.where((d) => d.spots.isNotEmpty).toList();
    return RefreshIndicator(
      color: FitnessAppTheme.nearlyDarkBlue,
      backgroundColor: FitnessAppTheme.white,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _stagger([
                    if (_cachedAt != null) ...[_offlineStrip(_cachedAt!), const SizedBox(height: 12)],
                    TripSummaryHero(record: r),
                    const SizedBox(height: 12),
                    TripSummaryStats(record: r),
                    const SizedBox(height: 12),
                    if (r.shownRows.isNotEmpty && !r.isCompleted) ...[
                      TripSummaryTodo(record: r, onOpen: _openRow),
                      const SizedBox(height: 12),
                    ],
                    if (days.isNotEmpty) ...[
                      _section(TripStringsA5.itinerary),
                      for (final d in days) ...[
                        TripSummaryDayCard(day: d, stay: TripDayChips.stay(r, d), taxi: TripDayChips.taxi(r, d)),
                        const SizedBox(height: 12),
                      ],
                    ],
                    ..._arrangementSection(r),
                    ..._journeySection(r, TripStepRole.gettingThere),
                    if (r.isMultiCity)
                      for (final leg in r.legs) ..._legSection(leg)
                    else ...[
                      if (r.nights.isNotEmpty) ...[
                        _section(TripStringsA5.staysSection),
                        for (final n in r.nights) ...[_nightCard(n), const SizedBox(height: 12)],
                      ],
                      if (r.taxis.isNotEmpty) ...[
                        _section(TripStringsA5.taxisSection),
                        for (final t in r.taxis) ...[_taxiCard(t), const SizedBox(height: 12)],
                      ],
                    ],
                    ..._journeySection(r, TripStepRole.comingBack),
                    const SizedBox(height: 12),
                    Text(
                      TripSummaryText.footer(r),
                      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: TripLook.textLight, height: 1.35),
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
      if (travel != null) ...[TripSummaryTravelCard(travel), const SizedBox(height: 12)],
      TripSummaryLegHeader(leg),
      for (final g in TripSummaryText.nightGroups(leg.nights)) ...[
        g.isRange ? _nightGroupCard(g) : _nightCard(g.first),
        const SizedBox(height: 12),
      ],
      for (final t in leg.taxis) ...[_taxiCard(t), const SizedBox(height: 12)],
    ];
  }

  List<Widget> _arrangementSection(TripSummaryRecord r) {
    final rows = TripSummaryText.shownArrangements(r);
    if (rows.isEmpty) return const [];
    return [
      _section(TripStringsV2Easy.arrangementsHeading),
      TripStatusCard(
        status: TripDisplayStatus.none,
        child: Column(children: [for (final a in rows) _arrangementRow(a)]),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _arrangementRow(TripSummaryArrangement a) {
    final done = a.isDone;
    final detail = a.detailLine ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TravelIcon(done ? TravelIcon.star : TravelIcon.calendar, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 13.5, fontWeight: FontWeight.w600, color: TripLook.textDark)),
                if (detail.isNotEmpty)
                  Text(detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textMedium)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(TripSummaryText.stateWord(a.state),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: FitnessAppTheme.fontName,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: done ? TripLook.successText : TripLook.warningText)),
          ),
        ],
      ),
    );
  }

  List<Widget> _journeySection(TripSummaryRecord r, TripStepRole role) {
    final j = TripSummaryText.journeyOf(r, role);
    final status = r.steps.of(role).status;
    if (j == null || status == TripStepStatus.own || status == TripStepStatus.skipped) return const [];
    return [
      _section(role == TripStepRole.gettingThere ? TripStringsStepsA3.gettingThereCaps : TripStringsStepsA3.comingBackCaps),
      TripStatusCard(
        status: TripDisplayStatus.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              TripStringsStepsA3.routeLine(j.places),
              TripStrings.joinDots([TripFormat.shortDate(j.date), TripStringsStepsA3.carsLine(j.cars)]),
              const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            TripJourneyCompact(journey: j),
            const SizedBox(height: 10),
            const TripPaymentLine(text: TripStrings.taxiPayLine),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: TripLook.textLight),
        ),
      );

  Widget _offlineStrip(DateTime at) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(color: TripLook.neutralChip, borderRadius: TripLook.softRadius),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: TripLook.textMedium, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                TripStringsA5.offlineCopy(TripFormat.time12Of(at)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: TripLook.textMedium),
              ),
            ),
          ],
        ),
      );

  Widget _kv(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textLight),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: color ?? TripLook.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleRow(String title, String subtitle, Widget pill) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: TripLook.textDark),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textMedium),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: pill),
      ],
    );
  }

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
    return TripStatusCard(
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(heading, subtitle ?? n.listingName, TripStatusPill(status, label: label)),
          for (final room in n.roomLines) _kv(TripStrings.room, TripSummaryText.roomLine(room)),
          if (agreed != null) _kv(TripStrings.agreed, BrowseItem.inr(agreed)),
          _kv(TripStrings.advance, TripSummaryText.advanceLine(n)),
          if ((n.cancellationText ?? '').isNotEmpty) _kv(TripStrings.cancellationTerms, n.cancellationText!),
          if (n.gstInvoice != null) _kv(TripStrings.gstInvoice, n.gstInvoice! ? TripStrings.yes : TripStrings.no),
          _kv(TripStrings.confirmedLabel, n.confirmedLine()),
        ],
      ),
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
    return TripStatusCard(
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(
            TripStrings.taxiCardTitle(TripSummaryText.taxiDays(t)),
            vehicle,
            TripStatusPill(status, taxi: true, label: label),
          ),
          if (fare.isNotEmpty) _kv(TripStrings.fare, fare),
          if (pickup.isNotEmpty) _kv(TripStrings.pickup, pickup),
          _kv(TripStrings.confirmedLabel, t.confirmedLine()),
          const SizedBox(height: 10),
          const TripPaymentLine(text: TripStrings.taxiPayLine),
        ],
      ),
    );
  }

  Widget _shareBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.elev3,
      ),
      padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 12 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TripButton(
                onPressed: _share,
                label: TripStringsA5.shareTrip,
                height: 48,
              ),
              Center(child: TextLink(label: TripStringsV2Easy.done, onTap: () => Get.back(), tone: KitTone.trip)),
            ],
          ),
        ),
      ),
    );
  }
}
