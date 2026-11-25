import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../design/extra/ext_trip_replies.dart';
import '../../stay/enquiries/stay_enquiries_controller.dart';
import '../../stay/enquiries/stay_enquiry_actions.dart';
import '../../stay/enquiries/stay_enquiry_format.dart';
import '../../stay/enquiries/stay_enquiry_owner_view.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/models/trip_offer_model.dart';
import '../../owner_core/home/numbers_row.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_work_strings.dart';
import 'stay_work_format.dart';
import 'widgets/enquiry_card_parts.dart';

class StayOwnerEnquiryCard extends StatefulWidget {
  const StayOwnerEnquiryCard({super.key, required this.enquiry, required this.view, required this.ctrl, this.highlighted = false, this.expanded = false});

  final TripEnquiryModel enquiry;
  final StayEnquiryOwnerView view;
  final StayEnquiriesController ctrl;
  final bool highlighted;
  final bool expanded;

  @override
  State<StayOwnerEnquiryCard> createState() => _StayOwnerEnquiryCardState();
}

class _StayOwnerEnquiryCardState extends State<StayOwnerEnquiryCard> {
  final _menuKey = GlobalKey();
  late bool _open = widget.expanded;

  TripEnquiryModel get e => widget.enquiry;
  StayEnquiryOwnerView get v => widget.view;

  @override
  void didUpdateWidget(covariant StayOwnerEnquiryCard old) {
    super.didUpdateWidget(old);
    if (widget.expanded && !old.expanded) _open = true;
  }

  String get _guest => StayEnquiryFormat.guest(e);

  String? get _roomName {
    for (final p in v.listedBreakdown) {
      final n = p.roomName;
      if (n != null && n.isNotEmpty) return n;
    }
    for (final o in [e.acceptedOffer, e.openOffer, e.pendingCounter]) {
      if (o == null) continue;
      for (final l in o.lines) {
        final n = l.roomName;
        if (n != null && n.isNotEmpty) return n;
      }
    }
    return null;
  }

  String get _roomsNights => StayWorkStrings.roomsNights(StayWorkFormat.rooms(e), e.nights);

  bool get _open2 => e.status == TripEnquiryStatuses.asked || e.status == TripEnquiryStatuses.offered || e.status == TripEnquiryStatuses.countered;

  String get _title {
    final urgent = _open2 && (e.isUrgent || StayWorkFormat.startsWithin72h(e, StayWorkFormat.now()));
    return urgent ? '${StayWorkStrings.urgentPrefix}$_guest' : _guest;
  }

  int? get _agreedPerNight {
    final o = e.acceptedOffer;
    if (o != null && o.lines.isNotEmpty) return o.lines.first.pricePerNight;
    final t = e.agreedTotal;
    final n = e.nights * StayWorkFormat.rooms(e);
    return t != null && t > 0 && n > 0 ? (t / n).round() : null;
  }

