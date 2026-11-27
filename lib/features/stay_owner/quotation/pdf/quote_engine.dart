import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/quote_models.dart';
import '../model/quote_doc.dart';
import '../model/quote_file_name.dart';

enum QuoteEngineFailure { tooLong, renderFailed, storageDenied, noSpace, unsupported, busy }

class QuoteEngineException implements Exception {
  const QuoteEngineException(this.failure, [this.detail]);

  final QuoteEngineFailure failure;
  final String? detail;

  static QuoteEngineFailure parse(String? code) => switch (code) {
        'TooLong' => QuoteEngineFailure.tooLong,
        'StorageDenied' => QuoteEngineFailure.storageDenied,
        'NoSpace' => QuoteEngineFailure.noSpace,
        'Unsupported' => QuoteEngineFailure.unsupported,
        'Busy' => QuoteEngineFailure.busy,
        _ => QuoteEngineFailure.renderFailed,
      };

  @override
  String toString() => 'QuoteEngineException(${failure.name})';
}

class QuoteLayout {
  const QuoteLayout({required this.ok, required this.pages, required this.fit, this.reason});

  final bool ok;
  final int pages;
  final int fit;
  final String? reason;

  bool get tooLong => !ok && reason == 'TooLong';

  factory QuoteLayout.fromMap(Map<Object?, Object?> m) => QuoteLayout(
        ok: m['ok'] == true,
        pages: (m['pages'] as num?)?.toInt() ?? 0,
        fit: (m['fit'] as num?)?.toInt() ?? 0,
        reason: m['reason'] as String?,
      );
}

class QuotePreviewPage {
  const QuotePreviewPage({required this.width, required this.height, required this.rgba});

  final int width;
  final int height;
  final Uint8List rgba;
}

class QuotePreview {
  const QuotePreview({required this.pages, required this.fit});

  final List<QuotePreviewPage> pages;
  final int fit;
}

class QuoteFile {
  const QuoteFile({required this.uri, required this.displayName, required this.pages, required this.engine, required this.bytes});

  final String uri;
  final String displayName;
  final int pages;
  final String engine;
  final int bytes;
}

enum QuoteOpenResult { opened, missing, noApp }

abstract class QuoteEngineApi {
  Future<String> storageDir();
  Future<void> putImage({required String userId, required QuoteImageKind kind, required int version, required Uint8List bytes});
  Future<void> clearUser(String userId);
  Future<void> warmUp(String template);
  Future<QuoteLayout> layout(String template, QuoteDoc doc);
  Future<QuotePreview> preview(String template, QuoteDoc doc, {required int widthPx, required bool watermark});
  Future<QuoteFile> render(String template, QuoteDoc doc, {required String fileName});
  Future<QuoteOpenResult> open(String uri);
  Future<void> delete(String uri);
  Future<void> dispose();
}

class QuoteEngine implements QuoteEngineApi {
  QuoteEngine({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'bakhli/quote_pdf';
  static const int maxJsonBytes = 256 * 1024;
  static const int maxImageBytes = 200 * 1024;

  static QuoteEngineApi instance = QuoteEngine();

  final MethodChannel _channel;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
      throw const QuoteEngineException(QuoteEngineFailure.unsupported);
    }
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw QuoteEngineException(QuoteEngineException.parse(e.code), e.message);
    } on MissingPluginException {
      throw const QuoteEngineException(QuoteEngineFailure.unsupported);
    }
  }

  static String encode(QuoteDoc doc) {
    final json = jsonEncode(doc.toJson());
    if (utf8.encode(json).length > maxJsonBytes) throw const QuoteEngineException(QuoteEngineFailure.tooLong);
    return json;
  }

  static bool isJpeg(Uint8List b) => b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  @override
  Future<String> storageDir() async {
    final m = await _call<Map<Object?, Object?>>('storageDir');
    return (m?['path'] as String?) ?? '';
  }

  @override
  Future<void> putImage({required String userId, required QuoteImageKind kind, required int version, required Uint8List bytes}) async {
    if (!isJpeg(bytes) || bytes.length > maxImageBytes) throw const QuoteEngineException(QuoteEngineFailure.renderFailed, 'image');
    await _call<void>('putImage', {'userId': userId, 'kind': kind.wire, 'version': version, 'bytes': bytes});
  }

  @override
  Future<void> clearUser(String userId) => _call<void>('clearUser', {'userId': userId});

  @override
  Future<void> warmUp(String template) => _call<void>('warmUp', {'template': template});

  @override
  Future<QuoteLayout> layout(String template, QuoteDoc doc) async {
    final m = await _call<Map<Object?, Object?>>('layout', {'template': template, 'json': encode(doc)});
    return QuoteLayout.fromMap(m ?? const {});
  }

  @override
  Future<QuotePreview> preview(String template, QuoteDoc doc, {required int widthPx, required bool watermark}) async {
    final m = await _call<Map<Object?, Object?>>('preview', {'template': template, 'json': encode(doc), 'widthPx': widthPx, 'watermark': watermark});
    final raw = (m?['pages'] as List?) ?? const [];
    return QuotePreview(
      fit: (m?['fit'] as num?)?.toInt() ?? 0,
      pages: [
        for (final p in raw.whereType<Map<Object?, Object?>>())
          QuotePreviewPage(width: (p['width'] as num).toInt(), height: (p['height'] as num).toInt(), rgba: p['rgba'] as Uint8List),
      ],
    );
  }

  @override
  Future<QuoteFile> render(String template, QuoteDoc doc, {required String fileName}) async {
    final safe = fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
    final m = await _call<Map<Object?, Object?>>('render', {'template': template, 'json': encode(doc), 'fileName': safe});
    if (m == null) throw const QuoteEngineException(QuoteEngineFailure.renderFailed);
    return QuoteFile(
      uri: m['uri'] as String? ?? '',
      displayName: m['displayName'] as String? ?? safe,
      pages: (m['pages'] as num?)?.toInt() ?? 0,
      engine: m['engine'] as String? ?? '',
      bytes: (m['bytes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<QuoteOpenResult> open(String uri) async {
    final m = await _call<Map<Object?, Object?>>('open', {'uri': uri});
    if (m?['missing'] == true) return QuoteOpenResult.missing;
    if (m?['noApp'] == true) return QuoteOpenResult.noApp;
    return QuoteOpenResult.opened;
  }

  @override
  Future<void> delete(String uri) async {
    try {
      await _call<void>('delete', {'uri': uri});
    } on QuoteEngineException {
      return;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _call<void>('dispose');
    } on QuoteEngineException {
      return;
    }
  }

  static String fileNameFor(String display, String guest) => QuoteFileName.of(display, guest);
}
