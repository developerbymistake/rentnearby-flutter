import 'dart:convert';

import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/utils/jwt_claims.dart';
import 'package:flutter_test/flutter_test.dart';

String _token(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.signature';
}

void main() {
  group('JwtClaims.role', () {
    test('returns RENT_OWNER from a rent-owner token', () {
      final token = _token({'sub': 'u1', 'session_id': 's1', UserRoleKeys.claim: UserRoleKeys.rentOwner});
      expect(JwtClaims.role(token), UserRoleKeys.rentOwner);
    });

    test('returns PROPERTY_OWNER from a property-owner token', () {
      final token = _token({'sub': 'u1', 'session_id': 's1', UserRoleKeys.claim: UserRoleKeys.propertyOwner});
      expect(JwtClaims.role(token), UserRoleKeys.propertyOwner);
    });

    test('returns SEEKER from a seeker token', () {
      final token = _token({'sub': 'u1', UserRoleKeys.claim: UserRoleKeys.seeker});
      expect(JwtClaims.role(token), UserRoleKeys.seeker);
    });

    test('returns null when the role claim is missing', () {
      expect(JwtClaims.role(_token({'sub': 'u1'})), isNull);
    });

    test('returns null when the role claim is not a string', () {
      expect(JwtClaims.role(_token({UserRoleKeys.claim: 1})), isNull);
    });

    test('returns null for a null token', () {
      expect(JwtClaims.role(null), isNull);
    });

    test('returns null for a malformed token', () {
      expect(JwtClaims.role('not-a-jwt'), isNull);
      expect(JwtClaims.role('a.%%%.c'), isNull);
    });
  });
}
