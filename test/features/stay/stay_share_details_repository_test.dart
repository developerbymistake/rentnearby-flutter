import 'dart:typed_data';

import 'package:bakhli/features/stay/setup/stay_repository.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _reply =
    '{"data": {"id": "s1", "status": "Approved", "name": "Deodar Cottage", "upiId": "deodar@okaxis", "whatsAppNumber": "9876543210", "rooms": []}, "status": "200", "code": 200}';

class _Api implements HttpClientAdapter {
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString(_reply, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('save share details puts to /stays/me/share-details', () async {
    ApiService.init();
    final api = _Api();
    ApiService.dio.httpClientAdapter = api;
    final stay = await const StayRepository().saveShareDetails(upiId: 'deodar@okaxis', whatsAppNumber: '9876543210');
    expect(api.seen.single.method, 'PUT');
    expect(api.seen.single.path, '/stays/me/share-details');
    expect(api.seen.single.data, {'upiId': 'deodar@okaxis', 'whatsAppNumber': '9876543210'});
    expect(stay?.hasShareDetails, isTrue);
  });
}
