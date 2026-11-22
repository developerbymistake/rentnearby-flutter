import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../design/extra/stay_photo_card.dart';
import '../../nearby/card_strings.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/listing_contact_actions.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_algo_aa.dart';
import '../trip_strings_fin_b1.dart';
import '../trip_strings_final_aa.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_format.dart';
import '../utils/trip_stay_rank.dart';
import '../trip_strings_shortlist.dart';
import '../trip_strings_dated_price.dart';
import 'trip_status.dart';

class TripStayRow extends StatelessWidget {
  const TripStayRow({
    super.key,
    required this.stay,
    required this.onOpen,
    this.status,
    this.statusLine,
    this.onOpenChat,
    this.readOnly = false,
    this.onCall,
    this.callBusy = false,
    this.onAsk,
    this.fit,
    this.onShortlist,
    this.shortlisted = false,
    this.shortlistBusy = false,
    this.noReply = false,
    this.tone,
    this.index = 0,
  });

  final StayNearbyModel stay;
  final ListingTone? tone;
  final int index;
  final TripStayFit? fit;
  final TripDisplayStatus? status;
  final String? statusLine;
  final VoidCallback? onOpenChat;
  final bool readOnly;
  final VoidCallback onOpen;
  final VoidCallback? onCall;
  final bool callBusy;
  final VoidCallback? onAsk;
  final VoidCallback? onShortlist;
  final bool shortlisted;
  final bool shortlistBusy;
  final bool noReply;

  static const double thumb = 88;
  static const double actionHeight = 56;

  static String? quoteLine(StayNearbyModel s, TripStayFit? f) {
    final lines = f == null || f.fits != true
        ? const <TripStayQuoteLine>[]
        : f.quoteLines;
    if (lines.isEmpty) return typeLine(s);
    final rooms = [
      for (final l in lines)
        if (l.units > 0 && l.roomName.trim().isNotEmpty)
          TripStringsAlgoAa.quoteLine(l.roomName.trim(), l.units),
    ];
    if (rooms.isEmpty) return typeLine(s);
    final type = s.stayTypeName?.trim() ?? '';
    return [if (type.isNotEmpty) type, rooms.join(' + ')].join(' · ');
  }

  static String? typeLine(StayNearbyModel s) {
    final room = s.bestRoomName?.trim() ?? '';
    final guests = room.isNotEmpty ? s.bestRoomGuests : s.maxGuests;
    final guestsText = guests != null && guests > 0
        ? TripStringsA2.guests(guests)
        : null;
    final parts = [
      if (s.stayTypeName != null && s.stayTypeName!.trim().isNotEmpty)
        s.stayTypeName!.trim(),
      if (room.isNotEmpty)
        TripStringsFinB1.roomLine(room, guestsText)
      else
        ?guestsText,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _mealLabel(String raw) {
    final v = raw.trim();
    for (final m in StayOptionSets.meals) {
      if (m.value == v) return m.label;
    }
    return v;
  }

  static String _checkIn(String hhmm) =>
      TripFormat.time12(hhmm).replaceFirst(':00 ', ' ');

  static String? factsLine(StayNearbyModel s) {
    final meals = (s.meals ?? '')
        .split('·')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .map(_mealLabel)
        .toSet()
        .toList();
    final time = s.checkInTime;
    final parts = [
      ...meals,
      if (time != null && time.trim().isNotEmpty)
        TripStringsA2.checkIn(_checkIn(time.trim())),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @visibleForTesting
  static Future<void> Function(String phone) dial = ContactLauncher.call;

  static Future<void> call(BuildContext context, StayNearbyModel s, {Map<String, dynamic>? detailArguments}) async {
    final raw = s.ownerPhone;
    if (raw != null && ContactLauncher.tenDigits(raw).isNotEmpty) return dial(raw);
    await ListingContactActions.call(context, kind: ListingKind.stay, id: s.id, detailArguments: detailArguments);
  }

  bool get _paused => !stay.isActive;

  @override
  Widget build(BuildContext context) {
    final type = quoteLine(stay, fit);
    final facts = factsLine(stay);
    final full = stay.fullOnDates && !_paused;
    final dated = full ? null : stay.datesPerNight;
    final quote = dated ?? (fit?.fits == true ? fit?.quotePerNight : null);
    final price = quote ?? stay.minPricePerNight;
    final was = dated == null ? null : stay.struckBase;
    final offChip = dated == null || was == null ? null : stay.priceChip?.text;
    final nearKm = fit != null && fit!.nearestKm.isFinite ? fit!.nearestKm : stay.distanceKm;
    final noFit = fit?.fits == false && !_paused;
    final st = status;
    final line = _paused ? null : statusLine;
    final km = nearKm > 0 ? TripStringsFinalAa.kmAway(nearKm) : null;
    final locality = stay.locality.trim();
    return EntranceOnce(
      child: StayPhotoCard(
        palette: CalmCard.stayAt(index),
        photoUrl: stay.thumbnailUrl,
        featured: stay.isFeatured && !_paused,
        title: stay.title,
        place: locality,
        leadChip: full ? TripStringsDatedPrice.fullOnDates : null,
        chips: [
          if (_paused) TripStrings.stayPaused,
          if (_paused) TripStrings.notAvailableNow,
          if (st != null) st == TripDisplayStatus.asked ? TripStringsA2.asked : TripStatusVisuals.label(st),
          if (noFit) TripStringsAlgoAa.doesNotFit,
          if (noReply) TripStringsShortlist.noReply,
          if (!_paused && type != null) ...type.split(' · '),
          if (facts != null && !_paused && line == null) ...facts.split(' · '),
        ],
        caption: price == null ? null : CardStrings.from,
        price: price == null ? TripStringsA2.priceOnRequest : BrowseItem.inr(price),
        unit: price == null ? '' : CardStrings.perNight,
        was: was == null ? null : BrowseItem.inr(was),
        offTag: offChip,
        address: km ?? line ?? (locality.isEmpty ? null : CardStrings.inPlace(locality)),
        note: km != null ? line : null,
        actions: _actions(full),
        dimmed: _paused,
        onTap: onOpen,
      ),
    );
  }

  List<CalmAction> _actions(bool full) {
    if (_paused || readOnly) return const [];
    final st = status;
    final call = CalmAction(kind: CalmActionKind.call, label: TripStringsV2Find.call, onTap: onCall, busy: callBusy);
    final CalmAction second;
    if (st != null && onOpenChat != null) {
      second = CalmAction(kind: CalmActionKind.plain, icon: Icons.chat_bubble_outline_rounded, label: TripStrings.openChat, onTap: onOpenChat);
    } else if (st != null) {
      second = const CalmAction(kind: CalmActionKind.disabled, label: TripStringsV2Find.asked);
    } else if (onShortlist != null && full && !shortlisted) {
      second = const CalmAction(kind: CalmActionKind.disabled, label: TripStringsDatedPrice.full);
    } else if (onShortlist != null) {
      second = CalmAction(
        kind: CalmActionKind.primary,
        label: shortlisted ? TripStringsShortlist.shortlisted : TripStringsShortlist.shortlist,
        onTap: onShortlist,
        selected: shortlisted,
        busy: shortlistBusy,
      );
    } else {
      second = CalmAction(kind: CalmActionKind.plain, icon: Icons.send_rounded, label: TripStringsV2Find.ask, onTap: onAsk);
    }
    return [call, second];
  }
}

class TripStayRowSkeleton extends StatelessWidget {
  const TripStayRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const WideCardSkeleton(kind: WideKind.photo);
}
