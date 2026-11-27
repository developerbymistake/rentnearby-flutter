import 'package:bakhli/utils/account_delete_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(int status, {String? type, List<Map<String, String>>? reasons, String message = 'srv'}) {
  final req = RequestOptions(path: '/account');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: {
      'status': '$status',
      'error': {'type': type, 'message': message},
      'data': reasons == null ? null : {'reasons': reasons},
    }),
  );
}

DioException _one(String code) =>
    _err(409, type: 'AccountHasActiveItems', reasons: [{'code': code, 'message': 'server text'}]);

void main() {
  const expected = {
    'ActiveTaxiBooking': 'You have an active taxi booking. You can delete your account after it ends.',
    'ActiveStayBooking': 'You have an active stay booking. You can delete your account after it ends.',
    'SelectedTaxiOffer': 'A traveller has chosen you. Confirm or decline the trip first.',
    'OpenTaxiRequest': 'You have an open taxi request. Cancel it first.',
    'OpenStayEnquiry': 'You have an open stay enquiry. Close it first.',
    'LiveListing': 'Take your listing offline first.',
    'ActiveSubscription': 'You have an active subscription. Cancel it in Google Play first, then delete your account.',
  };

  for (final e in expected.entries) {
    test('reason ${e.key}', () => expect(AccountDeleteMessage.from(_one(e.key)), e.value));
  }

  test('several reasons are all shown in order', () {
    final err = _err(409, type: 'AccountHasActiveItems', reasons: [
      {'code': 'OpenTaxiRequest', 'message': 'a'},
      {'code': 'LiveListing', 'message': 'b'},
    ]);
    expect(AccountDeleteMessage.from(err), '${expected['OpenTaxiRequest']}\n${expected['LiveListing']}');
  });

  test('unknown code falls back to server message', () {
    expect(AccountDeleteMessage.from(_one('Brand New')), 'server text');
  });

  test('409 without reasons uses error message, then generic', () {
    expect(AccountDeleteMessage.from(_err(409, type: 'AccountHasActiveItems', message: 'old msg')), 'old msg');
    expect(AccountDeleteMessage.from(_err(409, type: 'AccountHasActiveItems', message: '')), AccountDeleteMessage.fallback);
  });

  test('other errors are not handled', () {
    expect(AccountDeleteMessage.from(_err(409, type: 'Other')), isNull);
    expect(AccountDeleteMessage.from(_err(500, type: 'AccountHasActiveItems')), isNull);
    expect(AccountDeleteMessage.from(Exception('x')), isNull);
  });
}
