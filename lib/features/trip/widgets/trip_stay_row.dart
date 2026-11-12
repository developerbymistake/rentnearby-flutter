import 'trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../models/browse_item.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_algo_aa.dart';
import '../trip_strings_fin_b1.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_format.dart';
import '../utils/trip_stay_rank.dart';
import '../trip_strings_shortlist.dart';
import 'trip_shortlist_toggle.dart';
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
    this.onAsk,
    this.fit,
    this.onShortlist,
    this.shortlisted = false,
    this.shortlistBusy = false,
    this.noReply = false,
  });

  final StayNearbyModel stay;
  final TripStayFit? fit;
  final TripDisplayStatus? status;
  final String? statusLine;
  final VoidCallback? onOpenChat;
  final bool readOnly;
  final VoidCallback onOpen;
  final VoidCallback? onCall;
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

  bool get _paused => !stay.isActive;

  @override
  Widget build(BuildContext context) {
    final actions = _actions(context);
    return EntranceOnce(
      child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev2,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: CardRadius.tile,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onOpen,
                splashColor: DesignColors.splash,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: _body(),
                ),
              ),
              ?actions,
            ],
          ),
        ),
      ),
    ));
  }

  Widget _thumb() => KitPhoto(
        url: stay.thumbnailUrl,
        width: thumb,
        height: thumb,
        tone: KitTone.stay,
        asset: TravelIcon.stay,
        radius: KitMetrics.tileSmall,
        dimmed: _paused,
      );

  Widget _body() {
    final type = quoteLine(stay, fit);
    final facts = statusLine ?? factsLine(stay);
    final quote = fit?.fits == true ? fit?.quotePerNight : null;
    final price = quote ?? stay.minPricePerNight;
    final nearKm = fit != null && fit!.nearestKm.isFinite ? fit!.nearestKm : stay.distanceKm;
    final noFit = fit?.fits == false && !_paused;
    final st = status;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumb(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stay.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(14, FontWeight.w700,
                          color: _paused ? DesignColors.textMuted : DesignColors.textStrong, height: 1.2),
                    ),
                  ),
                  if (nearKm > 0) ...[
                    const SizedBox(width: 8),
                    KitTagChip(TripFormat.km(nearKm), tone: KitTone.stay),
                  ],
                ],
              ),
              if (_paused || st != null || stay.isFeatured || noFit || noReply) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_paused) KitTagChip(TripStrings.notAvailableNow, color: TripUi.bad),
                    if (st != null)
                      KitTagChip(
                        st == TripDisplayStatus.asked ? TripStringsA2.asked : TripStatusVisuals.label(st),
                        color: TripStatusVisuals.text(st),
                      ),
                    if (stay.isFeatured && !_paused) KitTagChip(TripStringsA2.featured, color: TripUi.gold),
                    if (noFit) KitTagChip(TripStringsAlgoAa.doesNotFit, color: TripUi.warn),
                    if (noReply) KitTagChip(TripStringsShortlist.noReply, color: TripUi.warn),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _paused ? TripStrings.stayPaused : (type ?? TripStringsA2.stay),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(12, FontWeight.w600, color: KitTone.stay.accentDark),
              ),
              if (stay.locality.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const TravelIcon(TravelIcon.place, size: 12),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(stay.locality, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
                    ),
                  ],
                ),
              ],
              if (facts != null && !_paused) ...[
                const SizedBox(height: 2),
                Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
              ],
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: price == null
                    ? Text(TripStringsA2.priceOnRequest, style: TypeTokens.style(13, FontWeight.w700))
                    : Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: BrowseItem.inr(price),
                              style: TypeTokens.style(15, FontWeight.w800, color: KitTone.stay.accentDark),
                            ),
                            TextSpan(
                              text: ' ${quote != null ? TripStringsAlgoAa.perNightGroup : TripStringsA2.perNightListed}',
                              style: TypeTokens.caption,
                            ),
                          ],
                        ),
                        maxLines: 1,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _actions(BuildContext context) {
    if (_paused || readOnly) return null;
    final st = status;
    final Widget ask;
    if (st != null && onOpenChat != null) {
      ask = SecondaryButton(
        label: TripStrings.openChat,
        onPressed: onOpenChat,
        tone: KitTone.stay,
        height: 44,
        icon: const TravelIcon(TravelIcon.chat, size: 18),
      );
    } else if (st != null) {
      ask = SecondaryButton(
        label: TripStringsV2Find.asked,
        onPressed: null,
        tone: KitTone.stay,
        height: 44,
        icon: const TravelIcon(TravelIcon.note, size: 18),
      );
    } else if (onShortlist != null) {
      ask = TripShortlistToggle(selected: shortlisted, busy: shortlistBusy, onTap: onShortlist, tone: KitTone.stay);
    } else {
      ask = PrimaryButton(
        label: TripStringsV2Find.ask,
        onPressed: onAsk,
        tone: KitTone.stay,
        height: 44,
        icon: const TravelIcon(TravelIcon.chat, size: 18),
      );
    }
    final call = SecondaryButton(
      label: TripStringsV2Find.call,
      onPressed: onCall,
      tone: KitTone.stay,
      height: 44,
      icon: Icon(Icons.call_rounded, size: 16, color: KitTone.stay.accentDark),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [call, const SizedBox(height: 8), ask])
          : Row(children: [Expanded(child: call), const SizedBox(width: 8), Expanded(child: ask)]),
    );
  }
}

class TripStayRowSkeleton extends StatelessWidget {
  const TripStayRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    double line(double size) => scale.scale(size) * 1.5;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TemplatePlaceholder(width: TripStayRow.thumb, height: TripStayRow.thumb, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TemplatePlaceholder(width: 160, height: line(14), radius: 6),
                        const SizedBox(height: 4),
                        TemplatePlaceholder(width: 130, height: line(12), radius: 6),
                        const SizedBox(height: 2),
                        TemplatePlaceholder(width: 110, height: line(11), radius: 6),
                        const SizedBox(height: 6),
                        TemplatePlaceholder(width: 120, height: line(15), radius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: TripStayRow.actionHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(child: TemplatePlaceholder(height: 44, radius: 24)),
                    SizedBox(width: 12),
                    Expanded(child: TemplatePlaceholder(height: 44, radius: 24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
