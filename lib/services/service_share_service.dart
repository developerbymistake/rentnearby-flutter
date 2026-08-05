import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_constants.dart';
import '../models/service_package_model.dart';
import '../utils/app_toast.dart';
import '../widgets/service_share_card.dart';

/// Captures a [ServiceShareCard] off-screen and hands it to the native share sheet together
/// with the plain-text website link — same mechanics as `shareListing()`
/// (`lib/services/listing_share_service.dart`), just pointed at a Service instead of a
/// Room/Plot listing.
///
/// [categorySlug]/[serviceSlug] back both the QR's `/go/s/` smart link and the shared
/// `bakhli.com/services/{categorySlug}/{serviceSlug}` website link (the latter already live —
/// see `Website/src/pages/services/[categorySlug]/[serviceSlug].astro`).
Future<void> shareService({
  required BuildContext context,
  required String categorySlug,
  required String serviceSlug,
  required String? photoUrl,
  required String title,
  required String ribbonText,
  required String? durationLabel,
  required String? pickupDropLocation,
  required String? priceUnit,
  required List<ServicePackageModel> tiers,
}) async {
  // Captured before any `await` below — using `context` after an async gap risks it having
  // been unmounted in between, and everything past this point only needs the Overlay itself.
  final overlay = Overlay.of(context, rootOverlay: true);
  final captureKey = GlobalKey();
  final goLink = '${AppConstants.serverUrl}/go/s/$categorySlug/$serviceSlug';
  final websiteLink = '${AppConstants.websiteUrl}/services/$categorySlug/$serviceSlug';

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
          child: ServiceShareCard(
            photo: photo,
            title: title,
            ribbonText: ribbonText,
            durationLabel: durationLabel,
            pickupDropLocation: pickupDropLocation,
            priceUnit: priceUnit,
            tiers: tiers,
            qrData: goLink,
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
    final image = await boundary.toImage(pixelRatio: 4.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'bakhli-service.png')],
        text: websiteLink,
      ),
    );
  } catch (e) {
    AppToast.error('Could not share this service: $e');
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
