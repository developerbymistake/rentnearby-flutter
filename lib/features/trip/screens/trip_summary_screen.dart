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
import '../data/trip_repository.dart';
import '../models/trip_summary_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import '../utils/trip_summary_text.dart';
import '../widgets/trip_payment_line.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_status_card.dart';

class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  static const double _maxWidth = 640;

  final _repo = const TripRepository();
  late final String _tripId;
  TripSummaryRecord? _record;
  bool _loading = true;
  bool _failed = false;
  bool _offline = false;

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
      _failed = false;
    });
    try {
      final r = await _repo.summary(_tripId);
      if (!mounted) return;
      setState(() {
        _record = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _offline = DioErrorMapper.isNetworkError(e);
        _loading = false;
      });
    }
  }

  Future<void> _share() async {
    final r = _record;
    if (r == null) return;
    try {
      await SharePlus.instance.share(ShareParams(text: TripSummaryText.build(r), subject: TripStrings.shareSubject(r.city)));
    } catch (_) {
      AppToast.error(TripStrings.couldNotLoad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final canShare = r != null && !r.isEmpty;
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
                  if (r != null)
                    Text(
                      TripStrings.summaryHeader(r.city, TripSummaryText.datesOf(r), TripStrings.peopleCount(r.people)),
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
    if (_loading) {
      return _column([
        for (var i = 0; i < 3; i++) ...[TripShimmers.rowBox(height: 150, radius: 18), const SizedBox(height: 12)],
      ]);
    }
    if (_failed || r == null) {
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
    if (r.isEmpty) {
      return _column([
        const EmptyStateView(
          icon: Iconsax.document_text,
          title: TripStrings.nothingBookedYet,
          subtitle: TripStrings.nothingBookedSub,
          palette: TripColors.palette,
        ),
      ]);
    }
    return RefreshIndicator(
      color: TripColors.accent,
      onRefresh: _load,
      child: _column([
        for (final n in r.nights) ...[_nightCard(n), const SizedBox(height: 12)],
        for (final t in r.taxis) ...[_taxiCard(t), const SizedBox(height: 12)],
        if (r.agreedTotal > 0) _totalStrip(r.agreedTotal),
        const SizedBox(height: 12),
        const Text(
          TripStrings.summaryFooter,
          style: TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.35),
        ),
      ]),
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
                maxLines: 2,
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

  Widget _nightCard(TripSummaryNight n) {
    final date = n.date == null ? '' : TripFormat.shortDate(n.date!);
    final label = n.isOwn
        ? TripStrings.ownBookingShort
        : n.isCancelled
            ? TripSummaryText.statusLabel(n.display, n.cancelledBy ?? 'owner')
            : null;
    return TripStatusCard(
      status: n.display,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(TripStrings.nightCard(n.night, date), n.listingName, TripStatusPill(n.display, label: label)),
          if (n.isOwn && (n.ownPhone ?? '').isNotEmpty) _kv(TripStrings.call, n.ownPhone!),
          for (final room in n.roomLines) _kv(TripStrings.room, TripSummaryText.roomLine(room)),
          if (n.agreedTotal != null) _kv(TripStrings.agreed, BrowseItem.inr(n.agreedTotal!)),
          if (!n.isOwn) _kv(TripStrings.advance, TripSummaryText.advanceLine(n)),
          if ((n.cancellationText ?? '').isNotEmpty) _kv(TripStrings.cancellationTerms, n.cancellationText!),
          if (n.gstInvoice != null) _kv(TripStrings.gstInvoice, n.gstInvoice! ? TripStrings.yes : TripStrings.no),
          if (!n.isOwn) _kv(TripStrings.confirmedLabel, n.confirmedLine()),
        ],
      ),
    );
  }

  Widget _taxiCard(TripSummaryTaxi t) {
    final vehicle = (t.vehicleTypeName ?? '').isEmpty ? t.listingName : '${t.listingName} · ${t.vehicleTypeName}';
    final label = t.isOwn
        ? TripStrings.ownBookingShort
        : t.isCancelled
            ? TripSummaryText.statusLabel(t.display, t.cancelledBy ?? 'owner', taxi: true)
            : null;
    final fare = TripSummaryText.fareLine(t);
    final pickup = [
      if ((t.pickupTime ?? '').isNotEmpty) TripFormat.time12(t.pickupTime!),
      if ((t.pickupPlace ?? '').isNotEmpty) t.pickupPlace!,
    ].join(', ');
    return TripStatusCard(
      status: t.display,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(
            TripStrings.taxiCardTitle(TripSummaryText.taxiDays(t)),
            vehicle,
            TripStatusPill(t.display, taxi: true, label: label),
          ),
          if (t.isOwn && (t.ownPhone ?? '').isNotEmpty) _kv(TripStrings.call, t.ownPhone!),
          if (fare.isNotEmpty) _kv(TripStrings.fare, fare),
          if (pickup.isNotEmpty) _kv(TripStrings.pickup, pickup),
          if (!t.isOwn) _kv(TripStrings.confirmedLabel, t.confirmedLine()),
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
          child: GradientButton(
            onPressed: _share,
            label: TripStrings.shareAsText,
            height: 48,
            gradient: TripColors.gradient,
            shadowColor: TripColors.accent,
          ),
        ),
      ),
    );
  }
}
