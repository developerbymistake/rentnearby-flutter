import 'dart:async';
import 'dart:ui' as ui;

import 'quote_engine.dart';

// Raw RGBA from the channel straight into a ui.Image (no PNG encode / decode).
abstract final class QuotePageImage {
  static Future<ui.Image> decode(QuotePreviewPage p) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(p.rgba, p.width, p.height, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  static Future<List<ui.Image>> decodeAll(QuotePreview preview) async => [for (final p in preview.pages) await decode(p)];

  static void disposeAll(Iterable<ui.Image> images) {
    for (final i in images) {
      i.dispose();
    }
  }
}
