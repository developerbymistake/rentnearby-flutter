import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
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
    this.onWhatsApp,
    this.onAsk,
    this.fit,
  });

  final StayNearbyModel stay;
  final TripStayFit? fit;
  final TripDisplayStatus? status;
  final String? statusLine;
  final VoidCallback? onOpenChat;
  final bool readOnly;
  final VoidCallback onOpen;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onAsk;

  static const double thumb = 56;
  static const double actionHeight = 56;

  static String? quoteLine(StayNearbyModel s, TripStayFit? f) {
    final lines = f == null || f.fits != true ? const <TripStayQuoteLine>[] : f.quoteLines;
    if (lines.isEmpty) return typeLine(s);
    final rooms = [for (final l in lines) if (l.units > 0 && l.roomName.trim().isNotEmpty) TripStringsAlgoAa.quoteLine(l.roomName.trim(), l.units)];
    if (rooms.isEmpty) return typeLine(s);
    final type = s.stayTypeName?.trim() ?? '';
    return [if (type.isNotEmpty) type, rooms.join(' + ')].join(' · ');
  }

  static String? typeLine(StayNearbyModel s) {
    final room = s.bestRoomName?.trim() ?? '';
    final guests = room.isNotEmpty ? s.bestRoomGuests : s.maxGuests;
    final guestsText = guests != null && guests > 0 ? TripStringsA2.guests(guests) : null;
    final parts = [
      if (s.stayTypeName != null && s.stayTypeName!.trim().isNotEmpty) s.stayTypeName!.trim(),
      if (room.isNotEmpty) TripStringsFinB1.roomLine(room, guestsText) else ?guestsText,
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

  static String _checkIn(String hhmm) => TripFormat.time12(hhmm).replaceFirst(':00 ', ' ');

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
      if (time != null && time.trim().isNotEmpty) TripStringsA2.checkIn(_checkIn(time.trim())),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  bool get _paused => !stay.isActive;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _paused ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: StayColors.accent.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: _body(),
                ),
              ),
              ?_actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb() => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: thumb,
          height: thumb,
          child: (stay.thumbnailUrl == null || stay.thumbnailUrl!.isEmpty)
              ? _placeholder()
              : CachedNetworkImage(
                  imageUrl: stay.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppColors.surfaceWarm),
                  errorWidget: (_, _, _) => _placeholder(),
                ),
        ),
      );

  Widget _placeholder() => Container(
        color: StayColors.surface,
        alignment: Alignment.center,
        child: const Icon(Iconsax.building_4, size: 22, color: StayColors.accent),
      );

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
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
                    child: Text(stay.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ),
                  if (nearKm > 0) ...[
                    const SizedBox(width: 8),
                    _pill(TripFormat.km(nearKm), StayColors.accentDark, StayColors.surface),
                  ],
                ],
              ),
              if (_paused || st != null || stay.isFeatured || noFit) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_paused) _pill(TripStrings.notAvailableNow, AppColors.error, AppColors.errorSurface),
                    if (st != null)
                      _pill(
                        st == TripDisplayStatus.asked ? TripStringsA2.asked : TripStatusVisuals.label(st),
                        TripStatusVisuals.text(st),
                        TripStatusVisuals.surface(st),
                      ),
                    if (stay.isFeatured && !_paused) _pill(TripStringsA2.featured, AppColors.gold, AppColors.surfaceWarm),
                    if (noFit) _pill(TripStringsAlgoAa.doesNotFit, AppColors.warningText, AppColors.warningSurface),
                  ],
                ),
              ],
              const SizedBox(height: 3),
              Text(_paused ? TripStrings.stayPaused : (type ?? TripStringsA2.stay),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
              if (facts != null && !_paused) ...[
                const SizedBox(height: 2),
                Text(facts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
              ],
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: price == null
                    ? const Text(TripStringsA2.priceOnRequest,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMedium))
                    : Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: BrowseItem.inr(price),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.gold),
                          ),
                          TextSpan(
                            text: ' ${quote != null ? TripStringsAlgoAa.perNightGroup : TripStringsA2.perNightListed}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
                          ),
                        ]),
                        maxLines: 1,
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _actions() {
    if (_paused || readOnly) return null;
    final st = status;
    final Widget ask;
    if (st != null && onOpenChat != null) {
      ask = _pillButton(TripStrings.openChat, Iconsax.message, onOpenChat, filled: false);
    } else if (st != null) {
      ask = _pillButton(TripStringsV2Find.asked, Iconsax.tick_circle, null, filled: false);
    } else {
      ask = _pillButton(TripStringsV2Find.ask, Iconsax.send_2, onAsk, filled: true);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Iconsax.call, size: 16, color: StayColors.accentDark),
              label: const Text(TripStringsV2Find.call,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                side: BorderSide(color: StayColors.accent.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onWhatsApp,
              tooltip: TripStrings.whatsApp,
              style: IconButton.styleFrom(
                side: BorderSide(color: AppColors.whatsApp.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Image.asset('assets/images/whatsapp_icon.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, _, _) => const Icon(Icons.chat, size: 20, color: AppColors.whatsApp)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: ask),
        ],
      ),
    );
  }

  Widget _pillButton(String label, IconData icon, VoidCallback? onTap, {required bool filled}) {
    final fg = filled ? Colors.white : StayColors.accentDark;
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: onTap == null && !filled ? AppColors.textHint : fg),
        label: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: onTap == null && !filled ? AppColors.textHint : fg)),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 44),
          backgroundColor: filled ? StayColors.accent : StayColors.surface,
          disabledBackgroundColor: StayColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class TripStayRowSkeleton extends StatelessWidget {
  const TripStayRowSkeleton({super.key});

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    double line(double size) => scale.scale(size) * 1.5;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: TripStayRow.thumb,
                    height: TripStayRow.thumb,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(160, line(14)),
                        const SizedBox(height: 3),
                        _bar(130, line(12)),
                        const SizedBox(height: 2),
                        _bar(110, line(11)),
                        const SizedBox(height: 6),
                        _bar(120, line(13.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TripStayRow.actionHeight),
          ],
        ),
      ),
    );
  }
}
