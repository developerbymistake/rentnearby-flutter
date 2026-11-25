import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../screens/trip_replies_leg_parts.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_enquiry_simple.dart';
import '../trip_strings_rc.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_report.dart';
import '../widgets/trip_accept_sheet.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_withdraw_sheet.dart';
import 'similar_stays.dart';

enum TravellerCardKind { waiting, quiet, offer, offerMissing, booked, ended }

class TravellerEnquiryCard extends StatefulWidget {
  const TravellerEnquiryCard({
    super.key,
    required this.enquiry,
    this.phone,
    this.listedPerNight,
    this.busy = false,
    this.readOnly = false,
    this.highlighted = false,
    this.onSimilar,
    this.onFindAnother,
    this.onRefresh,
    this.planNotes = const [],
    this.tripRange,
    this.firstRow,
  });

  final TripEnquiryModel enquiry;
  final String? phone;
  final int? listedPerNight;
  final bool busy;
  final bool readOnly;
  final bool highlighted;
  final VoidCallback? onSimilar;
  final VoidCallback? onFindAnother;
  final VoidCallback? onRefresh;
  final List<(ReplyNote, String)> planNotes;
  final String? tripRange;
  final ReplyRow? firstRow;

  static TravellerCardKind kindOf(TripEnquiryModel e) {
    final s = e.display;
    if (s == TripDisplayStatus.offered) return e.openOffer != null ? TravellerCardKind.offer : TravellerCardKind.offerMissing;
    if (s == TripDisplayStatus.confirmedByYou || s == TripDisplayStatus.confirmedByBoth || s == TripDisplayStatus.bookedByYou) {
      return TravellerCardKind.booked;
    }
    if (s == TripDisplayStatus.asked) return e.isQuiet ? TravellerCardKind.quiet : TravellerCardKind.waiting;
    return TravellerCardKind.ended;
  }

  static String ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String dates(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    return a != null && b != null ? TripFormat.dayMonthRange(a, b) : e.datesLabel;
  }

  static String inr(int? v) => v == null || v <= 0 ? '' : BrowseItem.inr(v);

  static String label(TripEnquiryModel e) {
    if (e.display == TripDisplayStatus.cancelled && e.cancelledBy == 'owner') return TripStrings.hostCancelled;
    if (!e.isOpen) {
      switch (e.endReason) {
        case TripEndReasons.datesChanged:
          return TripStringsEnq.closedDates;
        case TripEndReasons.stayRemoved:
          return TripStringsEnq.stayRemoved;
        case TripEndReasons.stayPaused:
          return TripStringsEnq.notTaking;
        case TripEndReasons.hostBlocked:
          return TripStringsEnq.hostCant;
        case TripEndReasons.hostNotAvailable:
          return TripStrings.notAvailable;
        case TripEndReasons.withdrawn:
          return TripStrings.withdrawn;
        case TripEndReasons.bookedElsewhere:
          return TripStrings.bookedAnother;
      }
    }
    if (e.display == TripDisplayStatus.asked && e.isQuiet) return TripStringsEnq.quietPill;
    if (e.display == TripDisplayStatus.closed) {
      return switch (e.failReason) {
        'Withdrawn' => TripStrings.withdrawn,
        'BookedElsewhere' => TripStrings.bookedAnother,
        _ => TripStrings.closed,
      };
    }
    return TripStatusVisuals.label(e.display);
  }

  // Withdraw with Undo; after the undo window the traveller sees similar stays.
  static Future<void> withdraw(BuildContext context, TripEnquiryModel e, {bool similarAfter = true}) async {
    final row = await TripWithdrawSheet.show(context, enquiry: e);
    if (row == null || !context.mounted) return;
    // The card may leave the list before the undo ends; open the sheet from the root navigator.
    final host = Navigator.of(context, rootNavigator: true).context;
    TripWithdrawSheet.showUndo(context, row, onGone: () {
      if (!similarAfter || !host.mounted || row.tripId == null || row.day == null) return;
      SimilarStaysSheet.show(host, reference: row, title: TripStringsEnq.similarAfterWithdraw);
    });
  }

  static Future<void> decline(BuildContext context, TripEnquiryModel e) async {
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
          subtitle: [dates(e), TripStrings.nights(e.nights)].where((s) => s.isNotEmpty).join(' · '),
          value: inr(offer.total),
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
  State<TravellerEnquiryCard> createState() => _TravellerEnquiryCardState();
}

class _TravellerEnquiryCardState extends State<TravellerEnquiryCard> {
  final _menuKey = GlobalKey();

  TripEnquiryModel get e => widget.enquiry;

