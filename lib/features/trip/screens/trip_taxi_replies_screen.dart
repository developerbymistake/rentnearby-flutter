import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/leads/trip_lead_format.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_rc.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_report.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_driver_reply_sheet.dart';
import '../widgets/trip_status.dart';
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
  late final AnimationController _anim;
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
    _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
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

  static final ListingTone _tone = ListingTone.coral;
  final _menuKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _c.plan.value;
      final date = _c.dateOf(_day);
      return RepliesScaffold(
        tone: _tone,
        title: TripStrings.taxiReplies,
        subtitle: [TripStrings.dayN(_day), if (date != null) TripFormat.shortDate(date)].join(' · '),
        art: ListingArt.taxi,
        leg: TripRepliesLegParts.legLine(_c, _day),
        onBack: () => Get.back(),
        body: _buildBody(),
      );
    });
  }

  Widget _scroll(List<Widget> children, String kind) {
    _play(kind);
    return RefreshIndicator(
      color: _tone.g2,
      onRefresh: _c.refreshEnquiries,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
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
  }

  Widget _error(VoidCallback onRetry) => RepliesEmpty(
        tone: _tone,
        art: ListingArt.worldMap,
        title: TripStrings.couldNotLoad,
        message: TripStrings.checkConnection,
        actionLabel: TripStrings.retry,
        onAction: onRetry,
      );

  Widget _buildBody() {
    return Obx(() {
      if (_c.tripGone.value) return const TripNotFoundView();
      if (_c.plannerOff.value) {
        return _scroll([
          RepliesEmpty(tone: _tone, art: ListingArt.compass, title: TripStrings.plannerOff, message: TripStrings.plannerOffSubtitle),
        ], 'plannerOff');
      }
      final plan = _c.plan.value;
      _c.enquiryList.length;
      TripEnquiryController.to.busyIds.length;
      if (plan == null && _c.openFailed.value) return _scroll([_error(_load)], 'openFailed');
      final entries = plan == null ? const <TripEnquiryModel>[] : _entries();
      if (plan == null || (entries.isEmpty && (!_started || _c.enquiriesLoading.value))) {
        _play('loading');
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: const [ReplyCardSkeleton(), ReplyCardSkeleton(), ReplyCardSkeleton()],
        );
      }
      if (entries.isEmpty && _c.enquiriesFailed.value) return _scroll([_error(_c.refreshEnquiries)], 'failed');
      if (entries.isEmpty) {
        return _scroll([
          RepliesEmpty(
            tone: _tone,
            art: ListingArt.roundPushpin,
            title: TripStrings.noTaxiReplies,
            message: TripStrings.driversReply,
            actionLabel: _readOnly ? null : TripStrings.findAnotherTaxi,
            actionArt: ListingArt.taxi,
            onAction: () => TripNavigation.openTaxi(),
          ),
        ], 'empty');
      }
      return _scroll([
        for (var i = 0; i < entries.length; i++) _card(entries[i]),
        const PayLine3D(TripStrings.taxiPayLine, art: ListingArt.moneyBag),
      ], 'list');
    });
  }

  String _statusLine(TripEnquiryModel e) {
    final t = e.taxi;
    return switch (e.display) {
      TripDisplayStatus.asked => TripStrings.askedAgo(_ago(e.createdAt)),
      TripDisplayStatus.fareSent => TripStrings.repliedFare(_inr(t?.driverFare), _inr(TripLeadFormat.listedTotal(e))),
      TripDisplayStatus.bookedByYou => [TripStrings.bookedByYou, _inr(t?.agreedFare)].where((s) => s.isNotEmpty).join(' · '),
      TripDisplayStatus.confirmedByBoth => _inr(t?.agreedFare).isEmpty ? TripStrings.bookedByYou : TripStrings.bothFare(_inr(t?.agreedFare)),
      _ => TripLeadFormat.dates(e),
    };
  }

  ({String? cap, String number, String? unit}) _price(TripEnquiryModel e) {
    final t = e.taxi;
    final days = TripLeadFormat.dayCount(e);
    final unit = days == 1 ? TripStringsRc.oneDay : '$days ${TripStringsRc.days}';
    final agreed = t?.agreedFare;
    if ((e.display == TripDisplayStatus.bookedByYou || e.display == TripDisplayStatus.confirmedByBoth) && agreed != null && agreed > 0) {
      return (cap: TripStrings.agreed, number: _inr(agreed), unit: unit);
    }
    final fare = t?.driverFare;
    if (fare != null && fare > 0) return (cap: TripStrings.fare, number: _inr(fare), unit: unit);
    final rate = t?.listedRate;
    if (rate != null && rate > 0) return (cap: TripStrings.listedLabel, number: _inr(rate), unit: TripStringsRc.perDay);
    return (cap: TripStrings.dates, number: '$days', unit: unit);
  }

  (String?, String) _note(TripEnquiryModel e) {
    final status = e.display;
    final now = DateTime.now();
    final lines = <String>[];
    String art = ListingArt.taxi;
    void add(String t, String a) {
      if (lines.isEmpty) art = a;
      lines.add(t);
    }

    if (TripRepliesLegParts.wrongCityNote(context, _c, e) case final w?) add(w.text, ListingArt.roundPushpin);
    if (TripRepliesLegParts.oldDatesNote(_c, e) case final o?) add(o.text, ListingArt.calendar);
    final note = (e.taxi?.driverNote ?? '').trim();
    if (status == TripDisplayStatus.fareSent && note.isNotEmpty) add('"$note"', ListingArt.speechBalloon);
    if (status == TripDisplayStatus.asked && e.expiresAt != null) add(TripStrings.closesIn(TripEnquiryRules.closesInLabel(e.expiresAt!, now)), ListingArt.calendar);
    if (lines.isNotEmpty) return (lines.join('\n'), art);
    if (status.isRed) {
      final other = _c
          .taxiEnquiriesForDay(_day)
          .where((x) => x.id != e.id && x.listingId != e.listingId && x.display.isOpen && x.listingName.isNotEmpty)
          .map((x) => x.listingName)
          .firstOrNull;
      if (other != null) return (TripStrings.driverAlsoGot(other), ListingArt.taxi);
      return (null, ListingArt.taxi);
    }
    return (TripStrings.taxiPayLine, ListingArt.moneyBag);
  }

  List<ReplyRow> _rows(TripEnquiryModel e, ({String? cap, String number, String? unit}) price) {
    final pickup = TripLeadFormat.pickup(e);
    final people = TripLeadFormat.people(e);
    final listed = TripLeadFormat.listedTotal(e) ?? 0;
    final rows = <ReplyRow>[
      ReplyRow(TripStrings.dates, TripLeadFormat.dates(e)),
      if (pickup.isNotEmpty) ReplyRow(TripStrings.pickup, pickup),
      if (people != null) ReplyRow(TripStrings.people, people),
      ReplyRow(TripStrings.days, price.unit ?? ''),
      if (listed > 0) ReplyRow(TripStrings.listedLabel, _inr(listed)),
    ];
    return rows.take(3).toList();
  }

  Widget _card(TripEnquiryModel e) {
    final status = e.display;
    final busy = TripEnquiryController.to.busyIds.contains(e.id);
    final phone = e.owner.phone;
    final canCall = phone != null && ContactLauncher.tenDigits(phone).isNotEmpty;
    final live = status == TripDisplayStatus.asked ||
        status == TripDisplayStatus.fareSent ||
        status == TripDisplayStatus.bookedByYou ||
        status == TripDisplayStatus.confirmedByBoth;
    final booked = status == TripDisplayStatus.bookedByYou || status == TripDisplayStatus.confirmedByBoth;
    final open = status == TripDisplayStatus.asked || status == TripDisplayStatus.fareSent;
    VoidCallback? act(bool on, VoidCallback f) => busy || !on ? null : f;
    final price = _price(e);
    final (noteText, noteArt) = _note(e);
    final menuKey = _menuKeys.putIfAbsent(e.id, () => GlobalKey());
    final noteData = TripRepliesLegParts.wrongCityNote(context, _c, e);

    final ReplyAction primary;
    if (booked) {
      primary = ReplyAction(label: TripStrings.editBooking, onTap: act(!_readOnly, () => _book(e)));
    } else if (open) {
      primary = ReplyAction(label: TripStrings.iBooked, onTap: act(!_readOnly, () => _book(e)));
    } else {
      primary = ReplyAction(label: TripStrings.askAnother, onTap: act(!_readOnly && status.isRed, () => TripNavigation.openTaxi()));
    }
    final menu = <MenuItem3D>[
      if (open && !_readOnly)
        MenuItem3D(label: TripStrings.withdraw, art: ListingArt.clipboard, danger: true, onTap: act(true, () => TripWithdrawSheet.show(context, enquiry: e))),
      if (booked && !_readOnly)
        MenuItem3D(
          label: TripStrings.cancelBooking,
          art: ListingArt.calendar,
          danger: true,
          onTap: act(true, () => TripCancelSheet.show(context, enquiry: e, ownerSide: false)),
        ),
      MenuItem3D(label: TripStrings.report, art: ListingArt.warning, danger: true, onTap: () => _report(e)),
    ];
    return ReplyCard3D(
      key: ValueKey('taxi-reply-${e.id}'),
      status: StatusTone3D.of(status.name),
      art: ListingArt.taxi,
      pill: TripStatusVisuals.label(status, taxi: true),
      urgent: e.isUrgent && status == TripDisplayStatus.asked,
      title: TripLeadFormat.driver(e),
      statusLine: _statusLine(e),
      cap: price.cap,
      number: price.number,
      unit: price.unit,
      menuKey: menuKey,
      onMenu: () => showReplyMenu(menuKey, menu),
      rows: _rows(e, price),
      note: noteText,
      noteArt: noteArt,
      noteAction: noteData?.actionLabel,
      onNoteAction: noteData?.onAction,
      primary: busy ? ReplyAction(label: primary.label, busy: true) : primary,
      secondary: [
        ReplyAction(label: TripStrings.call, onTap: act(live && canCall, () => ContactLauncher.call(phone!))),
        ReplyAction(label: TripStrings.viewLead, onTap: act(!_readOnly && status == TripDisplayStatus.fareSent, () => TripDriverReplySheet.show(context, enquiry: e))),
      ],
    );
  }
}

