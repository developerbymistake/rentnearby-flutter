import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/models/listing_report_model.dart';
import 'package:bakhli/screens/my_filed_reports_screen.dart';
import 'package:bakhli/widgets/report_row.dart';

class _FakeReportController extends ReportController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<List<ListingReportModel>> fetchMyFiledReports() async => [
        ListingReportModel(id: '1', listingId: 'a', listingType: 'Stay', reasonName: 'Spam', details: 'Some details here', status: 'Pending', createdAt: DateTime(2026, 1, 2)),
        ListingReportModel(id: '2', listingId: 'b', listingType: 'Taxi', reasonName: 'Fake', details: '', status: 'Resolved', createdAt: DateTime(2026, 1, 3), resolvedAt: DateTime(2026, 1, 4)),
      ];
}

void main() {
  testWidgets('my reports: tap row opens detail with body visible', (t) async {
    Get.put<ReportController>(_FakeReportController());
    await t.pumpWidget(GetMaterialApp(
      initialRoute: '/start',
      getPages: [
        GetPage(name: '/start', page: () => const MyFiledReportsScreen()),
        ...AppRoutes.routes.where((p) => p.name == AppRoutes.reportDetail),
      ],
    ));
    await t.pumpAndSettle();
    expect(find.byType(ReportRow), findsNWidgets(2));
    await t.tap(find.byType(ReportRow).first);
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    }
    await t.pumpAndSettle();
    expect(find.text('Some details here'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