  String _statusLine() {
    final now = DateTime.now();
    if (!e.isOpen) {
      switch (e.endReason) {
        case TripEndReasons.stayRemoved:
          return TripStringsEnq.stayRemovedLine;
        case TripEndReasons.stayPaused:
          return TripStringsEnq.notTakingLine;
      }
    }
    final raw = switch (e.display) {
      TripDisplayStatus.asked when e.isQuiet => TripStringsEnq.quietLine(TravellerEnquiryCard.ago(e.createdAt)),
      TripDisplayStatus.asked => TripStrings.askedAgo(TravellerEnquiryCard.ago(e.createdAt)),
      TripDisplayStatus.offered => e.openOffer == null
          ? TripStrings.offerReceived
          : TripStrings.offeredValid(
              TravellerEnquiryCard.inr(e.openOffer!.total),
              e.openOffer!.validUntil == null ? '' : TripEnquiryRules.closesInLabel(e.openOffer!.validUntil!, now)),
      TripDisplayStatus.confirmedByYou || TripDisplayStatus.confirmedByBoth =>
        [TravellerEnquiryCard.dates(e), TravellerEnquiryCard.inr(e.agreedTotal)].where((s) => s.isNotEmpty).join(' · '),
      _ => TravellerEnquiryCard.dates(e),
    };
    return raw.replaceAllMapped(RegExp(r'(\d) (h|min|d)(?!\w)'), (m) => '${m[1]} ${m[2]}');
  }

  ({String? cap, String number, String? unit}) _price() {
    final offer = e.openOffer;
    final nights = TripStrings.nights(e.nights);
    if (e.display == TripDisplayStatus.offered && offer != null) {
      return (cap: TripStrings.total, number: TravellerEnquiryCard.inr(offer.total), unit: nights);
    }
    final agreed = e.agreedTotal;
    if (agreed != null && agreed > 0) {
      return (cap: e.isBooked ? TripStrings.agreed : TripStrings.total, number: TravellerEnquiryCard.inr(agreed), unit: nights);
    }
    final listed = widget.listedPerNight;
    if (listed != null && listed > 0) return (cap: TripStrings.listedLabel, number: TravellerEnquiryCard.inr(listed), unit: TripStringsRc.perNight);
    return (cap: TripStringsRc.nights, number: '${e.nights}', unit: e.datesLabel);
  }

  List<ReplyRow> _rows() {
    final inr = TravellerEnquiryCard.inr;
    final dates = TravellerEnquiryCard.dates;
    final offer = e.openOffer;
    final status = e.display;
    if (status == TripDisplayStatus.offered && offer != null) {
      final each = offer.lines.fold<int>(0, (sum, l) => sum + l.perNight);
      return [
        ReplyRow(offer.nights > 0 && each > 0 ? '${TripStrings.nights(offer.nights)} · ${inr(each)} each' : TripStrings.total, inr(offer.total)),
      ];
    }
    if (status == TripDisplayStatus.confirmedByBoth) {
      final revised = e.pendingRevised;
      if (revised != null) {
        return [
          const ReplyRow(TripStrings.revisedOffer, TripStrings.notAcceptedYet),
          ReplyRow(TripStrings.total, inr(revised.total)),
          ReplyRow(TripStrings.dates, dates(e)),
        ];
      }
      final change = e.pendingChange;
      if (change != null) {
        final a = change.checkIn;
        final b = change.checkOut;
        return [
          const ReplyRow(TripStrings.changeRequest, TripStrings.notAcceptedYet),
          if (a != null && b != null) ReplyRow(TripStrings.dates, TripFormat.dayMonthRange(a, b)),
          ReplyRow(TripStrings.total, inr(change.total)),
        ];
      }
      final share = e.ownerShare;
      if (share != null && (share.upiId != null || share.whatsApp != null)) {
        return [
          ReplyRow(TripStrings.dates, [dates(e), TripStrings.nights(e.nights)].where((s) => s.isNotEmpty).join(' · ')),
          if (share.upiId case final u?) ReplyRow(TripStringsEnq.upi, u),
          if (share.whatsApp case final w?) ReplyRow(TripStringsEnq.whatsApp, w.startsWith('+') ? w : '+91 $w'),
        ];
      }
    }
    return [
      ReplyRow(TripStrings.dates, [dates(e), TripStrings.nights(e.nights)].where((s) => s.isNotEmpty).join(' · ')),
      if (e.context.peopleLabel case final p?) ReplyRow(TripStrings.people, p),
      if (e.context.roomsLabel case final r?) ReplyRow(TripStrings.rooms, r),
    ];
  }

