import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FX-36 a 401 maps its error type to the logout reason', () {
    Map<String, dynamic> body(Object? type) => {'error': {'type': type, 'message': 'x'}};
    expect(ApiService.reasonFor401(body('SessionRoleChanged')), LogoutReason.roleChanged);
    expect(ApiService.reasonFor401(body('AccountSuspended')), LogoutReason.accountSuspended);
    expect(ApiService.reasonFor401(body('Unauthorized')), LogoutReason.sessionExpired);
    expect(ApiService.reasonFor401(body(7)), LogoutReason.sessionExpired);
    expect(ApiService.reasonFor401(null), LogoutReason.sessionExpired);
    expect(ApiService.reasonFor401('<html>'), LogoutReason.sessionExpired);
    expect(ApiService.reasonFor401({'error': 'x'}), LogoutReason.sessionExpired);
  });
}