  Future<void> _run(Future<bool> Function() call) async {
    await call();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = widget.ctrl.busyIds.contains(e.id);
      final card = _card(context, busy);
      if (!widget.highlighted) return card;
      return DecoratedBox(
        decoration: BoxDecoration(color: ListingTone.forest.tint, borderRadius: DS.circular(28)),
        child: card,
      );
    });
  }

  Widget _card(BuildContext context, bool busy) {
    switch (e.status) {
      case TripEnquiryStatuses.asked:
      case TripEnquiryStatuses.countered:
        return _newCard(context, busy);
      case TripEnquiryStatuses.offered:
        return _offeredCard(context, busy);
      case TripEnquiryStatuses.confirmedByBoth:
      case TripEnquiryStatuses.confirmedByTraveller:
        if (!StayEnquiryBucket.hasEnded(e)) {
          final change = e.pendingChange;
          if (change != null) return _changeCard(context, change, busy);
          return _confirmedCard(context, busy);
        }
        return _closedCard(context);
      default:
        return _closedCard(context);
    }
  }

  Widget _tap(Widget child) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _open = !_open), child: child);

  EnquiryButton _callButton() => EnquiryButton(StayWorkStrings.call, EnquiryButtonKind.plain, () => StayEnquiryActions.callGuest(e));

  List<EnquiryButton> _newButtons(BuildContext context, {required String primary}) => [
        if (e.offersLeft != 0) EnquiryButton(primary, EnquiryButtonKind.primary, () => _run(() => StayEnquiryActions.sendOffer(context, e))),
        EnquiryButton(StayWorkStrings.notAvailable, EnquiryButtonKind.danger, () => _run(() => StayEnquiryActions.notAvailable(context, e))),
        if (StayEnquiryActions.canCall(e)) _callButton(),
      ];

  Widget _newCard(BuildContext context, bool busy) {
    final listed = v.listedStayTotal;
    final leftText = StayWorkFormat.left(e.expiresAt, StayWorkFormat.now());
    final room = _roomName;
    final city = e.context.city;
    final days = StayWorkFormat.daysUntil(e.tripStartDate ?? e.checkIn, StayWorkFormat.now());
    final trip = [if (city.isNotEmpty) city, if (days != null && days > 0) StayWorkStrings.tripInDays(days)].join(' · ');
    final asked = e.pendingCounter?.pricePerNight;
    return EnquiryCardFrame(
      semantics: _title,
      children: [
        _tap(EnquiryHeadParts(
          eyebrow: StayWorkStrings.newEnquiry,
          left: leftText == null ? null : StayWorkStrings.timeLeft(leftText),
          leftShort: StayWorkFormat.short(e.expiresAt, StayWorkFormat.now()),
          title: _title,
          priceLine: listed == null ? null : StayWorkStrings.listedWhenAskedPrice(StayWorkFormat.inr(listed)),
        )),
        _facts(),
        if (_open)
          EnquiryRows(rows: [
            if (room != null) EnquiryKv(StayWorkStrings.room, room),
            if (trip.isNotEmpty) EnquiryKv(StayWorkStrings.trip, trip),
            if (asked != null && asked > 0) EnquiryKv(StayWorkStrings.guestAsked, StayWorkStrings.perNight(StayWorkFormat.inr(asked))),
          ]),
        EnquiryButtons(busy: busy, buttons: _newButtons(context, primary: StayWorkStrings.sendOffer)),
      ],
    );
  }

  Widget _facts() {
    final g = StayWorkFormat.guests(e);
    return Container(
      margin: EdgeInsets.only(top: DS.gv(10)),
      decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Ink3D.line))),
      child: OwnerFacts(labelFirst: true, facts: [
        NumberTile(label: StayWorkStrings.datesLabel, value: StayWorkFormat.dates(e)),
        if (g > 0) NumberTile(label: StayWorkStrings.guestsHead, value: StayWorkStrings.guests(g)),
        NumberTile(label: StayWorkStrings.roomsLabel, value: StayWorkStrings.rooms(StayWorkFormat.rooms(e))),
      ]),
    );
  }

  String get _firstName {
    final g = _guest.trim();
    final i = g.indexOf(' ');
    return i > 0 ? g.substring(0, i) : g;
  }

  Widget _offeredCard(BuildContext context, bool busy) {
    final o = e.openOffer;
    final line = o != null && o.lines.isNotEmpty ? o.lines.first : null;
    final room = line?.roomName ?? _roomName;
    final price = line?.pricePerNight;
    final valid = o?.validUntil;
    final now = StayWorkFormat.now();
    return EnquiryCardFrame(
      semantics: _title,
      children: [
        EnquiryHead(name: _title, lines: [StayWorkFormat.datesGuests(e), _roomsNights], chip: const EnquiryChip(StayWorkStrings.chipOffered, EnquiryChipTone.indigo)),
        EnquiryRows(rows: [
          if (price != null && price > 0)
            EnquiryKv(StayWorkStrings.yourOffer, room == null ? StayWorkStrings.perNight(StayWorkFormat.inr(price)) : StayWorkStrings.roomPerNight(room, StayWorkFormat.inr(price))),
          if (o != null && o.total > 0) EnquiryKv(StayWorkStrings.total, StayWorkFormat.inr(o.total)),
          if (valid != null && valid.isAfter(now)) EnquiryKv(StayWorkStrings.validUntil, StayWorkFormat.clock(valid), pill: EnquiryChipTone.amber),
          EnquiryKv(StayWorkStrings.offersSent, StayWorkStrings.nOfThree(e.offerCount < 1 ? 1 : e.offerCount)),
        ]),
        EnquiryButtons(busy: busy, buttons: _newButtons(context, primary: StayWorkStrings.sendNewOffer)),
      ],
    );
  }

  void _confirmedMenu(BuildContext context) {
    showReplyMenu(_menuKey, [
      if ((e.traveller.id ?? '').isNotEmpty)
        MenuItem3D(label: StayWorkStrings.reportTraveller, art: ListingArt.warning, onTap: () => StayEnquiryActions.reportTraveller(context, e)),
      MenuItem3D(label: StayWorkStrings.cancelBooking, art: ListingArt.locked, danger: true, onTap: () => StayEnquiryActions.cancel(context, e)),
    ]);
  }

  Widget _confirmedCard(BuildContext context, bool busy) {
    final per = _agreedPerNight;
    final room = _roomName;
    final revised = e.pendingRevised;
    final revisedPer = revised?.pricePerNight;
    final total = e.agreedTotal;
    final confirmedAt = v.confirmedAt ?? e.acceptedOffer?.respondedAt;
    final a = e.checkIn;
    final b = e.checkOut;
    final entry = v.calendarEntryId;
    final lines = _open
        ? [StayWorkFormat.datesGuests(e), total != null && total > 0 ? '$_roomsNights · ${StayWorkStrings.offerAmount(StayWorkFormat.inr(total))}' : _roomsNights]
        : [StayWorkFormat.datesGuests(e), ?room];
    return EnquiryCardFrame(
      semantics: _guest,
      children: [
        _tap(EnquiryHead(
          name: _guest,
          lines: lines,
          chip: const EnquiryChip(StayWorkStrings.chipConfirmed, EnquiryChipTone.green),
          menuKey: _menuKey,
          menuLabel: StayWorkStrings.moreActionsFor(_guest),
          onMenu: () => _confirmedMenu(context),
        )),
        if (v.problemReported)
          EnquiryNote(text: StayWorkStrings.problemStrip, art: ListingArt.warning, tone: EnquiryChipTone.red, action: StayWorkStrings.open, onAction: () => setState(() => _open = true)),
        if (!_open && per != null) EnquiryRows(rows: [EnquiryKv(StayWorkStrings.agreedPrice, StayWorkStrings.perNight(StayWorkFormat.inr(per)))]),
        if (!_open && revisedPer != null) ...[
          EnquiryNote(text: StayWorkStrings.revisedNote(StayWorkFormat.inr(revisedPer)), art: ListingArt.clipboard, tone: EnquiryChipTone.indigo),
          Padding(
            padding: EdgeInsets.only(top: DS.gv(6)),
            child: Text(StayWorkStrings.revisedLine(_firstName), style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
          ),
        ],
        if (_open) ...[
          EnquiryRows(rows: [
            if (room != null) EnquiryKv(StayWorkStrings.room, room),
            if (confirmedAt != null && e.isConfirmedByBoth) EnquiryKv(StayWorkStrings.confirmed, StayWorkStrings.byBoth(StayWorkFormat.dayMonth(confirmedAt.toLocal()))),
            if (entry != null && a != null && b != null)
              EnquiryKv(StayWorkStrings.inYourCalendar, StayWorkFormat.range(a, b), valueColor: EnquiryChipTone.indigo.color, onTap: () => StayOwnerDeps.openEntry(entry)),
          ]),
          EnquiryNote(text: StayWorkStrings.moneyOutside, art: ListingArt.pushpin, tone: EnquiryChipTone.grey),
        ],
        EnquiryButtons(busy: busy, buttons: [
          if (e.isConfirmedByBoth) EnquiryButton(StayWorkStrings.shareUpiWhatsApp, EnquiryButtonKind.primary, () => _share(context)),
          if (StayEnquiryActions.canCall(e)) _callButton(),
        ]),
      ],
    );
  }

  Future<void> _share(BuildContext context) async {
    if (!await StayEnquiryActions.confirmShare(context) || !mounted) return;
    if (await StayEnquiryActions.sendShareCard(e)) AppToast.success(StayWorkStrings.shared);
  }

  Widget _changeCard(BuildContext context, TripOfferModel change, bool busy) {
    final room = _roomName;
    final a = e.checkIn;
    final b = e.checkOut;
    final na = change.checkIn;
    final nb = change.checkOut;
    final oldDates = a != null && b != null ? StayWorkFormat.range(a, b) : null;
    final newDates = na != null && nb != null ? StayWorkFormat.range(na, nb) : null;
    final oldGuests = StayWorkFormat.guests(e);
    final newGuests = (change.adults ?? 0) + (change.kids ?? 0) > 0 ? (change.adults ?? 0) + (change.kids ?? 0) : change.guests;
    final per = _agreedPerNight;
    final until = change.validUntil;
    return EnquiryCardFrame(
      semantics: _guest,
      children: [
        EnquiryHead(
          name: _guest,
          lines: [room == null ? StayWorkStrings.confirmed : StayWorkStrings.confirmedRoom(room)],
          chip: const EnquiryChip(StayWorkStrings.chipChangeRequest, EnquiryChipTone.amber),
        ),
        EnquiryRows(rows: [
          if (newDates != null && newDates != oldDates) EnquiryKv(StayWorkStrings.dates, newDates, old: oldDates, valueColor: EnquiryChipTone.indigo.color),
          if (newGuests > 0 && newGuests != oldGuests)
            EnquiryKv(StayWorkStrings.guestsLabel, '$newGuests', old: oldGuests > 0 ? '$oldGuests' : null, valueColor: EnquiryChipTone.indigo.color),
          if (per != null) EnquiryKv(StayWorkStrings.agreedPrice, StayWorkStrings.perNight(StayWorkFormat.inr(per))),
          if (StayWorkFormat.left(until, StayWorkFormat.now()) case final left?)
            EnquiryKv(StayWorkStrings.answerWithin, left, pill: StayWorkFormat.short(until, StayWorkFormat.now()) ? EnquiryChipTone.red : EnquiryChipTone.grey),
        ]),
        EnquiryNote(text: StayWorkStrings.changeInfo, art: ListingArt.calendar, tone: EnquiryChipTone.grey),
        // Kept on purpose: older app builds can still send a change request.
        EnquiryButtons(busy: busy, buttons: [
          EnquiryButton(StayWorkStrings.acceptChange, EnquiryButtonKind.primary, () => _run(() => StayEnquiryActions.acceptChange(context, e, change.id))),
          EnquiryButton(StayWorkStrings.cancelBooking, EnquiryButtonKind.danger, () => _run(() => StayEnquiryActions.cancel(context, e))),
        ]),
      ],
    );
  }

  static EnquiryChip? closedChip(StayClosedKind k) => switch (k) {
        StayClosedKind.expired => const EnquiryChip(StayWorkStrings.closedExpired, EnquiryChipTone.grey),
        StayClosedKind.offerDeclined => const EnquiryChip(StayWorkStrings.closedOfferDeclined, EnquiryChipTone.grey),
        StayClosedKind.offerExpired => const EnquiryChip(StayWorkStrings.closedOfferExpired, EnquiryChipTone.grey),
        StayClosedKind.travellerLeft => const EnquiryChip(StayWorkStrings.closedTravellerLeft, EnquiryChipTone.grey),
        StayClosedKind.bookedElsewhere => const EnquiryChip(StayWorkStrings.closedBookedElsewhere, EnquiryChipTone.grey),
        StayClosedKind.bookedByPhone => const EnquiryChip(StayWorkStrings.closedBookedByPhone, EnquiryChipTone.green),
        StayClosedKind.cancelledByGuest => const EnquiryChip(StayWorkStrings.closedCancelledByGuest, EnquiryChipTone.red),
        StayClosedKind.cancelledByOwner => const EnquiryChip(StayWorkStrings.closedCancelledByYou, EnquiryChipTone.red),
        StayClosedKind.closedByAdmin => const EnquiryChip(StayWorkStrings.closedByBakhli, EnquiryChipTone.grey),
        StayClosedKind.notAvailable => const EnquiryChip(StayWorkStrings.closedNotAvailable, EnquiryChipTone.grey),
        StayClosedKind.unknown => null,
      };

  String _closedDetail(StayClosedKind k) => switch (k) {
        StayClosedKind.expired => StayWorkStrings.detailNoReply,
        StayClosedKind.travellerLeft => StayWorkStrings.detailTripCancelled,
        StayClosedKind.bookedByPhone => StayWorkStrings.detailByPhone,
        _ => _roomName ?? '',
      };

  void _closedMenu(BuildContext context) {
    showReplyMenu(_menuKey, [
      if ((e.traveller.id ?? '').isNotEmpty) ...[
        MenuItem3D(label: StayWorkStrings.reportTraveller, art: ListingArt.warning, onTap: () => StayEnquiryActions.reportTraveller(context, e)),
        MenuItem3D(label: StayWorkStrings.block, art: ListingArt.locked, danger: true, onTap: () => StayEnquiryActions.block(context, e)),
      ],
    ]);
  }

  Widget _closedCard(BuildContext context) {
    final kind = v.closedKind(e);
    final detail = _closedDetail(kind);
    final dates = StayWorkFormat.dates(e);
    final cancelledByYou = kind == StayClosedKind.cancelledByOwner;
    final when = v.cancelledAt ?? e.updatedAt;
    final reason = e.cancelReason;
    final entry = v.calendarEntryId;
    final hasMenu = (e.traveller.id ?? '').isNotEmpty;
    return EnquiryCardFrame(
      semantics: _guest,
      children: [
        _tap(EnquiryHead(
          name: _guest,
          lines: [
            detail.isEmpty ? dates : '$dates · $detail',
            if (_open && cancelledByYou && when != null) StayWorkStrings.cancelledByYouOn(StayWorkFormat.dayMonth(when.toLocal())),
          ],
          chip: closedChip(kind),
          menuKey: _menuKey,
          menuLabel: StayWorkStrings.moreActionsFor(_guest),
          onMenu: hasMenu ? () => _closedMenu(context) : null,
        )),
        if (v.problemReported) EnquiryNote(text: StayWorkStrings.problemStrip, art: ListingArt.warning, tone: EnquiryChipTone.red),
        if (_open && cancelledByYou) ...[
          if (reason != null && reason.trim().isNotEmpty) EnquiryRows(rows: [EnquiryKv(StayWorkStrings.reason, reason.trim())]),
          EnquiryButtons(buttons: [
            if (entry != null) EnquiryButton(StayWorkStrings.calendarEntry, EnquiryButtonKind.plain, () => StayOwnerDeps.openEntry(entry)),
          ]),
        ],
      ],
    );
  }
}
