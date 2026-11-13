import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../features/trip/controllers/trip_plan_controller.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_navigation.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/trip_strings_v2_easy.dart';
import '../features/trip/utils/trip_format.dart';
import '../features/trip/widgets/trip_status.dart';
import '../models/browse_item.dart';
import '../models/message_model.dart';
import '../utils/app_toast.dart';
import '../utils/contact_launcher.dart';
import 'trip_chat_cards.dart';

class _AdvanceCard {
  final String status;
  final String? enquiryId;
  final int? amount;
  final DateTime? holdUntil;
  final String? upiId;
  final String? whatsApp;
  final String stayName;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? agreedTotal;
  final String? guestPhone;
  final DateTime? proofSentAt;

  const _AdvanceCard({
    required this.status,
    this.enquiryId,
    this.amount,
    this.holdUntil,
    this.upiId,
    this.whatsApp,
    this.stayName = '',
    this.checkIn,
    this.checkOut,
    this.agreedTotal,
    this.guestPhone,
    this.proofSentAt,
  });

  String get money => amount == null ? '' : BrowseItem.inr(amount!);

  String get holdTime => holdUntil == null ? '' : TripFormat.time12Of(holdUntil!);

  String get range {
    final a = checkIn;
    final b = checkOut;
    if (a == null) return '';
    return TripFormat.dateRange(a, b ?? a);
  }

  bool get canStillMark {
    final ci = checkIn;
    if (ci == null) return true;
    final now = DateTime.now();
    return !DateTime(ci.year, ci.month, ci.day).isBefore(DateTime(now.year, now.month, now.day));
  }
}

class TripAdvanceCards {
  static const String requestType = 'trip_advance_request';
  static const String proofType = 'trip_advance_proof_sent';

  static const String _pending = 'pending';
  static const String _proofSent = 'proofSent';
  static const String _received = 'received';
  static const String _replaced = 'replaced';
  static const String _cancelled = 'cancelled';
  static const String _holdExpired = 'holdExpired';

  static _AdvanceCard _read(Map<String, dynamic> p, TripAdvanceModel? live) {
    final wire = _str(p, 'status') ?? _pending;
    final holdUntil = DateTime.tryParse(_str(p, 'holdUntil') ?? '');
    final amount = _num(p, 'amount')?.toInt();
    var status = wire;
    if (live != null && wire != _replaced && wire != _cancelled && _sameRequest(live, holdUntil, amount)) {
      status = switch (live.status) {
        TripAdvanceStatuses.proofSent => _proofSent,
        TripAdvanceStatuses.received => _received,
        TripAdvanceStatuses.holdExpired => _holdExpired,
        _ => wire,
      };
    }
    if ((status == _pending || status == _proofSent) && holdUntil != null && !holdUntil.isAfter(DateTime.now())) {
      status = _holdExpired;
    }
    return _AdvanceCard(
      status: status,
      enquiryId: _str(p, 'enquiryId'),
      amount: amount,
      holdUntil: holdUntil,
      upiId: _str(p, 'upiId'),
      whatsApp: _str(p, 'whatsApp'),
      stayName: _str(p, 'stayName') ?? '',
      checkIn: tripDate(p['checkIn']),
      checkOut: tripDate(p['checkOut']),
      agreedTotal: _num(p, 'agreedTotal')?.toInt(),
      guestPhone: _str(p, 'guestPhone'),
      proofSentAt: DateTime.tryParse(_str(p, 'proofSentAt') ?? ''),
    );
  }

  static bool _sameRequest(TripAdvanceModel live, DateTime? holdUntil, int? amount) {
    final h = live.holdUntil;
    if (h == null || holdUntil == null) return false;
    return h.isAtSameMomentAs(holdUntil) && live.amount == amount;
  }

  static Widget request(
    BuildContext context,
    MessageModel m, {
    required bool isOwner,
    required Color accent,
    required TripChatCallbacks callbacks,
  }) {
    final a = _read(m.payload, callbacks.advance);
    if (isOwner) return _hostRequest(m, a, callbacks);
    return switch (a.status) {
      _proofSent => _waiting(m, a, callbacks),
      _received => _receivedCard(m, a, callbacks),
      _replaced || _cancelled => _replacedCard(m, a),
      _holdExpired => _expiredGuest(m, a, callbacks),
      _ => _payCard(m, a, callbacks),
    };
  }

  static Widget proofSent(
    BuildContext context,
    MessageModel m, {
    required bool isOwner,
    required Color accent,
    required TripChatCallbacks callbacks,
  }) {
    final a = _read(m.payload, callbacks.advance);
    if (!isOwner) {
      final at = a.proofSentAt ?? callbacks.advance?.proofSentAt ?? m.createdAt;
      return TripChatCards.bubble(m, '${TripStrings.iSentProof} · ${TripFormat.time12Of(at)}');
    }
    return _hostProof(m, a, callbacks);
  }

