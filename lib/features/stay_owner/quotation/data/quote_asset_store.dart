import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

import '../../../owner_core/data/owner_result.dart';
import '../../../owner_core/json/owner_json.dart';
import '../pdf/quote_engine.dart';
import 'quote_api.dart';
import 'quote_models.dart';

// Small seam over the two local stores so tests run without plugins.
abstract class QuoteKeyValue {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class QuoteSecureStore implements QuoteKeyValue {
  const QuoteSecureStore();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract class QuoteBoxes {
  Future<Map<String, dynamic>?> readJson(String box, String key);
  Future<void> writeJson(String box, String key, Map<String, dynamic> value);
  Future<void> erase(String box);
}

class QuoteGetStorageBoxes implements QuoteBoxes {
  const QuoteGetStorageBoxes();

  static Future<GetStorage> _open(String box) async {
    await GetStorage.init(box);
    return GetStorage(box);
  }

  @override
  Future<Map<String, dynamic>?> readJson(String box, String key) async {
    final raw = (await _open(box)).read<String>(key);
    if (raw == null) return null;
    try {
      return OwnerJson.mapOrNull(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeJson(String box, String key, Map<String, dynamic> value) async => (await _open(box)).write(key, jsonEncode(value));

  @override
  Future<void> erase(String box) async => (await _open(box)).erase();
}

typedef QuoteCachedHub = ({QuoteHub hub, String? etag, DateTime savedAt});

class QuoteAssetStore {
  QuoteAssetStore({QuoteEngineApi? engine, this.api = const QuoteApi(), this.secure = const QuoteSecureStore(), this.boxes = const QuoteGetStorageBoxes(), DateTime Function()? clock})
      : _engine = engine,
        _clock = clock ?? DateTime.now;

  final QuoteApi api;
  final QuoteKeyValue secure;
  final QuoteBoxes boxes;
  final DateTime Function() _clock;
  QuoteEngineApi? _engine;

  static const _hubKey = 'hub';
  static const int maxImageBytes = 200 * 1024;

  QuoteEngineApi get engine => _engine ?? QuoteEngine.instance;

  // Hub cache: no bank value at all (QuoteHub.toCacheJson).
  Future<QuoteCachedHub?> readHub(String userId) async {
    final j = await boxes.readJson(QuoteStorageNames.cacheBox(userId), _hubKey);
    final hub = OwnerJson.mapOrNull(j?['hub']);
    final savedAt = OwnerJson.time(j?['savedAt']);
    if (hub == null || savedAt == null) return null;
    return (hub: QuoteHub.fromJson(hub), etag: OwnerJson.strOrNull(j?['etag']), savedAt: savedAt);
  }

  Future<void> writeHub(String userId, QuoteHub hub, {String? etag}) => boxes.writeJson(
        QuoteStorageNames.cacheBox(userId),
        _hubKey,
        {'hub': hub.toCacheJson(), 'etag': etag, 'savedAt': _clock().toUtc().toIso8601String()},
      );

  // Full bank block: only in secure storage, stamped with the profile updatedAt it belongs to.
  Future<QuoteBank?> readBank(String userId, {DateTime? stamp}) async {
    final raw = await secure.read(QuoteStorageNames.bankKey(userId));
    if (raw == null) return null;
    try {
      final j = OwnerJson.map(jsonDecode(raw));
      final saved = OwnerJson.time(j['stamp']);
      if (stamp != null && (saved == null || !saved.isAtSameMomentAs(stamp))) return null;
      return QuoteBank.fromJson(OwnerJson.map(j['bank']));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBank(String userId, QuoteBank? bank, {DateTime? stamp}) async {
    final key = QuoteStorageNames.bankKey(userId);
    if (bank == null || bank.isEmpty) {
      await secure.delete(key);
      return;
    }
    await secure.write(key, jsonEncode({'stamp': stamp?.toUtc().toIso8601String(), 'bank': bank.toJson()}));
  }

  // The secure copy when it matches the profile, else GET /profile/bank (and the copy is refreshed).
  Future<OwnerResult<QuoteBank?>> bank(String userId, {DateTime? stamp, bool fetch = true}) async {
    final local = await readBank(userId, stamp: stamp);
    if (local != null || !fetch) return OwnerOk<QuoteBank?>(local);
    final r = await api.bank();
    if (r is OwnerOk<QuoteBank?>) await writeBank(userId, r.value, stamp: stamp);
    return r;
  }

  Future<String?> imagePath(String userId, QuoteImageKind kind, int version) async {
    try {
      final root = await engine.storageDir();
      final f = File('$root/$userId/${QuoteStorageNames.imageFile(kind, version)}');
      return await f.exists() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  static bool isJpeg(Uint8List b) => b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  // Only server-stripped bytes reach the phone store (the local crop still carries EXIF). True = file on the phone.
  Future<bool> fetchImage(String userId, QuoteImageKind kind, int version) async {
    final r = await api.image(kind);
    if (r is! OwnerOk<Uint8List>) return false;
    final bytes = r.value;
    if (!isJpeg(bytes) || bytes.length > maxImageBytes) return false;
    try {
      await engine.putImage(userId: userId, kind: kind, version: version, bytes: bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureImages(String userId, QuoteProfile? profile, {int? assetsVersion}) async {
    if (profile == null) return;
    final version = assetsVersion ?? profile.assetsVersion;
    for (final kind in QuoteImageKind.values) {
      if (!profile.hasImage(kind)) continue;
      if (await imagePath(userId, kind, version) != null) continue;
      await fetchImage(userId, kind, version);
    }
  }
}
