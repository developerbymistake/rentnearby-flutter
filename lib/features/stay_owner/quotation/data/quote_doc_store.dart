import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get_storage/get_storage.dart';

import '../model/quote_draft.dart';
import '../pdf/quote_engine.dart';
import 'quote_models.dart';
import '../model/quote_money.dart';

class QuoteIndexRow {
  const QuoteIndexRow({
    required this.id,
    required this.kind,
    required this.guest,
    required this.date,
    required this.updatedAt,
    this.number,
    this.checkIn,
    this.checkOut,
    this.total = 0,
    this.fileUri,
    this.savedAt,
  });

  final String id;
  final String kind;
  final String guest;
  final DateTime date;
  final DateTime updatedAt;
  final String? number;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int total;
  final String? fileUri;
  final DateTime? savedAt;

  bool get downloaded => fileUri != null;

  static String? _d(DateTime? d) => d?.toIso8601String();
  static DateTime? _p(Object? v) => v is String ? DateTime.tryParse(v) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'guest': guest,
        'date': _d(date),
        'updatedAt': _d(updatedAt),
        'number': number,
        'checkIn': _d(checkIn),
        'checkOut': _d(checkOut),
        'total': total,
        'fileUri': fileUri,
        'savedAt': _d(savedAt),
      };

  static QuoteIndexRow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final updated = _p(raw['updatedAt']) ?? DateTime(2000);
    return QuoteIndexRow(
      id: id,
      kind: raw['kind'] is String ? raw['kind'] as String : 'quotation',
      guest: raw['guest'] is String ? raw['guest'] as String : '',
      date: _p(raw['date']) ?? updated,
      updatedAt: updated,
      number: raw['number'] as String?,
      checkIn: _p(raw['checkIn']),
      checkOut: _p(raw['checkOut']),
      total: raw['total'] is num ? (raw['total'] as num).toInt() : 0,
      fileUri: raw['fileUri'] as String?,
      savedAt: _p(raw['savedAt']),
    );
  }

  factory QuoteIndexRow.of(QuoteDraft d, int total) {
    final file = d.lastFile;
    return QuoteIndexRow(
      id: d.documentId,
      kind: (file != null ? (d.reservations.entries.firstWhere((e) => identical(e.value, file)).key) : d.kind.name),
      guest: d.guestName,
      date: d.date,
      updatedAt: d.updatedAt,
      number: file?.display ?? d.reservation?.display,
      checkIn: d.checkIn,
      checkOut: d.checkOut,
      total: total,
      fileUri: file?.fileUri,
      savedAt: file?.savedAt,
    );
  }
}

abstract class QuoteIndexBox {
  List<Object?> read();
  Future<void> write(List<Map<String, dynamic>> rows);
  String? readTemplate();
  Future<void> writeTemplate(String id);
  Future<void> erase();
}

class MemoryIndexBox implements QuoteIndexBox {
  List<Map<String, dynamic>> rows = [];
  String? template;

  @override
  List<Object?> read() => rows;
  @override
  Future<void> write(List<Map<String, dynamic>> value) async => rows = value;
  @override
  String? readTemplate() => template;
  @override
  Future<void> writeTemplate(String id) async => template = id;
  @override
  Future<void> erase() async {
    rows = [];
    template = null;
  }
}

class GetStorageIndexBox implements QuoteIndexBox {
  GetStorageIndexBox(this.name);

  final String name;
  static const String _key = 'rows';
  static const String _template = 'template';

  static String boxName(String userId) => QuoteStorageNames.indexBox(userId);

  static Future<GetStorageIndexBox> open(String userId) async {
    final name = boxName(userId);
    await GetStorage.init(name);
    return GetStorageIndexBox(name);
  }

  @override
  List<Object?> read() {
    final v = GetStorage(name).read<Object?>(_key);
    return v is List ? v : const [];
  }

  @override
  Future<void> write(List<Map<String, dynamic>> rows) => GetStorage(name).write(_key, rows);

  @override
  String? readTemplate() => GetStorage(name).read<String>(_template);

  @override
  Future<void> writeTemplate(String id) => GetStorage(name).write(_template, id);

  @override
  Future<void> erase() => GetStorage(name).erase();
}

abstract class QuoteDocFiles {
  Future<String?> read(String id);
  Future<void> write(String id, String json);
  Future<void> delete(String id);
}

