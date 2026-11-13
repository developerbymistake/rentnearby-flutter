import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_f2.dart';
import '../trip_strings_rc.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_report.dart';
import '../widgets/trip_accept_sheet.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_change_request_sheet.dart';
import '../widgets/trip_counter_sheet.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_withdraw_sheet.dart';
import 'trip_replies_leg_parts.dart';

class TripRepliesScreen extends StatefulWidget {
  const TripRepliesScreen({super.key});

  @override
  State<TripRepliesScreen> createState() => _TripRepliesScreenState();
}

const int _maxOpenAsks = 3;
const List<String> _stayArt = [ListingArt.hotel, ListingArt.bed, ListingArt.key];

class _Entry {
  final String stayId;
  final String name;
  final TripEnquiryModel? enquiry;
  const _Entry({required this.stayId, required this.name, this.enquiry});

  TripDisplayStatus get status => enquiry?.display ?? TripDisplayStatus.shortlisted;
}

class _TripRepliesScreenState extends State<TripRepliesScreen> with TickerProviderStateMixin {
  late final AnimationController _anim;
  String _shown = '';
  late final TripPlanController _c;
  late final int _day;
  final _menuKeys = <String, GlobalKey>{};
  String? _tripId;
  String? _enquiryId;
  bool _started = false;
  bool _retried = false;

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

  int? _listed(_Entry x) {
    if (!Get.isRegistered<TripSupplyController>()) return null;
    for (final s in Get.find<TripSupplyController>().stays) {
      if (s.id == x.stayId) return s.minPricePerNight;
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

  static String _dates(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    return a != null && b != null ? TripFormat.dayMonthRange(a, b) : e.datesLabel;
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

  String _statusLine(_Entry x) => _glue(_statusLineRaw(x));

  static String _glue(String t) => t.replaceAllMapped(RegExp(r'(\d) (h|min|d)(?!\w)'), (m) => '${m[1]} ${m[2]}');

  String _statusLineRaw(_Entry x) {
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
              e.openOffer!.validUntil == null ? '' : TripEnquiryRules.closesInLabel(e.openOffer!.validUntil!, now)),
      TripDisplayStatus.confirmedByBoth when e.advanceLabel != null => e.advanceLabel!,
      TripDisplayStatus.confirmedByYou || TripDisplayStatus.confirmedByBoth =>
        [_dates(e), _inr(e.agreedTotal)].where((s) => s.isNotEmpty).join(' · '),
      TripDisplayStatus.holdExpired => TripStrings.hostDidNotConfirm,
      _ => _dates(e),
    };
  }

  Future<void> _decline(TripEnquiryModel e) async {
    final offer = e.openOffer;
    if (offer == null) return;
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.forest,
        art: ListingArt.hotel,
        title: TripStrings.declineQuestion,
        body: TripStrings.declineNote,
        content: ReplySummaryStrip(
          tone: ListingTone.forest,
          title: e.listingName.isEmpty ? TripStrings.stay : e.listingName,
          subtitle: [_dates(e), TripStrings.nights(e.nights)].where((s) => s.isNotEmpty).join(' · '),
          value: _inr(offer.total),
          margin: EdgeInsets.zero,
        ),
        secondaryLabel: TripStrings.keep,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStrings.decline,
        primaryDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (ok == true) await TripEnquiryController.to.decline(e.id, offer.id);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _c.plan.value;
      return RepliesScaffold(
        tone: ListingTone.forest,
        title: TripStrings.stayReplies,
        subtitle: _subtitle(),
        art: ListingArt.hotel,
        leg: TripRepliesLegParts.legLine(_c, _rankDay),
        onBack: () => Get.back(),
        body: _buildBody(),
      );
    });
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

