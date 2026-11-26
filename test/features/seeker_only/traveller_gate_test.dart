import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/navigation/traveller_gate.dart';
import 'package:bakhli/utils/dio_error_mapper.dart';
import 'package:bakhli/widgets/traveller_only_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../support/real_phone.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Widget _page() => const Text('traveller page');

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  group('TravellerOnlyMiddleware', () {
    test('a seeker gets the same builder back', () {
      Get.put<AuthController>(_Auth());
      final out = TravellerOnlyMiddleware().onPageBuildStart(_page);
      expect(identical(out, _page), isTrue);
    });

    test('stay owner and taxi driver get the calm page', () {
      for (final role in [UserRoleKeys.stayOwner, UserRoleKeys.taxiDriver, 'SOMETHING_NEW']) {
        Get.reset();
        Get.put<AuthController>(_Auth()).roleKey.value = role;
        final out = TravellerOnlyMiddleware().onPageBuildStart(_page);
        expect(identical(out, _page), isFalse, reason: role);
        expect(out!(), isA<TravellerOnlyScreen>(), reason: role);
      }
    });

    test('no AuthController registered: allowed', () {
      expect(TravellerGate.allowed, isTrue);
      expect(identical(TravellerOnlyMiddleware().onPageBuildStart(_page), _page), isTrue);
    });
  });

  test('the toast line equals the server message byte for byte', () {
    expect(TravellerGateStrings.line, 'These features are for travellers. Use a seeker account.');
    expect(TravellerGateStrings.title, 'These features are for travellers.');
    expect(TravellerGateStrings.message, 'Use a seeker account.');
    expect(TravellerGateStrings.goBack, 'Go back');
  });

  test('a 403 SeekerOnly answer maps to the calm line', () {
    final req = RequestOptions(path: '/trips');
    final e = DioException(
      requestOptions: req,
      response: Response(
        requestOptions: req,
        statusCode: 403,
        data: {
          'status': '403',
          'code': 403,
          'timestamp': 1764115200,
          'data': null,
          'error': {'message': 'These features are for travellers. Use a seeker account.', 'type': 'SeekerOnly'},
        },
      ),
    );
    expect(DioErrorMapper.errorType(e), 'SeekerOnly');
    expect(DioErrorMapper.toMessage(e, 'Could not load.'), TravellerGateStrings.line);
  });

  for (final w in [320.0, 411.0]) {
    for (final sc in [1.0, 1.3]) {
      testWidgets('calm page at $w @$sc shows both lines and Go back without overflow', (t) async {
        await pumpPhone(t, const TravellerOnlyScreen(), size: Size(w, 800), textScale: sc);
        await settlePhone(t);
        expect(find.text(TravellerGateStrings.title), findsOneWidget);
        expect(find.text(TravellerGateStrings.message), findsOneWidget);
        expect(find.text(TravellerGateStrings.goBack), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
