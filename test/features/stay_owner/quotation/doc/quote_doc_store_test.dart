import 'dart:convert';

import 'package:bakhli/features/stay_owner/quotation/data/quote_doc_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_fakes.dart';

void main() {
  group('Q22 one file per document, debounced autosave', () {
    test('keystrokes within 1.5 s write once; the index row follows', () async {
      final timers = TimerLog();
      final files = MemoryDocFiles();
      final store = QuoteDocStore(files: files, index: MemoryIndexBox(), timer: timers.call);
      final d = sampleDraft();
      store.saveLater(d.copyWith(guestName: 'H'));
      store.saveLater(d.copyWith(guestName: 'Ha'));
      store.saveLater(d.copyWith(guestName: 'Har'), total: 141026);
      expect(timers.timers.length, 3);
      expect(timers.timers.every((t) => t.duration == QuoteDocStore.debounce), isTrue);
      expect(timers.timers.take(2).every((t) => t.cancelled), isTrue);
      expect(files.writes, 0);
      timers.timers.last.fire();
      await Future<void>.delayed(Duration.zero);
      expect(files.writes, 1);
      final saved = QuoteDraft.fromJson(jsonDecode(files.files[d.documentId]!) as Map<String, dynamic>);
      expect(saved.guestName, 'Har');
      final row = store.rows().single;
      expect(row.guest, 'Har');
      expect(row.total, 141026);
      expect(row.downloaded, isFalse);
    });

    test('each document is its own file; saving one never rewrites another', () async {
      final files = MemoryDocFiles();
      final store = QuoteDocStore(files: files, index: MemoryIndexBox());
      final a = sampleDraft();
      final b = QuoteDraft.blank(documentId: 'doc-00000002', today: DateTime(2026, 11, 13));
      await store.saveNow(a);
      await store.saveNow(b);
      final before = files.files[a.documentId];
      await store.saveNow(b.copyWith(guestName: 'Second'));
      expect(files.files[a.documentId], before);
      expect(files.files.length, 2);
      expect(store.rows().length, 2);
    });

    test('round trip keeps lines, payments and reservations per kind', () async {
      final store = memoryStore();
      final d = sampleDraft(kind: QuoteKind.proforma)
          .copyWith(payments: [QuotePayment(id: 'p', kind: QuotePayKind.upi, label: 'UPI', date: DateTime(2026, 11, 20), amount: 5000)])
          .withReservation(QuoteKind.quotation, QuoteReservation(number: 42, display: 'Q-0042', issuedAt: DateTime.utc(2026, 11, 12), freeUntil: DateTime.utc(2026, 11, 13), freeLeft: 4, businessName: 'B', fileUri: 'content://x/1', fileName: 'Q-0042_H.pdf', pages: 1, savedAt: DateTime.utc(2026, 11, 12)));
      await store.saveNow(d);
      final back = await store.load(d.documentId);
      expect(back!.kind, QuoteKind.proforma);
      expect(back.lines.length, 4);
      expect(back.payments.single.amount, 5000);
      expect(back.reservationFor(QuoteKind.quotation)!.display, 'Q-0042');
      expect(back.reservationFor(QuoteKind.proforma), isNull);
      expect(back.downloaded, isTrue);
      final row = store.rows().single;
      expect(row.downloaded, isTrue);
      expect(row.number, 'Q-0042');
      expect(row.fileUri, 'content://x/1');
    });

    test('caps: 50 documents, nothing older than 90 days', () async {
      final now = DateTime(2026, 11, 27);
      final files = MemoryDocFiles();
      final store = QuoteDocStore(files: files, index: MemoryIndexBox(), now: () => now);
      for (var i = 0; i < 55; i++) {
        final d = QuoteDraft.blank(documentId: 'doc-${i.toString().padLeft(8, '0')}', today: now.subtract(Duration(days: i)));
        await store.saveNow(d);
      }
      final old = QuoteDraft.blank(documentId: 'doc-old00001', today: now.subtract(const Duration(days: 120)));
      await store.saveNow(old);
      await store.prune();
      final rows = store.rows();
      expect(rows.length, 50);
      expect(rows.any((r) => r.id == 'doc-old00001'), isFalse);
      expect(files.files.containsKey('doc-old00001'), isFalse);
    });

    test('a broken file loads as nothing, never a crash', () async {
      final files = MemoryDocFiles()..files['doc-broken01'] = '{not json';
      final store = QuoteDocStore(files: files, index: MemoryIndexBox());
      expect(await store.load('doc-broken01'), isNull);
    });
  });
}
