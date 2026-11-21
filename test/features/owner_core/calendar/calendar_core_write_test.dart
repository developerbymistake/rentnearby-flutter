import 'dart:async';

import 'package:bakhli/features/owner_core/calendar/calendar_api.dart';
import 'package:bakhli/features/owner_core/calendar/calendar_core_controller.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CalendarApi {
  _Api() : super(CalendarApi.taxiPrefix);

  final calls = <String>[];
  final gates = <String, Completer<OwnerResult<EntryWriteResult>>>{};

  Future<OwnerResult<EntryWriteResult>> _gate(String key) {
    calls.add(key);
    return (gates[key] = Completer()).future;
  }

  @override
  Future<OwnerResult<CalendarMonth>> month(DateTime from, DateTime to) async => const OwnerOffline();

  @override
  Future<OwnerResult<EntryWriteResult>> create(CalendarEntryDraft draft) => _gate('create');

  @override
  Future<OwnerResult<EntryWriteResult>> update(CalendarEntryDraft draft) => _gate('edit:${draft.id}');

  @override
  Future<OwnerResult<EntryWriteResult>> money(String id, {int? finalAmount, int? receivedSoFar, required bool paidInFull, required int version}) =>
      _gate('money:$id');
}

class _Ctrl extends CalendarCoreController {
  _Ctrl(_Api api) : super(api: api);

  @override
  bool get stayNights => false;

  @override
  String? get userId => null;
}

CalendarEntryDraft _draft(String id) => CalendarEntryDraft(id: id, label: 'Trip', dateFrom: DateTime(2026, 11, 25), dateTo: DateTime(2026, 11, 25));

void main() {
  test('a second, different write is sent while the first is in flight', () async {
    final api = _Api();
    final c = _Ctrl(api)..onInit();
    final a = c.create(_draft(''));
    final b = c.saveMoney(const CalendarEntry(id: 'e1'), finalAmount: 2000, paidInFull: false);
    expect(api.calls, ['create', 'money:e1']);
    expect(c.saving.value, isTrue);
    api.gates['create']!.complete(const OwnerOffline());
    await a;
    expect(c.saving.value, isTrue);
    api.gates['money:e1']!.complete(const OwnerOffline());
    expect(await b, isA<OwnerOffline<EntryWriteResult>>());
    expect(c.saving.value, isFalse);
  });

  test('a double tap of the same write joins the first call', () async {
    final api = _Api();
    final c = _Ctrl(api)..onInit();
    final a = c.edit(_draft('e2'));
    final b = c.edit(_draft('e2'));
    expect(api.calls, ['edit:e2']);
    api.gates['edit:e2']!.complete(const OwnerOffline());
    await Future.wait([a, b]);
    expect(c.saving.value, isFalse);
  });
}
