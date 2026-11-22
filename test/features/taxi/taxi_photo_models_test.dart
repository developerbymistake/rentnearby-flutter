import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../taxi_driver/core/taxi_fixtures.dart';

TaxiOwnerModel _parse(Map<String, Object?> extra, {bool dropKeys = false}) {
  final json = taxiJson()..addAll(extra);
  if (dropKeys) {
    json
      ..remove('displayPhotoUrl')
      ..remove('platePhotoLocked');
  }
  return TaxiOwnerModel.fromJson(json);
}

void main() {
  group('displayPhotoUrl', () {
    test('a valid https url is kept', () {
      final m = _parse({'displayPhotoUrl': 'https://res.cloudinary.com/x/taxi.jpg'});
      expect(m.displayPhotoUrl, 'https://res.cloudinary.com/x/taxi.jpg');
      expect(m.hasDisplayPhoto, isTrue);
    });

    test('missing, null, number, empty, blank and junk all parse to null and never throw', () {
      final cases = <String, Map<String, Object?>>{
        'missing': {},
        'null': {'displayPhotoUrl': null},
        'number': {'displayPhotoUrl': 42},
        'empty': {'displayPhotoUrl': ''},
        'blank': {'displayPhotoUrl': '   '},
        'junk': {'displayPhotoUrl': 'abc'},
      };
      for (final e in cases.entries) {
        final m = _parse(e.value, dropKeys: e.key == 'missing');
        expect(m.displayPhotoUrl, isNull, reason: e.key);
        expect(m.hasDisplayPhoto, isFalse, reason: e.key);
      }
    });
  });

  test('platePhotoUrl is still parsed for the owner', () {
    final m = _parse({'platePhotoUrl': 'https://res.cloudinary.com/x/plate.jpg'});
    expect(m.platePhotoUrl, 'https://res.cloudinary.com/x/plate.jpg');
    expect(_parse({'platePhotoUrl': null}).platePhotoUrl, isNull);
  });

  test('proofLocked is true only when platePhotoLocked or everApproved is the bool true', () {
    const lockedValues = <String, Object?>{'true': true, 'false': false, 'missing': null, 'string': 'true'};
    for (final locked in lockedValues.entries) {
      for (final ever in [true, false]) {
        final json = taxiJson()..['everApproved'] = ever;
        if (locked.key == 'missing') {
          json.remove('platePhotoLocked');
        } else {
          json['platePhotoLocked'] = locked.value;
        }
        final m = TaxiOwnerModel.fromJson(json);
        final expected = locked.value == true || ever;
        expect(m.platePhotoLocked, locked.value == true, reason: '${locked.key} / $ever');
        expect(m.proofLocked, expected, reason: '${locked.key} / $ever');
      }
    }
  });

  test('proofFrozen adds the first review to the lock', () {
    for (final status in ['Draft', 'PendingReview', 'Approved', 'Rejected']) {
      for (final ever in [true, false]) {
        final json = taxiJson()
          ..['status'] = status
          ..['everApproved'] = ever
          ..['platePhotoLocked'] = false;
        final m = TaxiOwnerModel.fromJson(json);
        expect(m.proofFrozen, ever || status == 'PendingReview', reason: '$status / $ever');
      }
    }
  });
}
