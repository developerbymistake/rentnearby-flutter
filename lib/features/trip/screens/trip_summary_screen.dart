import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/gradient_button.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_colors.dart';
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
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_status_card.dart';
import '../widgets/trip_summary_leg_header.dart';
import '../widgets/trip_summary_travel_card.dart';

class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
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
    _tripId = args is Map ? (args['tripId'] as String? ?? '') : '';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final snap = await TripSummarySource.load(_tripId);
      if (!mounted) return;
      setState(() {
        _record = snap.record;
        _cachedAt = snap.cachedAt;
        _gone = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gone = TripSummarySource.isGone(e);
        _offline = DioErrorMapper.isNetworkError(e);
        _loading = false;
      });
    }
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _header(context, r),
          Expanded(child: _body(r)),
          if (canShare) _shareBar(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, TripSummaryRecord? r) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    TripStrings.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (r != null && !_gone)
                    Text(
                      TripSummaryText.headerLine(r),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      return _column([
        for (var i = 0; i < 3; i++) ...[TripShimmers.rowBox(height: 150, radius: 18), const SizedBox(height: 12)],
      ]);
    }
    if (r == null) {
      return _column([
        EmptyStateView(
          icon: Iconsax.cloud_cross,
          title: _offline ? TripStrings.noNetworkTitle : TripStrings.couldNotLoad,
          subtitle: TripStrings.checkConnection,
          onRetry: _load,
          palette: TripColors.palette,
        ),
      ]);
    }
    if (!TripSummaryText.hasContent(r)) {
      return _column([
        const EmptyStateView(
          icon: Iconsax.document_text,
          title: TripStringsA5.nothingHere,
          subtitle: TripStringsA5.nothingHereSub,
          palette: TripColors.palette,
        ),
      ]);
    }
    final days = r.days.where((d) => d.spots.isNotEmpty).toList();
    return RefreshIndicator(
      color: TripColors.accent,
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
                  children: [
                    if (_cachedAt != null) ...[_offlineStrip(_cachedAt!), const SizedBox(height: 12)],
                    if (days.isNotEmpty) ...[
                      _section(TripStringsA5.itinerary),
                      for (final d in days) ...[_dayCard(d), const SizedBox(height: 12)],
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
                    if (r.agreedTotal > 0) _totalStrip(r.agreedTotal),
                    const SizedBox(height: 12),
                    Text(
                      TripSummaryText.footer(r),
                      style: const TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.35),
                    ),
                  ],
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
    final done = TripSummaryText.isDone(a.state);
    final detail = (a.detail ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Iconsax.tick_circle5 : Iconsax.clock,
              size: 18, color: done ? AppColors.success : AppColors.warningText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                if (detail.isNotEmpty)
                  Text(detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(TripSummaryText.stateWord(a.state),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.successText : AppColors.warningText)),
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
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMedium),
        ),
      );

  Widget _offlineStrip(DateTime at) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Iconsax.cloud_cross, size: 16, color: AppColors.textMedium),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                TripStringsA5.offlineCopy(TripFormat.time12Of(at)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
            ),
          ],
        ),
      );

  Widget _dayCard(TripSummaryDay d) {
    final date = d.date == null ? null : TripFormat.shortDate(d.date!);
    return TripStatusCard(
      status: TripDisplayStatus.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.city == null ? TripStringsA5.dayHeading(d.day, date) : TripStringsV2Easy.dayInCity(d.day, d.city!),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          if (d.city != null && date != null)
            Text(
              date,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
            ),
          if (d.minutes > 0)
            Text(
              TripStringsA5.aboutDuration(TripFormat.duration(d.minutes)),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
            ),
          const SizedBox(height: 6),
          for (var i = 0; i < d.spots.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
                  ),
                  Expanded(
                    child: Text(d.spots[i],
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textDark)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: color ?? AppColors.textDark),
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
                    fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
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

  Widget _totalStrip(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: TripStatusColors.bothSurface, borderRadius: BorderRadius.circular(14)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          TripStrings.agreedInTotal(BrowseItem.inr(total)),
          maxLines: 1,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.successText),
        ),
      ),
    );
  }

  Widget _shareBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientButton(
                onPressed: _share,
                label: TripStringsA5.shareTrip,
                height: 48,
                gradient: TripColors.gradient,
                shadowColor: TripColors.accent,
              ),
              TextButton(
                onPressed: () => Get.back(),
                style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                child: const Text(TripStringsV2Easy.done,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
