import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_constants.dart';
import '../utils/app_toast.dart';
import '../widgets/listing_share_card.dart';

/// Captures a [ListingShareCard] off-screen and hands it to the native share sheet together
/// with the plain-text website link, mirroring `rentnearby_Admin`'s `AppShareScreen._share`
/// (RepaintBoundary + `toImage(pixelRatio: 3.0)`) but parameterized per listing and bundling
/// both channels (image + text) in one native share call — see the plan's "two channels
/// bundled together whenever Share is tapped" decision.
///
/// [type] is the short URL code ('r' for Room, 'p' for Plot) used by both the QR's `/go/`
/// smart link and the shared `/l/` website link.
Future<void> shareListing({
  required BuildContext context,
  required String type,
  required String slug,
  required String? photoUrl,
  required String priceOrArea,
  required String typeLabel,
  required String locality,
  String? furnishedStatus,
}) async {
  // Captured before any `await` below — using `context` after an async gap risks it having
  // been unmounted in between, and everything past this point only needs the Overlay itself.
  final overlay = Overlay.of(context, rootOverlay: true);
  final captureKey = GlobalKey();
  final goLink = '${AppConstants.serverUrl}/go/$type/$slug';
  final websiteLink = '${AppConstants.websiteUrl}/l/$type/$slug';

  final photo = await _fetchAndDecodePhoto(photoUrl);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -9999,
      top: -9999,
      child: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: captureKey,
          child: ListingShareCard(
            photo: photo,
            priceOrArea: priceOrArea,
            typeLabel: typeLabel,
            locality: locality,
            qrData: goLink,
            type: type == 'p' ? ShareCardType.plot : ShareCardType.room,
            furnishedStatus: furnishedStatus,
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);

  try {
    // Two frames: one to lay out + paint the freshly-inserted card, one more as a safety
    // margin for the QR CustomPainter/text layout to fully settle before capture.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      AppToast.error('Could not prepare the share image.');
      return;
    }
    // 4.0 rather than 3.0 — sharper across the whole card (text, QR) on the denser
    // (3.5x-4x) screens common now; 3.0 was soft enough to notice at 100% zoom on those.
    final image = await boundary.toImage(pixelRatio: 4.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'bakhli-listing.png')],
        text: websiteLink,
      ),
    );
  } catch (e) {
    AppToast.error('Could not share this listing: $e');
  } finally {
    entry.remove();
  }
}

Future<ui.Image?> _fetchAndDecodePhoto(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final res = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    final data = res.data;
    if (data == null) return null;
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}
