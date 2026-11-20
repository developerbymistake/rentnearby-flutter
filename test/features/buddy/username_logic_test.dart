import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/buddy/buddy_strings.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Object? username = 'Bakhli#48291736', bool withKey = true}) => {
      'id': 'u1',
      'phoneNumber': '9876543210',
      'createdAt': '2026-11-20T10:00:00Z',
      'name': 'Rahul Mehra',
      if (withKey) 'username': username,
    };

void main() {
  group('UserModel.username', () {
    test('parses the backend field "username"', () {
      expect(UserModel.fromJson(_json()).username, 'Bakhli#48291736');
    });

    test('is null for an old response without the field', () {
      expect(UserModel.fromJson(_json(withKey: false)).username, isNull);
    });

    test('is null for null, blank or non-text values', () {
      expect(UserModel.fromJson(_json(username: null)).username, isNull);
      expect(UserModel.fromJson(_json(username: '  ')).username, isNull);
      expect(UserModel.fromJson(_json(username: 42)).username, isNull);
    });

    test('trims and survives the storage round trip', () {
      final u = UserModel.fromJson(_json(username: ' Bakhli#12345678 '));
      expect(u.username, 'Bakhli#12345678');
      expect(u.toJson()['username'], 'Bakhli#12345678');
      expect(UserModel.fromJson(u.toJson()).username, 'Bakhli#12345678');
    });
  });

  group('AuthController.signupUsernameOf (verify-otp response for a new user)', () {
    test('reads a top level username', () {
      expect(AuthController.signupUsernameOf({'needsOnboarding': true, 'username': 'Bakhli#11112222'}), 'Bakhli#11112222');
    });

    test('reads user.username when the user object is sent', () {
      expect(
        AuthController.signupUsernameOf({'needsOnboarding': true, 'user': {'username': 'Bakhli#33334444'}}),
        'Bakhli#33334444',
      );
    });

    test('is null when the server sent none', () {
      expect(AuthController.signupUsernameOf({'needsOnboarding': true}), isNull);
      expect(AuthController.signupUsernameOf({'needsOnboarding': true, 'user': null, 'username': ''}), isNull);
    });
  });

  group('qr sheet text', () {
    test('initial of the name', () {
      expect(BuddyStrings.initialOf(' rahul'), 'R');
      expect(BuddyStrings.initialOf(''), '');
    });
  });
}
