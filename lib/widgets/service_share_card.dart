import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_colors.dart';
import '../models/service_package_model.dart';

/// The image captured and shared by [shareService] (`lib/services/service_share_service.dart`)
/// — a Services-vertical equivalent of `ListingShareCard`, but a dedicated widget rather than a
/// third branch on it: the body shape here is fundamentally different (a multi-tier price list
/// instead of one price pill, no locality/furnished concepts, a dynamic ribbon across more than
/// two form types), so sharing `ListingShareCard`'s single `_isPlot` branch would scatter a
/// 3-way conditional through nearly every visual element instead of staying a straight-line
/// build method.
///
/// Uses `AppColors.primary`/`primaryGradient` — the same navy theme Room's own share card uses
/// — rather than a Services-specific tint, so this card reads as consistently "Bakhli" rather
/// than introducing a fourth brand color.
///
/// [photo] is decoded by the caller via `ui.instantiateImageCodec` before this widget is ever
/// built — see `ListingShareCard`'s doc comment for why (this widget is always captured
/// off-screen in one synchronous pass, so the photo can't decode asynchronously mid-build).
class ServiceShareCard extends StatelessWidget {
  final ui.Image? photo;
  final String title;
  final String ribbonText;
  final String? durationLabel;
  final String? pickupDropLocation;
  final String? priceUnit;
  final List<ServicePackageModel> tiers;
  final String qrData;

  const ServiceShareCard({
    super.key,
    required this.photo,
    required this.title,
    required this.ribbonText,
    required this.durationLabel,
    required this.pickupDropLocation,
    required this.priceUnit,
    required this.tiers,
    required this.qrData,
  });

  // "Starting from {pickup}" spells out that pricing starts from that departure point,
  // rather than the terser "Ex-{pickup}" — which reads as an unfamiliar abbreviation
  // rather than a clear "trip starts from here, price shown is per unit" signal.
  String? get _metaText {
    final pickup = pickupDropLocation != null && pickupDropLocation!.trim().isNotEmpty ? pickupDropLocation!.trim() : null;
    final unit = priceUnit != null && priceUnit!.trim().isNotEmpty ? priceUnit!.trim() : null;
    if (pickup != null && unit != null) return 'Starting from $pickup · $unit';
    if (pickup != null) return 'Starting from $pickup';
    if (unit != null) return unit;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaText;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Branded header band — wordmark + fixed tagline (one line).
          Container(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 44),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Column(
              children: [
                Text(
                  'Bakhli',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 23, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'No middleman, same trip. Better price.',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // 2 + 3. Inset photo card, floating up into the header band, with a diagonal ribbon
          // clipped to the card's own rounded corner.
          Container(
            margin: const EdgeInsets.fromLTRB(20, -36, 20, 0),
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: photo != null
                        ? RawImage(image: photo, fit: BoxFit.cover)
                        : Container(
                            decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                            child: const Center(
                              child: Icon(Icons.map_rounded, size: 44, color: Colors.white38),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 16,
                    left: -52,
                    child: Transform.rotate(
                      angle: -math.pi / 4,
                      child: Container(
                        width: 170,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                        child: Text(
                          ribbonText,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 4, 5, 6. Details row, tier list, divider, colored-ring QR footer.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (durationLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          durationLabel!,
                          style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (meta != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Column(
                  children: [
                    for (var i = 0; i < tiers.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _TierRow(package: tiers[i], isCheapest: i == 0),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                      child: Container(
                        padding: EdgeInsets.zero,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: QrImageView(data: qrData, size: 110, backgroundColor: Colors.white, gapless: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMedium, height: 1.4),
                              children: [
                                TextSpan(text: 'Connect directly with '),
                                TextSpan(text: 'local experts', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                                TextSpan(text: ' and save upto '),
                                TextSpan(text: '20-30%', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                                TextSpan(text: ' on every booking.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Scan for more details on Bakhli App',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One package/group-size tier row — name + price, the cheapest one (first by SortOrder)
/// visually distinguished with a colored dot + colored price. Every tier renders; this card
/// deliberately never collapses to a single "starting at" price (group size changes it a lot).
class _TierRow extends StatelessWidget {
  final ServicePackageModel package;
  final bool isCheapest;

  const _TierRow({required this.package, required this.isCheapest});

  @override
  Widget build(BuildContext context) {
    final priceColor = isCheapest ? AppColors.primary : AppColors.textDark;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCheapest ? AppColors.primary : AppColors.textLight.withValues(alpha: 0.4),
          ),
        ),
        Expanded(
          child: Text(
            package.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          package.price == null ? 'Get Custom Quote' : '₹${package.price}',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: priceColor),
        ),
      ],
    );
  }
}