class IoQuoteDocFiles implements QuoteDocFiles {
  IoQuoteDocFiles(this.folder);

  // filesDir/quote/<userId>/docs
  final String folder;

  File _file(String id) => File('$folder/$id.json');

  static bool _safeId(String id) => RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(id);

  @override
  Future<String?> read(String id) async {
    if (!_safeId(id)) return null;
    final f = _file(id);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<void> write(String id, String json) async {
    if (!_safeId(id)) return;
    await Directory(folder).create(recursive: true);
    final tmp = File('$folder/$id.json.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_file(id).path);
  }

  @override
  Future<void> delete(String id) async {
    if (!_safeId(id)) return;
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }
}

class MemoryDocFiles implements QuoteDocFiles {
  final Map<String, String> files = {};
  int writes = 0;

  @override
  Future<String?> read(String id) async => files[id];
  @override
  Future<void> write(String id, String json) async {
    writes++;
    files[id] = json;
  }

  @override
  Future<void> delete(String id) async => files.remove(id);
}

typedef QuoteTimerFactory = Timer Function(Duration d, void Function() cb);

// One small file per document plus a light index; the list reads only the index.
class QuoteDocStore {
  QuoteDocStore({required this.files, required this.index, DateTime Function()? now, QuoteTimerFactory? timer})
      : _now = now ?? DateTime.now,
        _timer = timer ?? Timer.new;

  static const Duration debounce = Duration(milliseconds: 1500);

  final QuoteDocFiles files;
  final QuoteIndexBox index;
  final DateTime Function() _now;
  final QuoteTimerFactory _timer;

  Timer? _pending;
  QuoteDraft? _queued;
  int _queuedTotal = 0;

  List<QuoteIndexRow> rows() {
    final out = <QuoteIndexRow>[];
    for (final r in index.read()) {
      final row = QuoteIndexRow.fromJson(r);
      if (row != null) out.add(row);
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<QuoteDraft?> load(String id) async {
    try {
      final raw = await files.read(id);
      if (raw == null) return null;
      final j = jsonDecode(raw);
      return j is Map<String, dynamic> ? QuoteDraft.fromJson(j) : null;
    } catch (_) {
      return null;
    }
  }

  static int totalOf(QuoteDraft d, {required bool gstAllowed}) => QuoteMoney.compute(
        lineAmounts: d.lines.map((l) => l.amount),
        discount: d.discount,
        gstBp: d.gstBp,
        gstAllowed: gstAllowed,
      ).total;

  Future<void> saveNow(QuoteDraft d, {int total = 0}) async {
    _pending?.cancel();
    _pending = null;
    _queued = null;
    await files.write(d.documentId, jsonEncode(d.toJson()));
    final list = rows().where((r) => r.id != d.documentId).toList();
    list.insert(0, QuoteIndexRow.of(d, total));
    await index.write([for (final r in list) r.toJson()]);
  }

  void saveLater(QuoteDraft d, {int total = 0}) {
    _queued = d;
    _queuedTotal = total;
    _pending?.cancel();
    _pending = _timer(debounce, () {
      final q = _queued;
      if (q != null) saveNow(q, total: _queuedTotal).ignore();
    });
  }

  Future<void> flush() async {
    final q = _queued;
    if (q != null) await saveNow(q, total: _queuedTotal);
  }

  bool get hasPending => _queued != null;

  // 50 documents, nothing older than 90 days (by last change).
  Future<void> prune() async {
    final all = rows();
    final cutoff = _now().subtract(const Duration(days: QuoteLimits.keepDays));
    final keep = <QuoteIndexRow>[];
    final drop = <QuoteIndexRow>[];
    for (final r in all) {
      if (r.updatedAt.isBefore(cutoff) || keep.length >= QuoteLimits.keepDocs) {
        drop.add(r);
      } else {
        keep.add(r);
      }
    }
    if (drop.isEmpty) return;
    for (final r in drop) {
      await files.delete(r.id);
    }
    await index.write([for (final r in keep) r.toJson()]);
  }

  static Future<QuoteDocStore> openFor(String userId, QuoteEngineApi engine) async {
    final root = await engine.storageDir();
    final index = await GetStorageIndexBox.open(userId);
    return QuoteDocStore(files: IoQuoteDocFiles('$root/$userId/docs'), index: index);
  }

  void cancel() {
    _pending?.cancel();
    _pending = null;
  }
}
