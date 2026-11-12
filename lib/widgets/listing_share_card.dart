import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../design/design.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Which listing type the card is branded for — drives gradient, ribbon text, and tagline.
enum ShareCardType { stay, taxi }

/// The image captured and shared by [shareListing] (`lib/services/listing_share_service.dart`)
/// — a per-listing equivalent of `rentnearby_Admin`'s `AppShareScreen._buildPosterCard`, but
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

  const ListingShareCard({
    super.key,
    required this.photo,
    required this.priceOrArea,
    required this.typeLabel,
    required this.locality,
    required this.qrData,
    this.type = ShareCardType.stay,
  });

  bool get _isTaxi => type == ShareCardType.taxi;
  LinearGradient get _gradient => _isTaxi ? TripEntryStyle.sunrise : TripEntryStyle.gradient;
  Color get _typeColor => _isTaxi ? TravelPalette.sunriseStart : FitnessAppTheme.nearlyDarkBlue;
  String get _tagline => _isTaxi ? 'Find local taxis near you.' : 'Find stays near you.';
  String get _ribbonText => _isTaxi ? 'TAXI' : 'FOR STAY';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: TripKit.cardRadius,
        boxShadow: GateKit.shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Branded header band — wordmark + type-specific tagline.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 31, 20, 52),
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: CardRadius.heroTop,
            ),
            child: Column(
              children: [
                Text(
                  'Bakhli',
                  style: FitnessAppTheme.headline.copyWith(fontSize: 27, fontWeight: FontWeight.w800, color: FitnessAppTheme.white),
                ),
                const SizedBox(height: 1.5),
                Text(
                  _tagline,
                  textAlign: TextAlign.center,
                  style: FitnessAppTheme.body2.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: FitnessAppTheme.white.withValues(alpha: Alpha.strong),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          // 2 + 3. Inset photo card, floating up into the header band, with a diagonal ribbon
          // clipped to the card's own rounded corner.
          Container(
            margin: const EdgeInsets.fromLTRB(20, -43, 20, 0),
            height: 220,
            decoration: BoxDecoration(
              color: FitnessAppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FitnessAppTheme.white, width: 4),
              boxShadow: GateKit.shadow,
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
                              child: TravelIcon(_isTaxi ? TravelIcon.taxi : TravelIcon.stay, size: 56),
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
                          style: FitnessAppTheme.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FitnessAppTheme.white,
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
                        style: FitnessAppTheme.headline.copyWith(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(38)),
                      child: Text(
                        priceOrArea,
                        style: FitnessAppTheme.body2.copyWith(
                          fontSize: 12, fontWeight: FontWeight.w700, color: FitnessAppTheme.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const TravelIcon(TravelIcon.place, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locality,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FitnessAppTheme.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: FitnessAppTheme.spacer),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: EdgeInsets.zero,
                        decoration: BoxDecoration(color: FitnessAppTheme.white, borderRadius: BorderRadius.circular(8), boxShadow: GateKit.shadow),
                        child: QrImageView(data: qrData, size: 121, backgroundColor: FitnessAppTheme.white, gapless: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Scan to view on',
                            textAlign: TextAlign.center,
                            style: FitnessAppTheme.body2.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: _typeColor),
                          ),
                          Text(
                            'Bakhli App',
                            textAlign: TextAlign.center,
                            style: FitnessAppTheme.body2.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: _typeColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'No broker · No commission',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.caption.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
