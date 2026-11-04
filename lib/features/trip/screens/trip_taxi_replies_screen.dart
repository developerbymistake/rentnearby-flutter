import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../../taxi/leads/trip_lead_format.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_report.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_driver_reply_sheet.dart';
import '../widgets/trip_payment_line.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_status_card.dart';
import '../widgets/trip_taxi_booking_sheet.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_withdraw_sheet.dart';
import 'trip_details_sheet.dart';

class TripTaxiRepliesScreen extends StatefulWidget {
  const TripTaxiRepliesScreen({super.key});

  @override
  State<TripTaxiRepliesScreen> createState() => _TripTaxiRepliesScreenState();
}

class _TripTaxiRepliesScreenState extends State<TripTaxiRepliesScreen> {
  late final TripPlanController _c;
  late final int _day;
  String? _tripId;
  String? _enquiryId;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = TripPlanController.to;
    _c.openPages++;
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    _day = (map['day'] as int?) ?? 1;
    _tripId = map['tripId'] as String?;
    _enquiryId = map['enquiryId'] as String?;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.openPages--;
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
    if (mounted) setState(() => _started = true);
  }

  static int _rank(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.confirmedByBoth => 0,
        TripDisplayStatus.bookedByYou => 1,
        TripDisplayStatus.fareSent => 2,
        TripDisplayStatus.asked => 3,
        _ when s.isRed => 4,
        _ => 5,
      };

  List<TripEnquiryModel> _entries() {
    final list = [..._c.taxiEnquiriesForDay(_day)];
    final focus = _enquiryId;
    if (focus != null && !list.any((e) => e.id == focus)) {
      for (final e in _c.enquiries) {
        if (e.id == focus && e.isTaxi) list.add(e);
      }
    }
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final r = _rank(a.value.display).compareTo(_rank(b.value.display));
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return [for (final x in indexed) x.value];
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String _inr(int? v) => v == null ? '' : BrowseItem.inr(v);

  Future<bool> _datesGate() async {
    if (_c.hasDates) return true;
    await TripDetailsSheet.edit(context, heading: TripStrings.addYourDates, description: TripStrings.datesNeededBooking);
    return mounted && _c.hasDates;
  }

  Future<void> _book(TripEnquiryModel e) async {
    if (!await _datesGate() || !mounted) return;
    await TripTaxiBookingSheet.show(context, taxi: null, day: e.days.isNotEmpty ? e.days.first : _day, enquiry: e, initialFare: e.taxi?.driverFare);
  }

  Future<void> _report(TripEnquiryModel e) async {
    if (e.listingId.isEmpty) return;
    await TripReport.taxi(context, e.listingId, tripEnquiryId: e.id);
  }

  bool get _readOnly => _c.isReadOnly || _c.isDayPast(_day);

  bool _canAskAgain(TripEnquiryModel e) =>
      e.isRed && !_readOnly && _c.askAgainTaxis(_day).any((s) => s.taxiId == e.listingId);

  Future<void> _askAgain() async {
    final batch = await _c.askAgain(kind: TripEnquiryKinds.taxi, day: _day);
    if (batch != null && mounted) await _c.refreshEnquiries();
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
        gradient: TaxiColors.gradient,
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
              final date = _c.dateOf(_day);
              final sub = [TripStrings.dayN(_day), if (date != null) TripFormat.shortDate(date)].join(' · ');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    TripStrings.taxiReplies,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
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
            retryLabel: TripStrings.retry,
            palette: TripColors.palette,
          ),
        ]);
      }
      final entries = plan == null ? const <TripEnquiryModel>[] : _entries();
      if (plan == null || (entries.isEmpty && (!_started || _c.enquiriesLoading.value))) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => TripShimmers.rowBox(height: 130, radius: 18),
        );
      }
      if (entries.isEmpty && _c.enquiriesFailed.value) {
        return _scroll([
          EmptyStateView(
            icon: Iconsax.cloud_cross,
            title: TripStrings.couldNotLoad,
            subtitle: TripStrings.checkConnection,
            onRetry: _c.refreshEnquiries,
            retryLabel: TripStrings.retry,
            palette: TripColors.palette,
          ),
        ]);
      }
      if (entries.isEmpty) {
        return _scroll([
          const EmptyStateView(
            icon: Iconsax.message_question,
            title: TripStrings.noTaxiReplies,
            subtitle: TripStrings.driversReply,
            palette: TripColors.palette,
          ),
          if (!_readOnly) ...[
            const SizedBox(height: 16),
            _findTaxiButton(),
          ],
        ]);
      }
      return _scroll([
        for (final e in entries) ...[
          _card(e),
          const SizedBox(height: 12),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: TripPaymentLine(text: TripStrings.taxiPayLine),
        ),
      ]);
    });
  }

  Widget _findTaxiButton() => Align(
        child: TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () => TripNavigation.openTaxi(_day),
          child: const Text(TripStrings.findAnotherTaxi,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
        ),
      );

  String _statusLine(TripEnquiryModel e) {
    final t = e.taxi;
    return switch (e.display) {
      TripDisplayStatus.asked => TripStrings.askedAgo(_ago(e.createdAt)),
      TripDisplayStatus.fareSent => TripStrings.repliedFare(_inr(t?.driverFare), _inr(TripLeadFormat.listedTotal(e))),
      TripDisplayStatus.bookedByYou => '${TripStrings.bookedByYou} · ${_inr(t?.agreedFare)}',
      TripDisplayStatus.confirmedByBoth => TripStrings.bothFare(_inr(t?.agreedFare)),
      _ => TripLeadFormat.dates(e),
    };
  }

  Widget _card(TripEnquiryModel e) {
    final status = e.display;
    final now = DateTime.now();
    final note = (e.taxi?.driverNote ?? '').trim();
    final closes = status == TripDisplayStatus.asked && e.expiresAt != null
        ? TripStrings.closesIn(TripEnquiryRules.closesInLabel(e.expiresAt!, now))
        : null;
    final other = _c
        .taxiEnquiriesForDay(_day)
        .where((x) => x.id != e.id && x.listingId != e.listingId && x.display.isOpen && x.listingName.isNotEmpty)
        .map((x) => x.listingName)
        .firstOrNull;
    return TripStatusCard(
      key: ValueKey('taxi-reply-${e.id}'),
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  TripLeadFormat.driver(e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              if (e.isUrgent && status == TripDisplayStatus.asked) ...[
                const SizedBox(width: 6),
                _urgentPill(),
              ],
              _overflow(e),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [TripStatusPill(status, taxi: true)],
          ),
          const SizedBox(height: 6),
          Text(_statusLine(e),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium)),
          if (status == TripDisplayStatus.fareSent && note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ],
          if (closes != null) ...[
            const SizedBox(height: 2),
            Text(closes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
          ],
          if (status.isRed && other != null) ...[
            const SizedBox(height: 4),
            Text(TripStrings.driverAlsoGot(other),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ],
          const SizedBox(height: 12),
          _actions(e),
        ],
      ),
    );
  }

  Widget _urgentPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: TripStatusColors.failedSurface, borderRadius: BorderRadius.circular(999)),
        child: const Text(TripStrings.urgent,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.errorText)),
      );

  Widget _overflow(TripEnquiryModel e) => SizedBox(
        width: 44,
        height: 44,
        child: PopupMenuButton<int>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textLight, size: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (_) => _report(e),
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

  Widget _actions(TripEnquiryModel e) {
    final status = e.display;
    final busy = TripEnquiryController.to.busyIds.contains(e.id);
    final phone = e.owner.phone;
    final canCall = phone != null && ContactLauncher.tenDigits(phone).isNotEmpty;
    final whatsApp = e.owner.whatsApp ?? phone;
    final canChat = whatsApp != null && ContactLauncher.tenDigits(whatsApp).isNotEmpty;
    final day = e.days.isNotEmpty ? e.days.first : _day;
    final buttons = <Widget>[];
    void add(IconData icon, String label, VoidCallback? onTap, {Color color = TripColors.accentDark}) =>
        buttons.add(_ActionButton(icon: icon, label: label, color: color, onTap: busy ? null : onTap));
    final live = status == TripDisplayStatus.asked ||
        status == TripDisplayStatus.fareSent ||
        status == TripDisplayStatus.bookedByYou ||
        status == TripDisplayStatus.confirmedByBoth;
    if (live && canCall) add(Iconsax.call, TripStrings.call, () => ContactLauncher.call(phone));
    if (live && canChat) {
      add(Iconsax.message, TripStrings.whatsApp,
          () => ContactLauncher.whatsApp(whatsApp, message: _c.whatsAppMessage(day, TripLeadFormat.driver(e))),
          color: AppColors.whatsApp);
    }
    switch (status) {
      case _ when _readOnly:
        break;
      case TripDisplayStatus.asked:
        add(Iconsax.receipt_edit, TripStrings.iBooked, () => _book(e));
        add(Iconsax.undo, TripStrings.withdraw, () => TripWithdrawSheet.show(context, enquiry: e), color: AppColors.error);
      case TripDisplayStatus.fareSent:
        add(Iconsax.eye, TripStrings.viewLead, () => TripDriverReplySheet.show(context, enquiry: e));
        add(Iconsax.receipt_edit, TripStrings.iBooked, () => _book(e));
        add(Iconsax.undo, TripStrings.withdraw, () => TripWithdrawSheet.show(context, enquiry: e), color: AppColors.error);
      case TripDisplayStatus.bookedByYou || TripDisplayStatus.confirmedByBoth:
        add(Iconsax.edit_2, TripStrings.editBooking, () => _book(e));
        add(Iconsax.close_circle, TripStrings.cancelBooking,
            () => TripCancelSheet.show(context, enquiry: e, ownerSide: false),
            color: AppColors.error);
      default:
        if (_canAskAgain(e)) add(Iconsax.refresh, TripStrings.askAgain, _c.askBusy.value ? null : _askAgain);
        if (status.isRed) add(Iconsax.car, TripStrings.askAnother, () => TripNavigation.openTaxi(_day));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final half = w >= 340 ? (w - 8) / 2 : w;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final b in buttons) SizedBox(width: half, child: b)],
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