  (String?, String, ReplyNote?) _note() {
    final status = e.display;
    final lines = <String>[];
    String art = ListingArt.clipboard;
    ReplyNote? action;
    void add(String t, String a) {
      if (lines.isEmpty) art = a;
      lines.add(t);
    }

    for (final (n, a) in widget.planNotes) {
      add(n.text, a);
      if (n.actionLabel != null) action ??= n;
    }
    if (status == TripDisplayStatus.confirmedByBoth && e.hasPendingRevised) add('${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}', ListingArt.clipboard);
    if (status == TripDisplayStatus.confirmedByBoth && e.hasPendingChange) add('${TripStrings.changeRequest} · ${TripStrings.notAcceptedYet}', ListingArt.calendar);
    if (e.display.isOpen && e.expiresAt != null) add(TripStrings.closesIn(TripEnquiryRules.closesInLabel(e.expiresAt!, DateTime.now())), ListingArt.calendar);
    if (lines.isEmpty) {
      final range = widget.tripRange;
      if (!e.isOpen && e.endReason == TripEndReasons.datesChanged && range != null) {
        final again = widget.onFindAnother;
        return (
          TripStringsEnq.closedDatesLine(range),
          ListingArt.calendar,
          again == null ? null : ReplyNote(TripStringsEnq.closedDatesLine(range), actionLabel: TripStringsEnq.askAgainFor(range), onAction: again),
        );
      }
      if (e.display == TripDisplayStatus.closed && e.failReason == 'BookedElsewhere') return (TripStringsRc.closedBookedElsewhere, ListingArt.clipboard, null);
      if (e.isRed || !e.isOpen) return (TripStrings.allAsksEnded, ListingArt.roundPushpin, null);
      return (TripStrings.termsByHost, ListingArt.clipboard, null);
    }
    return (lines.join('\n'), art, action);
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy;
    final phone = widget.phone;
    final offer = e.openOffer;
    final price = _price();
    final (noteText, noteArt, noteData) = _note();
    VoidCallback? live(VoidCallback? f) => busy || f == null ? null : f;

    final call = ReplyAction(label: TripStrings.callHost, onTap: phone == null ? null : live(() => ContactLauncher.call(phone)));
    final withdraw = ReplyAction(label: TripStrings.withdraw, onTap: live(() => TravellerEnquiryCard.withdraw(context, e)));
    final similar = ReplyAction(label: TripStringsEnq.seeSimilar, onTap: live(widget.onSimilar));
    final report = ReplyAction(label: TripStrings.report, onTap: () => TripReport.stay(context, e.listingId, tripEnquiryId: e.id));
    final kind = TravellerEnquiryCard.kindOf(e);

    final ReplyAction primary;
    final List<ReplyAction> second;
    final menu = <MenuItem3D>[];
    switch (kind) {
      case TravellerCardKind.waiting:
        primary = call;
        second = [withdraw, similar];
      case TravellerCardKind.quiet:
        primary = similar;
        second = [call, withdraw];
      case TravellerCardKind.offer:
        primary = ReplyAction(
          label: [TripStrings.acceptOffer, TravellerEnquiryCard.inr(offer!.total)].where((s) => s.isNotEmpty).join(' · '),
          onTap: live(() => TripAcceptSheet.show(context, enquiry: e, offer: offer)),
        );
        second = [ReplyAction(label: TripStringsEnq.decline, onTap: live(() => TravellerEnquiryCard.decline(context, e))), call];
        menu.add(MenuItem3D(label: TripStrings.withdraw, art: ListingArt.clipboard, danger: true, onTap: live(() => TravellerEnquiryCard.withdraw(context, e))));
      case TravellerCardKind.offerMissing:
        primary = ReplyAction(label: TripStringsA2.refresh, onTap: live(widget.onRefresh ?? () => TripEnquiryController.to.refreshOne(e.id)));
        second = [call, withdraw];
      case TravellerCardKind.booked:
        primary = call;
        final canCancel = e.isBooked && !widget.readOnly;
        second = [
          ReplyAction(label: TripStrings.cancelBooking, onTap: canCancel ? live(() => TripCancelSheet.show(context, enquiry: e, ownerSide: false)) : null),
          report,
        ];
      case TravellerCardKind.ended:
        primary = widget.onSimilar != null ? similar : ReplyAction(label: TripStrings.findAnother, onTap: live(widget.onFindAnother));
        second = [ReplyAction(label: TripStrings.findAnother, onTap: live(widget.onFindAnother)), report];
    }
    menu.add(MenuItem3D(label: TripStrings.report, art: ListingArt.warning, danger: true, onTap: () => TripReport.stay(context, e.listingId, tripEnquiryId: e.id)));

    final rows = [if (widget.firstRow case final f?) f, ..._rows()];
    Widget card = ReplyCard3D(
      status: e.display == TripDisplayStatus.asked && e.isQuiet ? StatusTone3D.closed : StatusTone3D.of(e.display.name),
      art: ListingArt.stay,
      pill: TravellerEnquiryCard.label(e),
      urgent: e.isUrgent,
      title: e.listingName.isEmpty ? TripStrings.stay : e.listingName,
      statusLine: _statusLine(),
      cap: price.cap,
      number: price.number,
      unit: price.unit,
      menuKey: _menuKey,
      onMenu: () => showReplyMenu(_menuKey, menu),
      rows: rows.length > ReplyCard3D.rowSlots ? rows.sublist(0, ReplyCard3D.rowSlots) : rows,
      note: noteText,
      noteArt: noteArt,
      noteAction: noteData?.actionLabel,
      onNoteAction: noteData?.onAction,
      primary: busy ? ReplyAction(label: primary.label, busy: true) : primary,
      secondary: second,
    );
    if (widget.highlighted) {
      card = DecoratedBox(decoration: BoxDecoration(color: ListingTone.forest.tint, borderRadius: DS.circular(28)), child: card);
    }
    return card;
  }
}