  Widget _scroll(List<Widget> children, [String kind = 'list']) {
    _play(kind);
    return RefreshIndicator(
      color: ListingTone.forest.g2,
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
      if (plan == null && _c.openFailed.value) {
        return _scroll([_error(_load)], 'openFailed');
      }
      final entries = plan == null ? const <_Entry>[] : _entries();
      if (plan == null || (entries.isEmpty && (!_started || _c.enquiriesLoading.value))) {
        _play('loading');
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: const [ReplyCardSkeleton(), ReplyCardSkeleton(), ReplyCardSkeleton()],
        );
      }
      if (entries.isEmpty && _c.enquiriesFailed.value) {
        return _scroll([_error(_c.refreshEnquiries)], 'failed');
      }
      if (entries.isEmpty) {
        return _scroll([
          RepliesEmpty(tone: _tone, art: ListingArt.roundPushpin, title: TripStrings.noRepliesYet, message: TripStrings.hostsReply),
        ], 'empty');
      }
      final nothingToAsk = !_c.isCompleted && entries.every((x) => x.enquiry?.isRed ?? false);
      return _scroll([
        if (nothingToAsk)
          RepliesBanner(
            bad: true,
            art: ListingArt.roundPushpin,
            text: TripStrings.allAsksEnded,
            actionLabel: TripStrings.findAnother,
            onAction: () => TripNavigation.openStay(_legIndex),
          ),
        for (var i = 0; i < entries.length; i++) _card(entries[i], i),
        if (_canAskAnother(entries))
          ArtPillButton(tone: _tone, art: ListingArt.hotel, label: TripStringsA5.askAnotherStay, onTap: () => TripNavigation.openStay(_legIndex)),
      ], 'list');
    });
  }

  static final ListingTone _tone = ListingTone.forest;

  Widget _error(VoidCallback onRetry) => RepliesEmpty(
        tone: _tone,
        art: ListingArt.worldMap,
        title: TripStrings.couldNotLoad,
        message: TripStrings.checkConnection,
        actionLabel: TripStrings.retry,
        onAction: onRetry,
      );

  bool _canAskAnother(List<_Entry> entries) {
    if (_c.isReadOnly || _c.isDayPast(_day)) return false;
    if (entries.any((x) => x.enquiry?.isBooked ?? false)) return false;
    return entries.where((x) => x.enquiry?.display.isOpen ?? false).length < _maxOpenAsks;
  }

  ({String? cap, String number, String? unit}) _price(_Entry x) {
    final e = x.enquiry;
    final offer = e?.openOffer;
    final nights = e == null ? null : TripStrings.nights(e.nights);
    final counter = e?.pendingCounter;
    if (e != null && counter != null && e.display.isOpen && !e.isBooked) {
      return (cap: TripStringsA5.yourPriceTitle, number: _inr(counter.pricePerNight), unit: TripStringsRc.perRoomNight);
    }
    if (e != null && e.display == TripDisplayStatus.offered && offer != null) {
      return (cap: TripStrings.total, number: _inr(offer.total), unit: nights);
    }
    final agreed = e?.agreedTotal;
    if (e != null && agreed != null && agreed > 0) {
      return (cap: e.isBooked ? TripStrings.agreed : TripStrings.total, number: _inr(agreed), unit: nights);
    }
    final listed = _listed(x);
    if (listed != null && listed > 0) return (cap: TripStrings.listedLabel, number: _inr(listed), unit: TripStringsRc.perNight);
    return (cap: TripStringsRc.nights, number: '${e?.nights ?? ''}', unit: e?.datesLabel);
  }

  List<ReplyRow> _rows(_Entry x) {
    final e = x.enquiry;
    if (e == null) return const [];
    final status = x.status;
    final offer = e.openOffer;
    if (status == TripDisplayStatus.offered && offer != null) {
      final each = offer.lines.fold<int>(0, (sum, l) => sum + l.perNight);
      final advance = offer.advanceAmount ?? 0;
      final left = offer.total - advance;
      return [
        ReplyRow(offer.nights > 0 && each > 0 ? '${TripStrings.nights(offer.nights)} · ${_inr(each)} each' : TripStrings.total, _inr(offer.total)),
        if (advance > 0) ReplyRow(TripStrings.advance, _inr(advance)),
        if (advance > 0 && left > 0) ReplyRow(TripStringsV2Easy.balanceAtCheckIn, _inr(left)),
      ];
    }
    if (status == TripDisplayStatus.confirmedByBoth) {
      final adv = e.advance;
      if (adv.isPending && (adv.amount ?? 0) > 0) {
        return [
          ReplyRow(TripStrings.step1Pay(_inr(adv.amount)), '', step: 1),
          const ReplyRow(TripStrings.step2Screenshot, '', step: 2),
          const ReplyRow(TripStrings.step3Host, '', step: 3),
        ];
      }
      if (adv.isProofSent || adv.isReceived) {
        return [
          const ReplyRow(TripStrings.stepPaymentSent, '', done: true),
          const ReplyRow(TripStrings.stepScreenshotSent, '', done: true),
          ReplyRow(TripStrings.stepHostChecks, '', done: adv.isReceived),
        ];
      }
      final revised = e.pendingRevised;
      if (revised != null) {
        return [
          const ReplyRow(TripStrings.revisedOffer, TripStrings.notAcceptedYet),
          ReplyRow(TripStrings.total, _inr(revised.total)),
          ReplyRow(TripStrings.dates, _dates(e)),
        ];
      }
      final change = e.pendingChange;
      if (change != null) {
        final a = change.checkIn;
        final b = change.checkOut;
        return [
          const ReplyRow(TripStrings.changeRequest, TripStrings.notAcceptedYet),
          if (a != null && b != null) ReplyRow(TripStrings.dates, TripFormat.dayMonthRange(a, b)),
          ReplyRow(TripStrings.total, _inr(change.total)),
        ];
      }
    }
    if (status == TripDisplayStatus.holdExpired) {
      final hold = e.advance.holdUntil;
      return [
        ReplyRow(TripStrings.dates, '${_dates(e)} · ${TripStrings.nights(e.nights)}'),
        if ((e.advance.amount ?? 0) > 0) ReplyRow(TripStringsRc.advanceAsked, _inr(e.advance.amount)),
        if (hold != null) ReplyRow(TripStrings.holdEnded, TripFormat.time12Of(hold.toLocal())),
      ];
    }
    final counter = e.pendingCounter;
    if (counter != null && e.display.isOpen && !e.isBooked) {
      return [
        if (_listed(x) case final l? when l > 0) ReplyRow(TripStrings.listedLabel, '${_inr(l)} ${TripStringsRc.perNight}'),
        ReplyRow(TripStrings.nights(e.nights), _inr(counter.total)),
        ReplyRow(TripStrings.dates, _dates(e)),
      ];
    }
    return [
      ReplyRow(TripStrings.dates, [_dates(e), TripStrings.nights(e.nights)].where((s) => s.isNotEmpty).join(' · ')),
      if (e.context.peopleLabel case final p?) ReplyRow(TripStrings.people, p),
      if (e.context.roomsLabel case final r?) ReplyRow(TripStrings.rooms, r),
    ];
  }

  (String?, String, ReplyNote?) _note(_Entry x) {
    final e = x.enquiry;
    if (e == null) return (null, ListingArt.clipboard, null);
    final status = x.status;
    final lines = <String>[];
    String art = ListingArt.clipboard;
    void add(String t, String a) {
      if (lines.isEmpty) art = a;
      lines.add(t);
    }

    final wrong = TripRepliesLegParts.wrongCityNote(context, _c, e);
    if (wrong != null) add(wrong.text, ListingArt.roundPushpin);
    if (TripRepliesLegParts.oldDatesNote(_c, e) case final o?) add(o.text, ListingArt.calendar);
    if (status == TripDisplayStatus.confirmedByBoth && e.hasPendingRevised) add('${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}', ListingArt.clipboard);
    if (status == TripDisplayStatus.confirmedByBoth && e.hasPendingChange) add('${TripStrings.changeRequest} · ${TripStrings.notAcceptedYet}', ListingArt.calendar);
    if (status == TripDisplayStatus.confirmedByBoth && e.advance.isPending && (e.advance.amount ?? 0) > 0) {
      add('${TripStrings.payDirectlyToHost} · ${TripStrings.advance} ${_inr(e.advance.amount)}. ${TripStrings.noPaymentTail}', ListingArt.moneyBag);
    }
    if (status == TripDisplayStatus.holdExpired) add('${TripStrings.roomMayBeReleased}. ${TripStrings.ifPaidFooter}', ListingArt.roundPushpin);
    if (e.display.isOpen && e.expiresAt != null) add(TripStrings.closesIn(TripEnquiryRules.closesInLabel(e.expiresAt!, DateTime.now())), ListingArt.calendar);
    if (lines.isEmpty) {
      if (e.display == TripDisplayStatus.closed && e.failReason == 'BookedElsewhere') return (TripStringsRc.closedBookedElsewhere, ListingArt.clipboard, null);
      if (e.isRed) return (TripStrings.allAsksEnded, ListingArt.roundPushpin, null);
      return (TripStrings.termsByHost, ListingArt.clipboard, null);
    }
    return (lines.join('\n'), art, wrong);
  }

  Widget _card(_Entry x, int i) {
    final e = x.enquiry;
    final status = x.status;
    final busy = e != null && TripEnquiryController.to.busyIds.contains(e.id);
    final phone = _phone(x);
    final offer = e?.openOffer;
    final price = _price(x);
    final (noteText, noteArt, noteData) = _note(x);
    final key = '${x.stayId}-${e?.id}';
    final menuKey = _menuKeys.putIfAbsent(key, () => GlobalKey());
    VoidCallback? live(VoidCallback f) => busy ? null : f;

    ReplyAction? primary;
    var chatPrimary = false;
    if (status == TripDisplayStatus.offered && offer != null) {
      primary = ReplyAction(
        label: [TripStrings.acceptOffer, _inr(offer.total)].where((s) => s.isNotEmpty).join(' · '),
        onTap: live(() => TripAcceptSheet.show(context, enquiry: e!, offer: offer)),
      );
    } else if (status == TripDisplayStatus.offered) {
      primary = ReplyAction(label: TripStringsA2.refresh, onTap: live(() => _c.refreshEnquiries()));
    } else if (status == TripDisplayStatus.holdExpired) {
      primary = ReplyAction(label: TripStrings.askOtherStays, onTap: live(() => TripNavigation.openStay(_legIndex)));
    } else if (e != null && e.isRed) {
      primary = ReplyAction(label: TripStrings.findAnother, onTap: live(() => TripNavigation.openStay(_legIndex)));
    } else {
      chatPrimary = true;
      final chat = e?.conversationId != null;
      primary = ReplyAction(label: TripStrings.openChat, onTap: chat ? live(() => TripNavigation.openChatForEnquiry(e!)) : null);
    }

    final call = ReplyAction(label: TripStrings.callHost, onTap: phone == null ? null : live(() => ContactLauncher.call(phone)));
    final ReplyAction second;
    final confirmed = status == TripDisplayStatus.confirmedByYou || status == TripDisplayStatus.confirmedByBoth;
    if (confirmed) {
      final can = status == TripDisplayStatus.confirmedByBoth && !_c.isReadOnly && TripEnquiryRules.isOutsideTrip(e!, _c.settings, _c.dayCount);
      second = ReplyAction(label: TripStrings.sendChangeRequest, onTap: can ? live(() => _sendChange(e)) : null);
    } else {
      final can = e != null && e.canCounter && !_c.isReadOnly && e.display.isOpen;
      second = ReplyAction(
        label: (e?.counterCount ?? 0) > 0 ? TripStringsF2.proposeAgain : TripStrings.proposePrice,
        onTap: can ? live(() => TripCounterSheet.show(context, enquiry: e)) : null,
      );
    }

    final menu = <MenuItem3D>[
      if (!chatPrimary && e?.conversationId != null)
        MenuItem3D(label: TripStrings.openChat, art: ListingArt.speechBalloon, onTap: live(() => TripNavigation.openChatForEnquiry(e!))),
      if (status == TripDisplayStatus.offered && offer != null)
        MenuItem3D(label: TripStrings.decline, art: ListingArt.bed, danger: true, onTap: live(() => _decline(e!))),
      if (status == TripDisplayStatus.offered || status == TripDisplayStatus.asked)
        MenuItem3D(label: TripStrings.withdraw, art: ListingArt.clipboard, danger: true, onTap: live(() => TripWithdrawSheet.show(context, enquiry: e!))),
      if (confirmed)
        MenuItem3D(
          label: TripStrings.cancelBooking,
          art: ListingArt.calendar,
          danger: true,
          onTap: live(() => TripCancelSheet.show(context, enquiry: e!, ownerSide: false)),
        ),
      MenuItem3D(label: TripStrings.report, art: ListingArt.roundPushpin, danger: true, onTap: () => TripReport.stay(context, x.stayId, tripEnquiryId: e?.id)),
    ];

    return ReplyCard3D(
      key: ValueKey('reply-$key'),
      status: StatusTone3D.of(status.name),
      art: _stayArt[i % _stayArt.length],
      pill: _label(x),
      urgent: e?.isUrgent ?? false,
      title: x.name.isEmpty ? TripStrings.stay : x.name,
      statusLine: _statusLine(x),
      cap: price.cap,
      number: price.number,
      unit: price.unit,
      menuKey: menuKey,
      onMenu: () => showReplyMenu(menuKey, menu),
      rows: _rows(x),
      note: noteText,
      noteArt: noteArt,
      noteAction: noteData?.actionLabel,
      onNoteAction: noteData?.onAction,
      primary: busy ? ReplyAction(label: primary.label, busy: true) : primary,
      secondary: [call, second],
    );
  }

  Future<void> _sendChange(TripEnquiryModel e) async {
    final day = e.day;
    final from = day == null || day > _c.dayCount ? null : _c.dateOf(day);
    final to = from == null ? null : DateTime(from.year, from.month, from.day + e.nights);
    final sent = await TripChangeRequestSheet.show(context, enquiry: e, checkIn: from, checkOut: to);
    if (sent && mounted) await _c.refreshEnquiries();
  }
}
