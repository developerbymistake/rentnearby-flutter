import 'package:jwt_decoder/jwt_decoder.dart';
import '../config/user_roles.dart';

class JwtClaims {
  const JwtClaims._();

  static String? role(String? token) {
    if (token == null) return null;
    final value = JwtDecoder.tryDecode(token)?[UserRoleKeys.claim];
    return value is String ? value : null;
  }

  static const List<String> userIdKeys = ['nameid', 'sub', 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];

  static String? userId(String? token) {
    if (token == null) return null;
    final claims = JwtDecoder.tryDecode(token);
    if (claims == null) return null;
    for (final key in userIdKeys) {
      final value = claims[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}
