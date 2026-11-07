import 'package:bakhli/utils/dio_error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _error(int status, String type, String message) {
  final req = RequestOptions(path: '/trips');
  return DioException(
    requestOptions: req,
    response: Response(
      requestOptions: req,
      statusCode: status,
      data: {
        'success': false,
        'error': {'type': type, 'message': message},
      },
    ),
  );
}

void main() {
  group('trip cap errors', () {
    test('too many places a day passes the server message through', () {
      final e = _error(400, 'TooManySpotsPerDay', 'Up to 6 places a day');
      expect(DioErrorMapper.errorType(e), 'TooManySpotsPerDay');
      expect(DioErrorMapper.toMessage(e, 'Could not save'), 'Up to 6 places a day');
    });

    test('too many places for the days passes the server message through', () {
      final e = _error(400, 'TooManySpotsForDays', 'Up to 12 places for 2 days (6 a day)');
      expect(DioErrorMapper.toMessage(e, 'Could not plan'), 'Up to 12 places for 2 days (6 a day)');
    });

    test('the cap messages show even when the caller shows no raw 400', () {
      final e = _error(400, 'TooManySpotsPerDay', 'Up to 6 places a day');
      expect(DioErrorMapper.toMessage(e, 'Could not save', showRawMessageForStatusCodes: const {}), 'Up to 6 places a day');
    });
  });

  group('existing mappings stay', () {
    test('a typed 409 shows its message, a 502 stays generic, a missing message falls back', () {
      expect(DioErrorMapper.toMessage(_error(409, 'TripNeedsUpdate', 'Update the app'), 'x'), 'Update the app');
      expect(DioErrorMapper.toMessage(_error(502, 'Whatever', 'boom'), 'x'), 'Server is busy. Please try again in a moment.');
      expect(DioErrorMapper.toMessage('not a dio error', 'Fallback'), 'Fallback');
    });

    test('an untyped 400 still shows the raw message', () {
      expect(DioErrorMapper.toMessage(_error(400, 'BadRequest', 'City is required'), 'x'), 'City is required');
    });
  });
}