  static Widget _card(
    MessageModel m, {
    required StatusTone3D status,
    required String art,
    required String pill,
    required String title,
    String? line,
    List<ReplyRow> rows = const [],
    List<String> extra = const [],
    String? note,
    String? noteArt,
    String? noteAction,
    VoidCallback? onNoteAction,
    ReplyAction? primary,
    ReplyAction? secondary,
    bool showActions = true,
    bool dimmed = false,
  }) =>
      TripChatCards.wrap(
        m,
        ChatTripCard3D(
          status: status,
          art: art,
          pill: pill,
          title: title,
          line: line,
          rows: rows,
          extra: extra,
          note: note,
          noteArt: noteArt,
          noteAction: noteAction,
          onNoteAction: onNoteAction,
          primary: primary,
          secondary: secondary,
          showActions: showActions,
          dimmed: dimmed,
          mine: m.isMine,
          read: m.readAt != null,
        ),
      );

  static String _tenDigits(String? phone) => phone == null ? '' : ContactLauncher.tenDigits(phone);

  static VoidCallback? _call(String phone) => phone.isEmpty ? null : () => ContactLauncher.call(phone);

  static VoidCallback? _viewTrip(TripChatCallbacks cb) {
    final tripId = cb.tripId;
    if (tripId == null) return null;
    return () => Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId});
  }

  // guest

  static Widget _payCard(MessageModel m, _AdvanceCard a, TripChatCallbacks cb) {
    final upi = a.upiId;
    final hasUpi = upi != null && upi.isNotEmpty;
    final id = a.enquiryId;
    return _card(
      m,
      status: StatusTone3D.waiting,
      art: ListingArt.moneyBag,
      pill: a.amount == null ? TripStrings.advance : a.money,
      title: TripStrings.payDirectlyToHost,
      line: a.holdUntil == null ? null : TripStrings.advanceHoldTill(a.holdTime),
      rows: [
        ReplyRow(TripStrings.step1Pay(a.money), '', done: false),
        const ReplyRow(TripStrings.step2Screenshot, '', done: false),
        const ReplyRow(TripStrings.step3Host, '', done: false),
      ],
      extra: [if (hasUpi) TripStrings.stayPayLine],
      note: hasUpi ? '${TripStrings.upiId} $upi' : TripStrings.stayPayLine,
      noteArt: hasUpi ? ListingArt.key : ListingArt.moneyBag,
      noteAction: hasUpi ? TripStrings.copy : null,
      onNoteAction: hasUpi
          ? () async {
              await Clipboard.setData(ClipboardData(text: upi));
              AppToast.success(TripStrings.upiCopied);
            }
          : null,
      primary: ReplyAction(
          label: TripStrings.iSentProof, onTap: id == null || cb.onProofSent == null ? null : () => cb.onProofSent!(id)),
      secondary: ReplyAction(label: TripStrings.callHost, onTap: _call(_tenDigits(cb.hostPhone))),
    );
  }

  static Widget _waiting(MessageModel m, _AdvanceCard a, TripChatCallbacks cb) {
    final live = cb.advance;
    final sentAt = live?.proofSentAt ?? a.proofSentAt;
    final last = live?.lastHostReminderAt;
    final next = live?.nextHostReminderAt;
    final notYetAt = live?.notYetAt;
    final reminder = last == null
        ? null
        : (next == null
            ? TripStrings.hostRemindedOnly(TripFormat.time12Of(last))
            : TripStrings.hostReminded(TripFormat.time12Of(last), TripFormat.time12Of(next)));
    return _card(
      m,
      status: StatusTone3D.waiting,
      art: ListingArt.calendar,
      pill: a.amount == null ? TripStrings.advance : a.money,
      title: TripStrings.waitingForHost,
      line: sentAt == null ? null : TripStrings.youSaidProofSent(TripFormat.time12Of(sentAt)),
      rows: const [
        ReplyRow(TripStrings.stepPaymentSent, '', done: true),
        ReplyRow(TripStrings.stepScreenshotSent, '', done: true),
        ReplyRow(TripStrings.stepHostChecks, '', done: false),
      ],
      extra: [
        if (notYetAt != null)
          [
            TripStrings.hostNotSeenYet,
            TripStrings.hostChecked(TripFormat.time12Of(notYetAt)),
            if (a.holdUntil != null) TripStrings.checkBefore(a.holdTime),
          ].join('. '),
        if (reminder != null) TripStrings.waitingFooter,
      ],
      note: reminder ?? TripStrings.waitingFooter,
      noteArt: ListingArt.calendar,
      primary: ReplyAction(label: TripStrings.callHost, onTap: _call(_tenDigits(cb.hostPhone))),
      secondary: ReplyAction(label: TripStrings.viewInTrip, onTap: _viewTrip(cb)),
    );
  }

  static Widget _receivedCard(MessageModel m, _AdvanceCard a, TripChatCallbacks cb) {
    final at = cb.advance?.receivedAt;
    final total = a.agreedTotal;
    final amount = a.amount;
    return _card(
      m,
      status: StatusTone3D.booked,
      art: ListingArt.star,
      pill: amount == null ? TripStrings.advance : a.money,
      title: TripStrings.advanceReceived,
      line: at == null ? TripStrings.advanceReceivedHostSays : TripStrings.saysReceived(a.stayName, a.money, TripFormat.time12Of(at)),
      rows: [
        if (amount != null) ReplyRow(TripStrings.advance, a.money),
        if (total != null) ReplyRow(TripStrings.total, BrowseItem.inr(total)),
        if (total != null && amount != null && total > amount)
          ReplyRow(TripStringsV2Easy.balanceAtCheckIn, BrowseItem.inr(total - amount)),
      ],
      note: TripStrings.stayPayLine,
      noteArt: ListingArt.moneyBag,
      primary: ReplyAction(label: TripStrings.callHost, onTap: _call(_tenDigits(cb.hostPhone))),
      secondary: ReplyAction(label: TripStrings.viewInTrip, onTap: _viewTrip(cb)),
    );
  }

  static Widget _expiredGuest(MessageModel m, _AdvanceCard a, TripChatCallbacks cb) {
    final others = _otherReplies(cb);
    return _card(
      m,
      status: StatusTone3D.red,
      art: ListingArt.roundPushpin,
      pill: TripStatusVisuals.label(TripDisplayStatus.holdExpired),
      title: TripStrings.hostDidNotConfirm,
      line: TripStrings.roomMayBeReleased,
      rows: [
        if (a.amount != null) ReplyRow(TripStrings.advance, a.money),
        if (a.holdUntil != null) ReplyRow(TripStrings.holdEnded, a.holdTime),
        if (a.range.isNotEmpty) ReplyRow(TripStrings.dates, a.range),
      ],
      extra: [if (others.isNotEmpty) TripStrings.ifPaidFooter],
      note: others.isNotEmpty ? TripStrings.otherStaysReplied(others.length, others.join(', ')) : TripStrings.ifPaidFooter,
      noteArt: others.isNotEmpty ? ListingArt.hotel : ListingArt.moneyBag,
      primary: ReplyAction(label: TripStrings.askOtherStays, onTap: () => _askOthers(cb)),
      secondary: ReplyAction(label: TripStrings.callHost, onTap: _call(_tenDigits(cb.hostPhone))),
    );
  }

  static List<String> _otherReplies(TripChatCallbacks cb) {
    final day = cb.day;
    if (day == null || !Get.isRegistered<TripPlanController>()) return const [];
    final plan = Get.find<TripPlanController>();
    if (plan.trip.value?.id == null || plan.trip.value?.id != cb.tripId) return const [];
    return plan
        .enquiriesForNight(day)
        .where((e) => e.display == TripDisplayStatus.offered)
        .map((e) => e.listingName)
        .where((n) => n.isNotEmpty)
        .toList();
  }

  static void _askOthers(TripChatCallbacks cb) {
    final tripId = cb.tripId;
    final day = cb.day;
    final loaded = Get.isRegistered<TripPlanController>() && Get.find<TripPlanController>().trip.value?.id == tripId;
    if (loaded && day != null) {
      TripNavigation.openStay(Get.find<TripPlanController>().legIndexOf(day));
    } else if (tripId != null) {
      Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId});
    }
  }

  static Widget _replacedCard(MessageModel m, _AdvanceCard a) => _card(
        m,
        status: StatusTone3D.closed,
        art: ListingArt.moneyBag,
        pill: a.status == _cancelled ? TripStrings.advanceCancelled : TripStrings.replacedByNewer,
        title: TripStrings.advancePending(a.money),
        line: a.holdUntil == null ? null : TripStrings.holdTill(a.holdTime),
        rows: [if (a.amount != null) ReplyRow(TripStrings.advance, a.money)],
        showActions: false,
        dimmed: true,
      );

  // host

  static Widget _hostRequest(MessageModel m, _AdvanceCard a, TripChatCallbacks cb) {
    if (a.status == _replaced || a.status == _cancelled) return _replacedCard(m, a);
    if (a.status == _holdExpired) return _lateMark(m, a, cb);
    final upi = a.upiId;
    final wa = _tenDigits(a.whatsApp);
    final (StatusTone3D tone, String pill) = switch (a.status) {
      _received => (StatusTone3D.both, TripStrings.advanceReceivedHostSays),
      _proofSent => (
          StatusTone3D.waiting,
          cb.guestName == null ? TripStrings.waitingForHostHourly : TripStrings.saysProofSent(cb.guestName!)
        ),
      _ => (StatusTone3D.waiting, TripStrings.holdTill(a.holdTime)),
    };
    return _card(
      m,
      status: tone,
      art: ListingArt.moneyBag,
      pill: pill,
      title: TripStrings.advancePending(a.money),
      line: a.holdUntil == null ? null : TripStrings.holdTill(a.holdTime),
      rows: [
        if (upi != null && upi.isNotEmpty) ReplyRow(TripStrings.upiId, upi),
        if (wa.isNotEmpty) ReplyRow(TripStrings.whatsApp, '+91 $wa'),
        if (a.range.isNotEmpty) ReplyRow(TripStrings.dates, a.range),
      ],
      note: TripStrings.stayPayLine,
      noteArt: ListingArt.moneyBag,
      showActions: false,
    );
  }

  static Widget _lateMark(MessageModel m, _AdvanceCard a, TripChatCallbacks cb) {
    final id = a.enquiryId;
    final canMark = !cb.movedOn && a.canStillMark && id != null && cb.onMarkReceived != null;
    return _card(
      m,
      status: StatusTone3D.red,
      art: ListingArt.roundPushpin,
      pill: a.amount == null ? TripStrings.holdEnded : a.money,
      title: TripStrings.holdEnded,
      line: TripStrings.advanceNotMarked,
      rows: [
        if (a.amount != null) ReplyRow(TripStrings.advance, a.money),
        if (a.holdUntil != null) ReplyRow(TripStrings.holdEnded, a.holdTime),
        if (a.range.isNotEmpty) ReplyRow(TripStrings.dates, a.range),
      ],
      extra: const [TripStrings.stayPayLine],
      note: cb.movedOn ? TripStrings.guestMovedOn : TripStrings.canStillMark(cb.guestName ?? ''),
      primary: ReplyAction(label: TripStrings.markAdvanceReceived, onTap: canMark ? () => cb.onMarkReceived!(id) : null),
      secondary: ReplyAction(label: TripStrings.callGuest, onTap: _call(_tenDigits(cb.guestPhone))),
    );
  }

  static Widget _hostProof(MessageModel m, _AdvanceCard a, TripChatCallbacks cb) {
    if (a.status == _replaced || a.status == _cancelled) {
      return _card(
        m,
        status: StatusTone3D.closed,
        art: ListingArt.moneyBag,
        pill: a.status == _cancelled ? TripStrings.advanceCancelled : TripStrings.replacedByNewer,
        title: TripStrings.saysProofSent(cb.guestName ?? ''),
        rows: [if (a.amount != null) ReplyRow(TripStrings.advance, a.money)],
        showActions: false,
        dimmed: true,
      );
    }
    final phone = _tenDigits(a.guestPhone);
    final id = a.enquiryId;
    final open = a.status == _pending || a.status == _proofSent;
    final (StatusTone3D tone, String pill) = switch (a.status) {
      _received => (StatusTone3D.both, TripStrings.advanceReceivedHostSays),
      _holdExpired => (StatusTone3D.red, TripStatusVisuals.label(TripDisplayStatus.holdExpired)),
      _ => (StatusTone3D.waiting, a.holdUntil == null ? TripStrings.advance : TripStrings.holdTill(a.holdTime)),
    };
    return _card(
      m,
      status: tone,
      art: ListingArt.moneyBag,
      pill: pill,
      title: TripStrings.saysProofSent(cb.guestName ?? ''),
      line: phone.isEmpty ? null : TripStrings.checkWhatsApp(phone),
      rows: [
        if (a.amount != null) ReplyRow(TripStrings.advance, a.money),
        if (a.holdUntil != null) ReplyRow(TripStrings.holdTill(a.holdTime), ''),
        if (a.range.isNotEmpty) ReplyRow(TripStrings.dates, a.range),
      ],
      note: open ? TripStrings.checkAmountFirst : null,
      primary: ReplyAction(
          label: TripStrings.markAdvanceReceived,
          onTap: !open || id == null || cb.onMarkReceived == null ? null : () => cb.onMarkReceived!(id)),
      secondary: ReplyAction(
          label: TripStrings.notYet, onTap: !open || id == null || cb.onNotYet == null ? null : () => cb.onNotYet!(id)),
    );
  }

  static String? _str(Map<String, dynamic> p, String k) {
    final v = p[k];
    return v is String ? v : null;
  }

  static num? _num(Map<String, dynamic> p, String k) {
    final v = p[k];
    return v is num ? v : null;
  }
}
