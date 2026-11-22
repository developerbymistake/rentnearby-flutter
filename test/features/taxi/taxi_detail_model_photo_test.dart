import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/features/taxi/models/taxi_detail_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _taxi([Map<String, dynamic> extra = const {}]) => {
      'id': 't1',
      'driverName': 'Rakesh Singh',
      'vehicleTypeName': 'Sedan',
      'plateDisplay': 'UK04',
      'createdAt': '2026-11-01T00:00:00Z',
      ...extra,
    };

void main() {
  test('displayPhotoUrl: valid absolute and relative urls parse', () {
    expect(TaxiDetailModel.fromJson(_taxi({'displayPhotoUrl': 'https://res.cloudinary.com/d.jpg'})).displayPhotoUrl, 'https://res.cloudinary.com/d.jpg');
    expect(TaxiDetailModel.fromJson(_taxi({'displayPhotoUrl': '/uploads/d.jpg'})).displayPhotoUrl, '${AppConstants.serverUrl}/uploads/d.jpg');
  });

  test('displayPhotoUrl: missing, null, empty, number and junk are null', () {
    expect(TaxiDetailModel.fromJson(_taxi()).displayPhotoUrl, isNull);
    for (final bad in <Object?>[null, '', 'x', 12, true]) {
      expect(TaxiDetailModel.fromJson(_taxi({'displayPhotoUrl': bad})).displayPhotoUrl, isNull, reason: '$bad');
    }
  });

  test('a payload that still carries platePhotoUrl parses and the plate photo is never exposed', () {
    final m = TaxiDetailModel.fromJson(_taxi({'platePhotoUrl': 'https://x/plate.jpg'}));
    expect(m.displayPhotoUrl, isNull);
    expect(m.driverName, 'Rakesh Singh');
    expect(() => (m as dynamic).platePhotoUrl, throwsNoSuchMethodError);
  });
}
