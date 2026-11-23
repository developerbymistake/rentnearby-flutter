import 'package:bakhli/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
      'id': 'u1',
      'phoneNumber': '9876543210',
      'createdAt': '2026-11-22T10:00:00Z',
      ...extra,
    };

void main() {
  test('key missing: photo unknown, never gated', () {
    final u = UserModel.fromJson(_json());
    expect(u.photoKnown, isFalse);
    expect(u.profilePhotoUrl, isNull);
    expect(u.needsProfilePhoto, isFalse);
    expect(u.profilePhotoRemoved, isFalse);
  });

  test('null, blank and non-string values read as no picture; a user who never added one is NOT asked (optional)', () {
    for (final raw in [null, '', '   ', 42, true, const ['x']]) {
      final u = UserModel.fromJson(_json({'profilePhotoUrl': raw}));
      expect(u.photoKnown, isTrue, reason: '$raw');
      expect(u.profilePhotoUrl, isNull, reason: '$raw');
      expect(u.needsProfilePhoto, isFalse, reason: '$raw');
    }
  });

  test('a picture removed by the admin must be replaced', () {
    final u = UserModel.fromJson(_json({'profilePhotoUrl': null, 'profilePhotoRemoved': true}));
    expect(u.needsProfilePhoto, isTrue);
  });

  test('present url is trimmed and not gated', () {
    final u = UserModel.fromJson(_json({'profilePhotoUrl': ' https://res.cloudinary.com/x/a.jpg '}));
    expect(u.profilePhotoUrl, 'https://res.cloudinary.com/x/a.jpg');
    expect(u.needsProfilePhoto, isFalse);
  });

  test('profilePhotoRemoved is true only for a real true', () {
    expect(UserModel.fromJson(_json({'profilePhotoUrl': null, 'profilePhotoRemoved': true})).profilePhotoRemoved, isTrue);
    for (final raw in [false, 'true', 1, null]) {
      expect(UserModel.fromJson(_json({'profilePhotoRemoved': raw})).profilePhotoRemoved, isFalse, reason: '$raw');
    }
  });

  test('toJson round trip keeps photoKnown in both states', () {
    final unknown = UserModel.fromJson(UserModel.fromJson(_json()).toJson());
    expect(unknown.photoKnown, isFalse);
    expect(unknown.toJson().containsKey('profilePhotoUrl'), isFalse);

    final none = UserModel.fromJson(UserModel.fromJson(_json({'profilePhotoUrl': null, 'profilePhotoRemoved': true})).toJson());
    expect(none.photoKnown, isTrue);
    expect(none.needsProfilePhoto, isTrue);
    expect(none.profilePhotoRemoved, isTrue);

    final set = UserModel.fromJson(UserModel.fromJson(_json({'profilePhotoUrl': 'https://x/y.jpg'})).toJson());
    expect(set.photoKnown, isTrue);
    expect(set.profilePhotoUrl, 'https://x/y.jpg');
  });

  test('constructor defaults keep old callers unchanged', () {
    final u = UserModel(id: 'u', phoneNumber: '1', createdAt: DateTime(2026));
    expect(u.photoKnown, isFalse);
    expect(u.needsProfilePhoto, isFalse);
  });
}
