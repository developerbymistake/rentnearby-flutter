import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/utils/trip_continue_pick.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 10);

String _d(int o) {
  final d = DateTime(_today.year, _today.month, _today.day + o);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

TripSummaryModel _t(String id, {int? startIn, int days = 3, String updated = '2026-11-01T10:00:00Z', String status = 'Planned'}) =>
    TripSummaryModel.fromJson({
      'id': id,
      'title': '',
      'status': status,
      'cityName': 'Nainital',
      'dayCount': days,
      'spotCount': 4,
      'category': 'attraction',
      if (startIn != null) 'startDate': _d(startIn),
      if (startIn != null) 'endDate': _d(startIn + days - 1),
      'updatedAt': updated,
    });

void main() {
  test('pickMany returns at most the rail max, soonest first', () {
    final l = [_t('d', startIn: 40), _t('a', startIn: 2), _t('c', startIn: 20), _t('b', startIn: 9)];
    expect(TripContinuePick.pickMany(l, _today).map((e) => e.id), ['a', 'b', 'c']);
  });

  String? pick(List<TripSummaryModel> l) => TripContinuePick.pickMany(l, _today, 1).firstOrNull?.id;

  test('empty list gives null', () => expect(pick([]), isNull));

  test('soonest start date wins', () {
    expect(pick([_t('far', startIn: 30), _t('near', startIn: 5), _t('mid', startIn: 12)]), 'near');
  });

  test('dated trip beats a newer undated one', () {
    expect(pick([_t('undated', updated: '2026-11-09T10:00:00Z'), _t('dated', startIn: 40)]), 'dated');
  });

  test('tie on start date goes to the latest updated', () {
    expect(pick([_t('a', startIn: 5), _t('b', startIn: 5, updated: '2026-11-05T10:00:00Z')]), 'b');
  });

  test('no dates picks the most recently updated', () {
    expect(pick([_t('old'), _t('new', updated: '2026-11-08T10:00:00Z'), _t('mid', updated: '2026-11-03T10:00:00Z')]), 'new');
  });

  test('completed trips are never picked', () {
    expect(pick([_t('done', startIn: 1, status: 'Completed'), _t('later', startIn: 20)]), 'later');
    expect(pick([_t('done', status: 'Completed')]), isNull);
  });

  test('ended trips are skipped, a running trip counts as soonest', () {
    expect(pick([_t('ended', startIn: -10), _t('running', startIn: -1), _t('soon', startIn: 3)]), 'running');
    expect(pick([_t('ended', startIn: -10)]), isNull);
  });
}
