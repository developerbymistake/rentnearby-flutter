import '../data/owner_api.dart';
import '../data/owner_page.dart';
import '../data/owner_result.dart';
import '../json/owner_dates.dart';
import '../json/owner_json.dart';
import '../money/money_wire.dart';
import 'models/calendar_models.dart';

class CalendarEntryDraft {
  const CalendarEntryDraft({
    required this.id,
    required this.label,
    required this.dateFrom,
    required this.dateTo,
    this.timeOfDay,
    this.fromPlace,
    this.toPlace,
    this.note,
    this.finalAmount,
    this.receivedSoFar,
    this.paidInFull = false,
    this.version,
    this.keepVisible,
  });

  final String id;
  final String label;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? timeOfDay;
  final String? fromPlace;
  final String? toPlace;
  final String? note;
  final int? finalAmount;
  final int? receivedSoFar;
  final bool paidInFull;
  final int? version;
  final bool? keepVisible;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label.trim(),
        'dateFrom': OwnerDates.dayText(dateFrom),
        'dateTo': OwnerDates.dayText(dateTo),
        'timeOfDay': ?timeOfDay,
        'fromPlace': ?fromPlace,
        'toPlace': ?toPlace,
        'note': ?note,
        'finalAmount': ?finalAmount,
        MoneyWire.receivedKey: ?receivedSoFar,
        'paidInFull': paidInFull,
        'version': ?version,
        'keepVisible': ?keepVisible,
      };
}

class CalendarApi {
  const CalendarApi(this.prefix);

  static const String stayPrefix = '/stays/me/calendar';
  static const String taxiPrefix = '/taxis/me/calendar';

  final String prefix;

  Future<OwnerResult<CalendarMonth>> month(DateTime from, DateTime to) => OwnerApi.get(
        prefix,
        CalendarMonth.fromJson,
        params: {'from': OwnerDates.dayText(from), 'to': OwnerDates.dayText(to)},
      );

  Future<OwnerResult<UpcomingPage>> upcoming({String? cursor}) =>
      OwnerApi.get('$prefix/upcoming', UpcomingPage.fromJson, params: {'cursor': cursor});

  Future<OwnerResult<OwnerPage<CalendarEntry>>> past({String? cursor}) => OwnerApi.get(
        '$prefix/past',
        (d) => OwnerPage.fromJson(d, CalendarEntry.fromJson),
        params: {'cursor': cursor},
      );

  Future<OwnerResult<CalendarEntry>> entry(String id) => OwnerApi.get('$prefix/entries/$id', CalendarEntry.fromJson);

  Future<OwnerResult<EntryWriteResult>> create(CalendarEntryDraft draft) =>
      OwnerApi.post('$prefix/entries', draft.toJson(), EntryWriteResult.fromJson);

  Future<OwnerResult<EntryWriteResult>> update(CalendarEntryDraft draft) =>
      OwnerApi.put('$prefix/entries/${draft.id}', draft.toJson(), EntryWriteResult.fromJson);

  Future<OwnerResult<void>> delete(String id) => OwnerApi.delete('$prefix/entries/$id');

  Future<OwnerResult<EntryWriteResult>> money(String id, {int? finalAmount, int? receivedSoFar, required bool paidInFull, required int version}) =>
      OwnerApi.put(
        '$prefix/entries/$id/money',
        {'finalAmount': finalAmount, MoneyWire.receivedKey: receivedSoFar, 'paidInFull': paidInFull, 'version': version},
        (d) => EntryWriteResult.ofEntry(CalendarEntry.fromJson(d)),
      );

  Future<OwnerResult<MoneySummary>> summary(DateTime month) =>
      OwnerApi.get('$prefix/summary', MoneySummary.fromJson, params: {'month': OwnerDates.monthKey(month)});

  Future<OwnerResult<OwnerPage<CalendarEntry>>> balanceDue(DateTime month, {String? cursor}) => OwnerApi.get(
        '$prefix/balance-due',
        (d) => OwnerPage.fromJson(d, CalendarEntry.fromJson),
        params: {'month': OwnerDates.monthKey(month), 'cursor': cursor},
      );

  Future<OwnerResult<CalendarReminder>> reminder(bool on) =>
      OwnerApi.put('$prefix/reminder', {'on': on}, (d) => CalendarReminder.fromJson(OwnerJson.map(d['reminder'])));
}
