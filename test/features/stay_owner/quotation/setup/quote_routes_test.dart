import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/stay_owner/quotation/stay_owner_only_middleware.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  const quoteRoutes = {
    AppRoutes.stayQuotations: '/stay-quotations',
    AppRoutes.stayQuotationBusiness: '/stay-quotation-business',
    AppRoutes.stayQuotationEdit: '/stay-quotation-edit',
    AppRoutes.stayQuotationTemplate: '/stay-quotation-template',
    AppRoutes.stayQuotationPreview: '/stay-quotation-preview',
  };

  test('five quotation routes, registered, stay owner only, each with the stay owner middleware', () {
    for (final e in quoteRoutes.entries) {
      expect(e.key, e.value);
      expect(AppRoutes.isRegistered(e.key), isTrue, reason: e.key);
      expect(AppRoutes.stayOwnerNewRoutes, contains(e.key));
      expect(AppRoutes.stayOwnerOnly, contains(e.key));
      expect(AppRoutes.travellerOnly, isNot(contains(e.key)));
      final page = AppRoutes.routes.firstWhere((p) => p.name == e.key);
      expect((page.middlewares ?? const []).whereType<StayOwnerOnlyMiddleware>(), hasLength(1), reason: e.key);
    }
  });

  test('the middleware passes the page through when no session gate applies', () {
    Get.reset();
    Widget page() => const SizedBox();
    final out = StayOwnerOnlyMiddleware().onPageBuildStart(page);
    expect(out!(), isA<SizedBox>());
  });
}
