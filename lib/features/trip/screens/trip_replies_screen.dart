import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_f2.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_report.dart';
import '../widgets/trip_accept_sheet.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_change_request_sheet.dart';
import '../widgets/trip_counter_sheet.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_status_card.dart';
import '../widgets/trip_withdraw_sheet.dart';
import 'trip_replies_leg_parts.dart';

class TripRepliesScreen extends StatefulWidget {
  const TripRepliesScreen({super.key});

  @override
  State<TripRepliesScreen> createState() => _TripRepliesScreenState();
}

const int _maxOpenAsks = 3;

class _Entry {
  final String stayId;
  final String name;
  final TripEnquiryModel? enquiry;
  const _Entry({required this.stayId, required this.name, this.enquiry});

  TripDisplayStatus get status => enquiry?.display ?? TripDisplayStatus.shortlisted;
}

class _TripRepliesScreenState extends State<TripRepliesScreen> {
  late final TripPlanController _c;
  late final int _day;
  String? _tripId;
  String? _enquiryId;
  bool _started = false;
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _c = TripPlanController.to;
    _c.openPages++;
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    final day = map['day'];
    _day = (day is num ? day.toInt() : int.tryParse('${day ?? ''}')) ?? 1;
    _tripId = map['tripId']?.toString();
    _enquiryId = map['enquiryId']?.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.openPages--;
      if (_c.openPages > 0) unawaited(_c.refreshEnquiries());
      _c.releaseIfIdle();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final id = _tripId;
    if (id != null && _c.trip.value?.id != id) {
      await _c.open(id);
    } else {
      await _c.refreshEnquiries();
    }
    if (!mounted) return;
    setState(() => _started = true);
    final stale = _c.stayEnquiriesOf(_legIndex).any((e) => e.display == TripDisplayStatus.offered && e.openOffer == null);
    if (stale && !_retried) {
      _retried = true;
      await _c.refreshEnquiries();
    }
  }

  int get _legIndex => _c.legIndexOf(_day);

  int get _rankDay {
    final id = _enquiryId;
    if (id == null) return _day;
    for (final e in _c.enquiries) {
      if (e.id == id) return _c.dayOfDate(e.checkIn) ?? e.day ?? _day;
    }
    return _day;
  }

  static int _rank(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.confirmedByBoth => 0,
        TripDisplayStatus.confirmedByYou => 1,
        TripDisplayStatus.offered => 2,
        TripDisplayStatus.asked => 3,
        TripDisplayStatus.shortlisted => 4,
        _ when s.isRed => 5,
        _ => 6,
      };

  List<_Entry> _entries() {
    final byStay = <String, TripEnquiryModel>{};
    final focus = _enquiryId;
    if (focus != null) {
      for (final e in _c.enquiries) {
        if (e.id == focus) byStay[e.listingId] = e;
      }
    }
    for (final e in _c.stayEnquiriesOf(_legIndex)) {
      byStay.putIfAbsent(e.listingId, () => e);
    }
    final out = <_Entry>[];
    for (final e in byStay.values) {
      out.add(_Entry(stayId: e.listingId, name: e.listingName, enquiry: e));
    }
    final indexed = out.asMap().entries.toList()
      ..sort((a, b) {
        final r = _rank(a.value.status).compareTo(_rank(b.value.status));
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return [for (final x in indexed) x.value];
  }

  String? _phone(_Entry x) {
    final raw = x.enquiry?.owner.phone;
    if (raw != null && ContactLauncher.tenDigits(raw).isNotEmpty) return raw;
    if (!Get.isRegistered<TripSupplyController>()) return null;
    for (final s in Get.find<TripSupplyController>().stays) {
      final p = s.ownerPhone;
      if (s.id == x.stayId && p != null && ContactLauncher.tenDigits(p).isNotEmpty) return p;
    }
    return null;
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String _inr(int? v) => v == null || v <= 0 ? '' : BrowseItem.inr(v);

  String _label(_Entry x) {
    final e = x.enquiry;
    if (e == null) return TripStrings.shortlisted;
    if (e.display == TripDisplayStatus.cancelled && e.cancelledBy == 'owner') return TripStrings.hostCancelled;
    if (e.display == TripDisplayStatus.closed) {
      return switch (e.failReason) {
        'Withdrawn' => TripStrings.withdrawn,
        'BookedElsewhere' => TripStrings.bookedAnother,
        _ => TripStrings.closed,
      };
    }
    return TripStatusVisuals.label(e.display);
  }

  String _statusLine(_Entry x) {
    final e = x.enquiry;
    if (e == null) return '';
    final now = DateTime.now();
    final counter = e.pendingCounter;
    if (counter != null && e.display.isOpen && !e.isBooked) {
      return TripStringsF2.youProposed(_inr(counter.pricePerNight));
    }
    return switch (e.display) {
      TripDisplayStatus.asked => TripStrings.askedAgo(_ago(e.createdAt)),
      TripDisplayStatus.offered => e.openOffer == null
          ? TripStrings.offerReceived
          : TripStrings.offeredValid(
              _inr(e.openOffer!.total),
              e.openOffer!.validUntil == null
                  ? ''
                  : TripEnquiryRules.closesInLabel(e.openOffer!.validUntil!, now)),
      TripDisplayStatus.confirmedByBoth when e.advanceLabel != null => e.advanceLabel!,
      TripDisplayStatus.confirmedByYou ||
      TripDisplayStatus.confirmedByBoth =>
        [e.datesLabel, _inr(e.agreedTotal)].where((s) => s.isNotEmpty).join(' · '),
      TripDisplayStatus.holdExpired => TripStrings.hostDidNotConfirm,
      _ => e.datesLabel,
    };
  }

  Future<void> _decline(TripEnquiryModel e) async {
    final offer = e.openOffer;
    if (offer == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStrings.declineQuestion,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text(TripStrings.declineNote, style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(TripStrings.keep, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStrings.decline,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) await TripEnquiryController.to.decline(e.id, offer.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 20, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Obx(() {
              _c.plan.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    TripStrings.stayReplies,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  if (TripRepliesLegParts.legLine(_c, _rankDay) case final leg?) ...[
                    const SizedBox(height: 2),
                    TripRepliesLegParts.legLineText(leg),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final date = _c.dateOf(_rankDay);
    final city = _c.legOf(_rankDay).cityName;
    if (date == null) return city.isEmpty ? _c.cityName : city;
    final days = _c.legDays(_c.legIndexOf(_rankDay));
    final first = days.isEmpty ? null : _c.dateOf(days.first);
    final last = days.isEmpty ? null : _c.dateOf(days.last);
    final from = first ?? date;
    final to = last == null ? date : DateTime(last.year, last.month, last.day + 1);
    return [city.isEmpty ? _c.cityName : city, TripFormat.dayMonthRange(from, to), _c.settings.peopleSummary]
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .join(' · ');
  }

  Widget _scroll(List<Widget> children) => RefreshIndicator(
        color: TripColors.accent,
        onRefresh: _c.refreshEnquiries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            for (final w in children)
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: w)),
          ],
        ),
      );

  Widget _buildBody() {
    return Obx(() {
      if (_c.tripGone.value) return const TripNotFoundView();
      if (_c.plannerOff.value) {
        return _scroll(const [
          EmptyStateView(
            icon: Iconsax.routing_2,
            title: TripStrings.plannerOff,
            subtitle: TripStrings.plannerOffSubtitle,
            palette: TripColors.palette,
          ),
        ]);
      }
      final plan = _c.plan.value;
      _c.enquiryList.length;
      TripEnquiryController.to.busyIds.length;
      if (plan == null && _c.openFailed.value) {
        return _scroll([
          EmptyStateView(
            icon: Iconsax.cloud_cross,
            title: TripStrings.couldNotLoad,
            subtitle: TripStrings.checkConnection,
            onRetry: _load,
            palette: TripColors.palette,
          ),
        ]);
      }
      final entries = plan == null ? const <_Entry>[] : _entries();
      if (plan == null || (entries.isEmpty && (!_started || _c.enquiriesLoading.value))) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => TripShimmers.rowBox(height: 120, radius: 18),
        );
      }
      if (entries.isEmpty && _c.enquiriesFailed.value) {
        return _scroll([
          EmptyStateView(
            icon: Iconsax.cloud_cross,
            title: TripStrings.couldNotLoad,
            subtitle: TripStrings.checkConnection,
            onRetry: _c.refreshEnquiries,
            palette: TripColors.palette,
          ),
        ]);
      }
      if (entries.isEmpty) {
        return _scroll(const [
          EmptyStateView(
            icon: Iconsax.message_question,
            title: TripStrings.noRepliesYet,
            subtitle: TripStrings.hostsReply,
            palette: TripColors.palette,
          ),
        ]);
      }
      final nothingToAsk = !_c.isCompleted && entries.every((x) => x.enquiry?.isRed ?? false);
      return _scroll([
        if (nothingToAsk) ...[
          _nothingToAsk(),
          const SizedBox(height: 12),
        ],
        for (final x in entries) ...[
          _card(x),
          const SizedBox(height: 12),
        ],
        if (_canAskAnother(entries)) _askAnotherButton(),
      ]);
    });
  }

  bool _canAskAnother(List<_Entry> entries) {
    if (_c.isReadOnly || _c.isDayPast(_day)) return false;
    if (entries.any((x) => x.enquiry?.isBooked ?? false)) return false;
    return entries.where((x) => x.enquiry?.display.isOpen ?? false).length < _maxOpenAsks;
  }

  Widget _askAnotherButton() => SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () => TripNavigation.openStay(_legIndex),
          icon: const Icon(Iconsax.add_circle, size: 18, color: TripColors.accentDark),
          label: const Text(
            TripStringsA5.askAnotherStay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: TripColors.accentDark),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: BorderSide(color: TripColors.accent.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _nothingToAsk() => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(color: TripStatusColors.failedSurface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Iconsax.warning_2, size: 16, color: TripStatusColors.failed),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  TripStrings.allAsksEnded,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.errorText),
                ),
              ),
            ),
            TextButton(
              onPressed: () => TripNavigation.openStay(_legIndex),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text(
                TripStrings.findAnother,
                maxLines: 1,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripStatusColors.failed),
              ),
            ),
          ],
        ),
      );

  Widget _card(_Entry x) {
    final e = x.enquiry;
    final status = x.status;
    final line = _statusLine(x);
    final now = DateTime.now();
    final closes = e != null && e.display.isOpen && e.expiresAt != null
        ? TripStrings.closesIn(TripEnquiryRules.closesInLabel(e.expiresAt!, now))
        : null;
    return TripStatusCard(
      key: ValueKey('reply-${x.stayId}-${e?.id}'),
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  x.name.isEmpty ? TripStrings.stay : x.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              if (e?.isUrgent ?? false) ...[
                const SizedBox(width: 6),
                _urgentPill(),
              ],
              _overflow(x),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [TripStatusPill(status, label: _label(x))],
          ),
          if (line.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium)),
          ],
          if (status == TripDisplayStatus.offered && e?.openOffer != null) _offerBreakdown(e!.openOffer!),
          if (e != null) ...[
            if (TripRepliesLegParts.wrongCityStrip(context, _c, e) case final w?) w,
            if (TripRepliesLegParts.oldDatesCard(_c, e) case final o?) o,
          ],
          if (status == TripDisplayStatus.confirmedByBoth && e != null && e.hasPendingRevised) ...[
            const SizedBox(height: 2),
            _pendingLine('${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}'),
          ],
          if (status == TripDisplayStatus.confirmedByBoth && e != null && e.hasPendingChange) ...[
            const SizedBox(height: 2),
            _pendingLine('${TripStrings.changeRequest} · ${TripStrings.notAcceptedYet}'),
          ],
          if (status == TripDisplayStatus.confirmedByBoth && e != null && e.advance.isPending && (e.advance.amount ?? 0) > 0)
            _advanceSteps(e.advance.amount!),
          if (closes != null) ...[
            const SizedBox(height: 2),
            Text(closes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
          ],
          if (status == TripDisplayStatus.holdExpired) ...[
            const SizedBox(height: 2),
            const Text(TripStrings.roomMayBeReleased,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.errorText)),
          ],
          const SizedBox(height: 12),
          _actions(x),
          if (status == TripDisplayStatus.holdExpired) ...[
            const SizedBox(height: 10),
            const Text(TripStrings.ifPaidFooter,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight, height: 1.35)),
          ],
        ],
      ),
    );
  }

  Widget _offerRow(String k, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(k,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: strong ? 13 : 12.5,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                      color: strong ? AppColors.textDark : AppColors.textMedium)),
            ),
            Text(v,
                maxLines: 1,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: strong ? 15 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ],
        ),
      );

  Widget _offerBreakdown(TripOfferModel offer) {
    final each = offer.lines.fold<int>(0, (sum, l) => sum + l.perNight);
    final advance = offer.advanceAmount ?? 0;
    final nights = offer.nights;
    final left = offer.total - advance;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nights > 0)
            _offerRow(each > 0 ? '${TripStrings.nights(nights)} · ${_inr(each)} each' : TripStrings.nights(nights),
                _inr(offer.total),
                strong: true)
          else
            _offerRow(TripStrings.total, _inr(offer.total), strong: true),
          if (advance > 0) ...[
            _offerRow(TripStrings.advance, _inr(advance)),
            if (left > 0) _offerRow(TripStringsV2Easy.balanceAtCheckIn, _inr(left)),
          ],
          const SizedBox(height: 2),
          const Text(TripStrings.termsByHost,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight, height: 1.35)),
        ],
      ),
    );
  }

  Widget _advanceSteps(int amount) {
    final steps = [TripStrings.step1Pay(_inr(amount)), TripStrings.step2Screenshot, TripStrings.step3Host];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(TripStrings.payDirectlyToHost,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              Text('${TripStrings.advance} ${_inr(amount)}',
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: TripColors.accent, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(steps[i],
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textDark, height: 1.3)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Text(TripStrings.noPaymentTail,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight, height: 1.35)),
        ],
      ),
    );
  }

  Widget _pendingLine(String text) => Text(text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText));

  Widget _urgentPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: TripStatusColors.failedSurface, borderRadius: BorderRadius.circular(999)),
        child: const Text(TripStrings.urgent,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.errorText)),
      );

  Widget _overflow(_Entry x) => SizedBox(
        width: 44,
        height: 44,
        child: PopupMenuButton<int>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textLight, size: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (_) => TripReport.stay(context, x.stayId, tripEnquiryId: x.enquiry?.id),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 0,
              child: Row(
                children: [
                  Icon(Iconsax.flag, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text(TripStrings.report, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _sendChange(TripEnquiryModel e) async {
    final day = e.day;
    final from = day == null || day > _c.dayCount ? null : _c.dateOf(day);
    final to = from == null ? null : DateTime(from.year, from.month, from.day + e.nights);
    final sent = await TripChangeRequestSheet.show(context, enquiry: e, checkIn: from, checkOut: to);
    if (sent && mounted) await _c.refreshEnquiries();
  }

  Widget _actions(_Entry x) {
    final e = x.enquiry;
    final status = x.status;
    final busy = e != null && TripEnquiryController.to.busyIds.contains(e.id);
    final phone = _phone(x);
    final offer = e?.openOffer;
    final buttons = <Widget>[];
    void add(IconData icon, String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) =>
        buttons.add(_ActionButton(icon: icon, label: label, color: color, onTap: busy ? null : onTap));
    final advanceOpen = status == TripDisplayStatus.confirmedByBoth && (e?.advance.isOpenRequest ?? false);
    final chatPrimary = advanceOpen && e?.conversationId != null;
    if (phone != null) {
      add(Iconsax.call, TripStrings.callHost, () => ContactLauncher.call(phone));
      if (!advanceOpen || e!.advance.isProofSent) {
        add(Iconsax.message, advanceOpen ? TripStrings.openWhatsApp : TripStrings.whatsApp,
            () => ContactLauncher.whatsApp(phone, message: advanceOpen ? null : e?.context.text),
            color: AppColors.whatsApp);
      }
    }
    if (e?.conversationId != null && !chatPrimary) {
      add(Iconsax.messages_2, TripStrings.openChat, () => TripNavigation.openChatForEnquiry(e!));
    }
    void counter() {
      if (e == null || !e.canCounter || _c.isReadOnly) return;
      add(Iconsax.money, e.counterCount > 0 ? TripStringsF2.proposeAgain : TripStrings.proposePrice,
          () => TripCounterSheet.show(context, enquiry: e));
    }
    switch (status) {
      case TripDisplayStatus.offered:
        if (offer != null) {
          add(Iconsax.close_circle, TripStrings.decline, () => _decline(e!), color: AppColors.error);
        } else {
          add(Iconsax.refresh, TripStringsA2.refresh, () => _c.refreshEnquiries());
        }
        counter();
        add(Iconsax.undo, TripStrings.withdraw, () => TripWithdrawSheet.show(context, enquiry: e!), color: AppColors.error);
      case TripDisplayStatus.asked:
        counter();
        add(Iconsax.undo, TripStrings.withdraw, () => TripWithdrawSheet.show(context, enquiry: e!), color: AppColors.error);
      case TripDisplayStatus.confirmedByYou:
        add(Iconsax.close_circle, TripStrings.cancelBooking,
            () => TripCancelSheet.show(context, enquiry: e!, ownerSide: false),
            color: AppColors.error);
      case TripDisplayStatus.confirmedByBoth:
        if (!_c.isReadOnly && TripEnquiryRules.isOutsideTrip(e!, _c.settings, _c.dayCount)) {
          add(Iconsax.calendar_edit, TripStrings.sendChangeRequest, () => _sendChange(e));
        }
        add(Iconsax.close_circle, TripStrings.cancelBooking,
            () => TripCancelSheet.show(context, enquiry: e!, ownerSide: false),
            color: AppColors.error);
      case TripDisplayStatus.holdExpired:
        add(Iconsax.building_4, TripStrings.askOtherStays, () => TripNavigation.openStay(_legIndex));
      default:
    }
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final half = w >= 340 ? (w - 8) / 2 : w;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == TripDisplayStatus.offered && offer != null) ...[
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: busy ? null : () => TripAcceptSheet.show(context, enquiry: e!, offer: offer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text([TripStrings.acceptOffer, _inr(offer.total)].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (chatPrimary) ...[
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => TripNavigation.openChatForEnquiry(e!),
                icon: const Icon(Iconsax.messages_2, size: 18),
                label: const Text(TripStrings.openChat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TripStatusVisuals.advanceBar(e!.advance.status),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final b in buttons) SizedBox(width: half, child: b)],
          ),
        ],
      );
    });
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? AppColors.textHint : color;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(color: c.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: c)),
          ),
        ],
      ),
    );
  }
}
