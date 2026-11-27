import 'dart:async';
import 'dart:typed_data';

import 'package:bakhli/features/stay_owner/quotation/data/quote_doc_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_business.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_doc.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_source.dart';
import 'package:bakhli/features/stay_owner/quotation/pdf/quote_engine.dart';
import 'package:flutter/widgets.dart';

QuoteBusiness sampleBusiness({String gstin = '05ABCDE1234F1Z5', QuoteUsage? usage}) => QuoteBusiness(
      name: 'The Banyan Retreat',
      slogan: 'Riverside stays on the edge of the forest',
      address: 'Village Dhikuli, Ramnagar\nNainital, Uttarakhand 244715',
      phone: '+91 98370 41122',
      email: 'stay@banyanretreat.in',
      gstin: gstin,
      preparedBy: 'Meena Bisht',
      termsText: 'Check-in from 12:00 pm.\nRates are per night.',
      cancellationText: '15 days or more: full refund.',
      assetsVersion: 3,
      hasLogo: true,
      bank: const QuoteBankLines(holder: 'The Banyan Retreat', accountNo: '30987654521', ifsc: 'SBIN0001234', bank: 'State Bank of India', branch: 'Ramnagar', upi: 'banyan@sbi'),
      nextQuotation: 42,
      nextProforma: 7,
      usage: usage,
    );

QuoteDraft sampleDraft({QuoteKind kind = QuoteKind.quotation}) {
  final d = QuoteDraft.blank(documentId: 'doc-00000001', today: DateTime(2026, 11, 12, 10));
  return d.copyWith(
    kind: kind,
    guestName: 'Harshit & Mansi',
    guestPhone: '+91 99100 23456',
    bookedBy: 'Rahul (agent)',
    checkIn: DateTime(2026, 11, 23),
    checkOut: DateTime(2026, 11, 25),
    adults: 12,
    kids: 2,
    rooms: 5,
    meal: QuoteMeal.ap,
    lines: const [
      QuoteLine(id: 'l1', description: '5 rooms, double occupancy', rate: 10000, qty: 5, nights: 2),
      QuoteLine(id: 'l2', description: 'Extra person', rate: 3500, qty: 4, nights: 2),
      QuoteLine(id: 'l3', description: 'Extra breakfast', rate: 885, qty: 6, nights: 1),
      QuoteLine(id: 'l4', description: 'Bonfire package', rate: 6000, qty: 1, nights: 1),
    ],
    discount: 5000,
    gstBp: 500,
  );
}

class ManualTimer implements Timer {
  ManualTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled || fired) return;
    fired = true;
    callback();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

class TimerLog {
  final timers = <ManualTimer>[];

  Timer call(Duration d, void Function() cb) {
    final t = ManualTimer(d, cb);
    timers.add(t);
    return t;
  }
}

QuoteDocStore memoryStore({TimerLog? timers, DateTime Function()? now}) =>
    QuoteDocStore(files: MemoryDocFiles(), index: MemoryIndexBox(), timer: timers?.call, now: now);

class FakeEngine implements QuoteEngineApi {
  final calls = <String>[];
  QuoteLayout layoutResult = const QuoteLayout(ok: true, pages: 1, fit: 0);
  final renderFailures = <QuoteEngineFailure>[];
  QuoteDoc? lastRendered;
  String? lastFileName;
  final deleted = <String>[];
  int _n = 0;

  @override
  Future<String> storageDir() async => '/tmp/quote';

  @override
  Future<void> putImage({required String userId, required QuoteImageKind kind, required int version, required Uint8List bytes}) async => calls.add('putImage');

  @override
  Future<void> clearUser(String userId) async => calls.add('clearUser');

  @override
  Future<void> warmUp(String template) async => calls.add('warmUp');

  @override
  Future<QuoteLayout> layout(String template, QuoteDoc doc) async {
    calls.add('layout');
    return layoutResult;
  }

  @override
  Future<QuotePreview> preview(String template, QuoteDoc doc, {required int widthPx, required bool watermark}) async {
    calls.add('preview:$watermark');
    return const QuotePreview(pages: [], fit: 0);
  }

  @override
  Future<QuoteFile> render(String template, QuoteDoc doc, {required String fileName}) async {
    calls.add('render');
    if (renderFailures.isNotEmpty) throw QuoteEngineException(renderFailures.removeAt(0));
    lastRendered = doc;
    lastFileName = fileName;
    _n++;
    return QuoteFile(uri: 'content://media/external/downloads/$_n', displayName: fileName, pages: 1, engine: 'print', bytes: 120000);
  }

  @override
  Future<QuoteOpenResult> open(String uri) async => QuoteOpenResult.opened;

  @override
  Future<void> delete(String uri) async => deleted.add(uri);

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class FakeSource implements QuoteSource {
  FakeSource({this.business0, this.usage0});

  QuoteBusiness? business0;
  QuoteUsage? usage0;
  final reserves = <(String, QuoteKind)>[];
  final List<QuoteReserveOutcome> outcomes = [];
  final log = <String>[];

  static QuoteReserveResult ok({int number = 42, QuoteKind kind = QuoteKind.quotation, bool counted = true, int used = 1, int limit = 2, int assets = 3, DateTime? at}) {
    final now = at ?? DateTime.utc(2026, 11, 27, 9);
    return QuoteReserveResult(
      number: number,
      display: kind.display(number),
      kind: kind,
      counted: counted,
      freeUntil: now.add(const Duration(hours: 24)),
      freeLeft: 5,
      issuedAt: now,
      usage: QuoteUsage(used: used, limit: limit, resetsAt: DateTime.utc(2026, 11, 30, 18, 30), canUpgrade: true),
      businessName: 'The Banyan Retreat',
      assetsVersion: assets,
    );
  }

  @override
  String? get userId => 'user-1';

  @override
  String get businessName => business0?.name ?? '';

  @override
  QuoteBusiness? business({QuoteBank? bank}) => business0;

  @override
  QuoteUsage? get usage => usage0;

  @override
  bool get offline => false;

  @override
  Future<bool> ensureReady(BuildContext context, {int? appTemplateVersion}) async => true;

  @override
  Future<QuoteBank?> bank() async => null;

  @override
  Future<bool> hasImage(QuoteImageKind kind, int version) async => kind == QuoteImageKind.logo;

  @override
  Future<void> ensureImages(int assetsVersion) async => log.add('images:$assetsVersion');

  @override
  Future<QuoteReserveOutcome> reserve(String documentId, QuoteKind kind) async {
    reserves.add((documentId, kind));
    log.add('reserve');
    return outcomes.isEmpty ? QuoteReserved(ok(kind: kind)) : outcomes.removeAt(0);
  }
}
