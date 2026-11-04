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
import '../utils/trip_format.dart';
import 'trip_status.dart';

class TripStayRow extends StatelessWidget {
  const TripStayRow({
    super.key,
    required this.stay,
    required this.shortlisted,
    required this.onOpen,
    this.status,
    this.readOnly = false,
    this.onCall,
    this.onWhatsApp,
    this.onShortlist,
    this.onRemove,
  });

  final StayNearbyModel stay;
  final bool shortlisted;
  final TripDisplayStatus? status;
  final bool readOnly;
  final VoidCallback onOpen;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onShortlist;
  final VoidCallback? onRemove;

  static const double thumb = 56;
  static const double actionHeight = 46;

  static String? typeLine(StayNearbyModel s) {
    final guests = s.maxGuests;
    final parts = [
      if (s.stayTypeName != null && s.stayTypeName!.trim().isNotEmpty) s.stayTypeName!.trim(),
      if (guests != null && guests > 0) TripStringsA2.guests(guests),
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
    final highlight = shortlisted && !_paused;
    return Opacity(
      opacity: _paused ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ? StayColors.accent : AppColors.divider,
            width: highlight ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: StayColors.accent.withValues(alpha: highlight ? 0.12 : 0.05),
              blurRadius: highlight ? 18 : 8,
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
    final type = typeLine(stay);
    final facts = factsLine(stay);
    final price = stay.minPricePerNight;
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
                  const SizedBox(width: 8),
                  _pill(TripFormat.km(stay.distanceKm), StayColors.accentDark, StayColors.surface),
                ],
              ),
              if (_paused || st != null || stay.isFeatured) ...[
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
                          const TextSpan(
                            text: ' ${TripStringsA2.perNightListed}',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
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
    if (_paused) {
      if (!shortlisted || onRemove == null || readOnly) return null;
      return _strip([
        _ActionSpec(
          icon: Iconsax.close_circle,
          label: TripStrings.remove,
          color: AppColors.error,
          onTap: onRemove,
        ),
      ]);
    }
    final specs = <_ActionSpec>[
      _ActionSpec(icon: Iconsax.call, label: TripStrings.call, color: StayColors.accentDark, onTap: onCall),
      _ActionSpec(
        icon: Icons.chat,
        asset: 'assets/images/whatsapp_icon.png',
        label: TripStrings.whatsApp,
        color: AppColors.whatsApp,
        onTap: onWhatsApp,
      ),
    ];
    if (!readOnly) {
      if (status != null) {
        specs.add(const _ActionSpec(icon: Iconsax.tick_circle, label: TripStringsA2.asked, color: AppColors.textHint));
      } else if (shortlisted) {
        specs.add(_ActionSpec(
          icon: Iconsax.tick_circle,
          label: TripStrings.shortlisted,
          color: Colors.white,
          fill: StayColors.accent,
          onTap: onRemove,
        ));
      } else {
        specs.add(_ActionSpec(
          icon: Iconsax.add_circle,
          label: TripStrings.shortlist,
          color: StayColors.accentDark,
          onTap: onShortlist,
        ));
      }
    }
    if (specs.every((s) => s.onTap == null && s.fill == null) && readOnly) return null;
    return _strip(specs);
  }

  Widget _strip(List<_ActionSpec> specs) => DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        child: SizedBox(
          height: actionHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < specs.length; i++) ...[
                if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
                Expanded(child: _ActionButton(spec: specs[i])),
              ],
            ],
          ),
        ),
      );
}

class _ActionSpec {
  const _ActionSpec({required this.icon, required this.label, required this.color, this.onTap, this.fill, this.asset});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final Color? fill;
  final String? asset;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.spec});

  final _ActionSpec spec;

  @override
  Widget build(BuildContext context) {
    final enabled = spec.onTap != null;
    final color = enabled || spec.fill != null ? spec.color : AppColors.textHint;
    final Widget icon = spec.asset != null && enabled
        ? Image.asset(spec.asset!,
            width: 16, height: 16, errorBuilder: (_, _, _) => Icon(spec.icon, size: 16, color: color))
        : Icon(spec.icon, size: 16, color: color);
    return Semantics(
      button: true,
      enabled: enabled,
      label: spec.label,
      excludeSemantics: true,
      child: Material(
        color: spec.fill ?? Colors.transparent,
        child: InkWell(
          onTap: spec.onTap,
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Text(spec.label,
                          maxLines: 1,
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
            Container(height: 1, color: Colors.white),
            const SizedBox(height: TripStayRow.actionHeight),
          ],
        ),
      ),
    );
  }
}
