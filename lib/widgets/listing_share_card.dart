import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_colors.dart';

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

  const ListingShareCard({
    super.key,
    required this.photo,
    required this.priceOrArea,
    required this.typeLabel,
    required this.locality,
    required this.qrData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: photo != null
                  ? RawImage(image: photo, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                      child: const Center(child: Icon(Icons.home_rounded, size: 56, color: Colors.white38)),
                    ),
            ),
          ),
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
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        priceOrArea,
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: QrImageView(data: qrData, size: 64, backgroundColor: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bakhli',
                            style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Scan to view on the app',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
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
