import 'package:jwt_decoder/jwt_decoder.dart';
import '../config/user_roles.dart';

class JwtClaims {
  const JwtClaims._();

  static String? role(String? token) {
    if (token == null) return null;
    final value = JwtDecoder.tryDecode(token)?[UserRoleKeys.claim];
    return value is String ? value : null;
  }
}
