import 'package:bakhli/features/owner_core/calendar/calendar_api.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/money/money_note_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';

void main() {
  tearDown(OwnerApi.debugReset);

  const api = CalendarApi(CalendarApi.stayPrefix);

  test('reminder reads the nested reminder block (switch stays on)', () async {
    OwnerApi.transport = FakeTransport((m, p, b) async => {
          'data': {
            'reminder': {'allowed': true, 'on': true},
          },
        });
    final r = await api.reminder(true);
    expect(r, isA<OwnerOk<CalendarReminder>>());
    final v = (r as OwnerOk<CalendarReminder>).value;
    expect(v.allowed, isTrue);
    expect(v.on, isTrue);
  });

  test('money reads the bare entry body (Mark paid shows Paid)', () async {
    final entry = Map<String, dynamic>.from(loadSample('calendar_summary')['topBalances'][0] as Map)
      ..['paidInFull'] = true
      ..['chip'] = 'PaidInFull'
      ..['balance'] = 0
      ..['chipAmount'] = 0
      ..['version'] = 2;
    OwnerApi.transport = FakeTransport((m, p, b) async => {'data': entry});
    final r = await api.money(entry['id'] as String, paidInFull: true, version: 1);
    expect(r, isA<OwnerOk<EntryWriteResult>>());
    final e = (r as OwnerOk<EntryWriteResult>).value.entry;
    expect(e, isNotNull);
    expect(e!.paidInFull, isTrue);
    expect(e.chip, MoneyChip.paidInFull);
    expect(e.version, 2);
  });
}
