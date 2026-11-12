import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/leads/trip_lead_format.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_report.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_driver_reply_sheet.dart';
import '../widgets/trip_payment_line.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_status_card.dart';
import '../widgets/trip_taxi_booking_sheet.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_withdraw_sheet.dart';
import 'trip_dates_sheet.dart';
import 'trip_replies_leg_parts.dart';

class TripTaxiRepliesScreen extends StatefulWidget {
  const TripTaxiRepliesScreen({super.key});

  @override
  State<TripTaxiRepliesScreen> createState() => _TripTaxiRepliesScreenState();
}

class _TripTaxiRepliesScreenState extends State<TripTaxiRepliesScreen> with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  String _shown = '';
  late final TripPlanController _c;
  late int _day;
  String? _date;
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
    final day = map['day'];
    _day = (day is num ? day.toInt() : int.tryParse('${day ?? ''}')) ?? 1;
    _date = map['date']?.toString();
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
    _anim.dispose();
    super.dispose();
  }

  void _play(String kind) {
    if (_shown == kind) return;
    _shown = kind;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anim.forward(from: 0);
    });
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
    final day = _c.dayOfDate(DateTime.tryParse(_date ?? '')) ?? _focusDay();
    setState(() {
      if (day != null) _day = day;
      _started = true;
    });
  }

  int? _focusDay() {
    final id = _enquiryId;
    if (id == null) return null;
    for (final e in _c.enquiries) {
      if (e.id == id && e.isTaxi) return _c.planDaysOf(e).contains(_day) ? _day : _c.firstPlanDayOf(e);
    }
    return null;
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

  static String _inr(int? v) => v == null || v <= 0 ? '' : BrowseItem.inr(v);

  Future<bool> _datesGate() async {
    if (_c.hasDates) return true;
    await TripDatesSheet.ensure(context, heading: TripStrings.addYourDates);
    return mounted && _c.hasDates;
  }

  Future<void> _book(TripEnquiryModel e) async {
    if (!await _datesGate() || !mounted) return;
    await TripTaxiBookingSheet.show(context, taxi: null, day: _c.firstPlanDayOf(e) ?? _day, enquiry: e, initialFare: e.taxi?.driverFare);
  }

  Future<void> _report(TripEnquiryModel e) async {
    if (e.listingId.isEmpty) return;
    await TripReport.taxi(context, e.listingId, tripEnquiryId: e.id);
  }

  bool get _readOnly => _c.isReadOnly || _c.isDayPast(_day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitnessAppTheme.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Obx(() {
      _c.plan.value;
      final date = _c.dateOf(_day);
      final sub = [TripStrings.dayN(_day), if (date != null) TripFormat.shortDate(date)].join(' · ');
      final leg = TripRepliesLegParts.legLine(_c, _day);
      return ModuleHeader(
        title: TripStrings.taxiReplies,
        subtitle: sub,
        tone: KitTone.taxi,
        leadingAsset: TravelIcon.taxi,
        onBack: () => Get.back(),
        bottom: leg == null ? null : TripRepliesLegParts.legLineText(leg),
        bottomHeight: leg == null ? 0 : 20,
      );
    });
  }

  Widget _scroll(List<Widget> children, String kind) {
    _play(kind);
    return _scrollView(children);
  }

  Widget _scrollView(List<Widget> children) => RefreshIndicator(
        color: RepliesTone.accent,
        onRefresh: _c.refreshEnquiries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          children: [
            for (var i = 0; i < children.length; i++)
              TemplateEntrance(
                animation: templateInterval(_anim, i, children.length),
                animationController: _anim,
                child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: children[i])),
              ),
          ],
        ),
      );

  Widget _buildBody() {
    return Obx(() {
      if (_c.tripGone.value) return const TripNotFoundView();
      if (_c.plannerOff.value) {
        return _scroll([
          TripEmpty(
            asset: TravelIcon.route,
            title: TripStrings.plannerOff,
            subtitle: TripStrings.plannerOffSubtitle,
          ),
        ], 'plannerOff');
      }
      final plan = _c.plan.value;
      _c.enquiryList.length;
      TripEnquiryController.to.busyIds.length;
      if (plan == null && _c.openFailed.value) {
        return _scroll([
          TripEmpty(
            asset: TravelIcon.map,
            title: TripStrings.couldNotLoad,
            subtitle: TripStrings.checkConnection,
            onRetry: _load,
            retryLabel: TripStrings.retry,
          ),
        ], 'openFailed');
      }
      final entries = plan == null ? const <TripEnquiryModel>[] : _entries();
      if (plan == null || (entries.isEmpty && (!_started || _c.enquiriesLoading.value))) {
        _play('loading');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const TemplatePlaceholder(height: 130, radius: 8),
        );
      }
      if (entries.isEmpty && _c.enquiriesFailed.value) {
        return _scroll([
          TripEmpty(
            asset: TravelIcon.map,
            title: TripStrings.couldNotLoad,
            subtitle: TripStrings.checkConnection,
            onRetry: _c.refreshEnquiries,
            retryLabel: TripStrings.retry,
          ),
        ], 'failed');
      }
      if (entries.isEmpty) {
        return _scroll([
          TripEmpty(
            asset: TravelIcon.place,
            title: TripStrings.noTaxiReplies,
            subtitle: TripStrings.driversReply,
          ),
          if (!_readOnly) ...[
            const SizedBox(height: 16),
            _findTaxiButton(),
          ],
        ], 'empty');
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
      ], 'list');
    });
  }

  Widget _findTaxiButton() => Align(
        child: SizedBox(
          width: 220,
          child: TripActionChip(
            iconAsset: TravelIcon.taxi,
            label: TripStrings.findAnotherTaxi,
            onTap: () => TripNavigation.openTaxi(),
          ),
        ),
      );

  String _statusLine(TripEnquiryModel e) {
    final t = e.taxi;
    return switch (e.display) {
      TripDisplayStatus.asked => TripStrings.askedAgo(_ago(e.createdAt)),
      TripDisplayStatus.fareSent => TripStrings.repliedFare(_inr(t?.driverFare), _inr(TripLeadFormat.listedTotal(e))),
      TripDisplayStatus.bookedByYou =>
        [TripStrings.bookedByYou, _inr(t?.agreedFare)].where((s) => s.isNotEmpty).join(' · '),
      TripDisplayStatus.confirmedByBoth =>
        _inr(t?.agreedFare).isEmpty ? TripStrings.bookedByYou : TripStrings.bothFare(_inr(t?.agreedFare)),
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
                      fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: FitnessAppTheme.darkerText),
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
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, color: FitnessAppTheme.lightText)),
          if (TripRepliesLegParts.wrongCityStrip(context, _c, e) case final w?) w,
          if (TripRepliesLegParts.oldDatesCard(_c, e) case final o?) o,
          if (status == TripDisplayStatus.fareSent && note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.deactivatedText)),
          ],
          if (closes != null) ...[
            const SizedBox(height: 2),
            Text(closes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, color: FitnessAppTheme.deactivatedText)),
          ],
          if (status.isRed && other != null) ...[
            const SizedBox(height: 4),
            Text(TripStrings.driverAlsoGot(other),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.deactivatedText)),
          ],
          const SizedBox(height: 12),
          _actions(e),
        ],
      ),
    );
  }

  Widget _urgentPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: RepliesTone.badSurface, borderRadius: BorderRadius.circular(999)),
        child: const Text(TripStrings.urgent,
            style: TextStyle(
                fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, color: RepliesTone.bad)),
      );

  Widget _overflow(TripEnquiryModel e) => SizedBox(
        width: 44,
        height: 44,
        child: PopupMenuButton<int>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert_rounded, color: FitnessAppTheme.deactivatedText, size: 20),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          onSelected: (_) => _report(e),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 0,
              child: Row(
                children: [
                  TravelIcon(TravelIcon.note, size: 18),
                  SizedBox(width: 10),
                  Text(TripStrings.report, style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: RepliesTone.bad)),
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
    final day = _c.firstPlanDayOf(e) ?? _day;
    final buttons = <Widget>[];
    void add(Object icon, String label, VoidCallback? onTap, {Color color = RepliesTone.accent}) =>
        buttons.add(TripActionChip(
            iconAsset: icon is String ? icon : null,
            icon: icon is IconData ? icon : null,
            label: label,
            color: color,
            onTap: busy ? null : onTap));
    final live = status == TripDisplayStatus.asked ||
        status == TripDisplayStatus.fareSent ||
        status == TripDisplayStatus.bookedByYou ||
        status == TripDisplayStatus.confirmedByBoth;
    if (live && canCall) add(Icons.call_rounded, TripStrings.call, () => ContactLauncher.call(phone));
    if (live && canChat) {
      add(TravelIcon.chat, TripStrings.whatsApp,
          () => ContactLauncher.whatsApp(whatsApp, message: _c.whatsAppMessage(day, TripLeadFormat.driver(e))),
          color: RepliesTone.good);
    }
    switch (status) {
      case _ when _readOnly:
        break;
      case TripDisplayStatus.asked:
        add(TravelIcon.checkout, TripStrings.iBooked, () => _book(e));
        add(Icons.undo_rounded, TripStrings.withdraw, () => TripWithdrawSheet.show(context, enquiry: e), color: RepliesTone.bad);
      case TripDisplayStatus.fareSent:
        add(TravelIcon.note, TripStrings.viewLead, () => TripDriverReplySheet.show(context, enquiry: e));
        add(TravelIcon.checkout, TripStrings.iBooked, () => _book(e));
        add(Icons.undo_rounded, TripStrings.withdraw, () => TripWithdrawSheet.show(context, enquiry: e), color: RepliesTone.bad);
      case TripDisplayStatus.bookedByYou || TripDisplayStatus.confirmedByBoth:
        add(TravelIcon.note, TripStrings.editBooking, () => _book(e));
        add(Icons.close_rounded, TripStrings.cancelBooking,
            () => TripCancelSheet.show(context, enquiry: e, ownerSide: false),
            color: RepliesTone.bad);
      default:
        if (status.isRed) add(TravelIcon.taxi, TripStrings.askAnother, () => TripNavigation.openTaxi());
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
