import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_colors.dart';

/// Which listing type the card is branded for — drives gradient, ribbon text, and tagline.
enum ShareCardType { room, plot }

/// The image captured and shared by [shareListing] (`lib/services/listing_share_service.dart`)
/// — a Room/Plot equivalent of `rentnearby_Admin`'s `AppShareScreen._buildPosterCard`, but
/// parameterized by real listing data instead of static app-download copy, and carrying a
/// per-listing QR (the `/go/{type}/{slug}` smart link) instead of the one fixed `/app` link.
///
/// [photo] is decoded by the caller via `ui.instantiateImageCodec` before this widget is ever
/// built (not loaded here via a network `Image`/`Image.memory` widget) — this widget is always
/// rendered off-screen for a single synchronous capture, so the photo must already be a fully
/// decoded `dart:ui.Image` by the time it first paints; anything that decodes asynchronously
/// inside the widget tree (a network fetch, or even `Image.memory`'s own internal decode) would
/// race the capture instead of being guaranteed ready for it.
class ListingShareCard extends StatelessWidget {
  final ui.Image? photo;
  final String priceOrArea;
  final String typeLabel;
  final String locality;
  final String qrData;
  final ShareCardType type;
  final String? furnishedStatus;

  const ListingShareCard({
    super.key,
    required this.photo,
    required this.priceOrArea,
    required this.typeLabel,
    required this.locality,
    required this.qrData,
    this.type = ShareCardType.room,
    this.furnishedStatus,
  });

  bool get _isPlot => type == ShareCardType.plot;
  LinearGradient get _gradient => _isPlot ? AppColors.plotGradient : AppColors.primaryGradient;
  Color get _typeColor => _isPlot ? AppColors.plot : AppColors.primary;
  String get _tagline => _isPlot ? 'Find plots for sale near you.' : 'Find rooms for rent near you.';
  String get _ribbonText => _isPlot ? 'FOR SALE' : 'FOR RENT';

  @override
  Widget build(BuildContext context) {
    final showFurnished = !_isPlot && furnishedStatus != null && furnishedStatus != 'None';

    return Container(
      width: 320,
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
          // 1. Branded header band — wordmark + type-specific tagline.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 50),
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const Text(
                  'Bakhli',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  _tagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          // 2 + 3. Inset photo card, floating up into the header band, with a diagonal ribbon
          // clipped to the card's own rounded corner.
          Container(
            margin: const EdgeInsets.fromLTRB(20, -36, 20, 0),
            height: 180,
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
                            decoration: BoxDecoration(gradient: _gradient),
                            child: Center(
                              child: Icon(
                                _isPlot ? Icons.landscape_rounded : Icons.home_rounded,
                                size: 48,
                                color: Colors.white38,
                              ),
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
                        decoration: BoxDecoration(gradient: _gradient),
                        child: Text(
                          _ribbonText,
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
          // 4, 5, 6. Details row, divider, colored-ring QR footer.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        priceOrArea,
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locality,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                    ),
                    if (showFurnished) ...[
                      const SizedBox(width: 8),
                      const _FurnishedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(17)),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(data: qrData, size: 101, backgroundColor: Colors.white, gapless: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Scan to view on',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _typeColor),
                          ),
                          Text(
                            'Bakhli App',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _typeColor),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'No broker · No commission',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight),
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

/// Room-only "Furnished" badge — a standalone element (own background pill, own layout slot)
/// pinned to the far right of the locality row, never string-concatenated into the locality
/// text, so a long address truncates independently instead of pushing this off-card. Color
/// matches the real furnished-pill purple already used on `listing_detail_screen.dart`.
class _FurnishedBadge extends StatelessWidget {
  const _FurnishedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Furnished',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
      ),
    );
  }
}
