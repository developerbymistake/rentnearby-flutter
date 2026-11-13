import 'dart:async';

import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_reports.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/listing_report_model.dart';
import 'package:bakhli/screens/listing_reports_screen.dart';
import 'package:bakhli/screens/my_filed_reports_screen.dart';
import 'package:bakhli/screens/report_detail_screen.dart';
import 'package:bakhli/widgets/report_listing_sheet.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:bakhli/widgets/report_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

const _det1 = 'The owner asked me to pay the full amount on UPI before the visit and would not show the room.';
const _det2 = 'Driver asked for double the listed fare at pickup.';

ListingReportModel _r(String id, String type, String reason, DateTime filed, String status, {String details = '', DateTime? resolved}) =>
    ListingReportModel(id: id, listingId: 'l$id', listingType: type, reasonName: reason, details: details, status: status, createdAt: filed, resolvedAt: resolved);

final _my = [
  _r('1', 'Stay', 'Asked for advance', DateTime(2026, 11, 12), 'Pending', details: _det1),
  _r('2', 'Taxi', 'Wrong price', DateTime(2026, 11, 9), 'Pending'),
  _r('3', 'Stay', 'Wrong photos', DateTime(2026, 11, 2), 'Resolved'),
  _r('4', 'Taxi', 'Rude behaviour', DateTime(2026, 10, 28), 'Resolved'),
];

final _lrStay = [
  _r('5', 'Stay', 'Asked for advance', DateTime(2026, 11, 12), 'Pending'),
  _r('6', 'Stay', 'Wrong photos', DateTime(2026, 11, 6), 'Pending'),
  _r('7', 'Stay', 'Wrong price', DateTime(2026, 10, 30), 'Resolved'),
];

final _lrTaxi = [
  _r('8', 'Taxi', 'Wrong price', DateTime(2026, 11, 9), 'Pending'),
  _r('9', 'Taxi', 'Rude behaviour', DateTime(2026, 10, 28), 'Resolved'),
];

class _Reports extends ReportController {
  _Reports({this.list = const [], this.hang = false, this.reasons = true, this.submit, this.failMessage});

  final List<ListingReportModel> list;
  final bool hang;
  final bool reasons;
  final String? failMessage;
  final Future<bool> Function()? submit;
  int submits = 0;

  @override
  // ignore: must_call_super
  void onInit() {
    if (reasons) {
      reportReasons.value = [
        for (final (i, n) in ['Wrong price', 'Fake listing', 'Wrong photos', 'Asked for advance', 'Rude behaviour', 'Other'].indexed)
          ReportReasonModel(id: 'r$i', name: n),
      ];
    }
  }

  @override
  Future<void> loadReportReasons() async {}

  Future<List<ListingReportModel>> _fetch() {
    if (hang) return Completer<List<ListingReportModel>>().future;
    if (failMessage != null) Future.delayed(const Duration(milliseconds: 50), () => AppToast.error(failMessage!));
    return Future.value(list);
  }

  @override
  Future<List<ListingReportModel>> fetchMyFiledReports() => _fetch();

  @override
  Future<List<ListingReportModel>> fetchListingReports(String listingId, String listingType) => _fetch();

  @override
  Future<bool> submitReport({required String listingId, required String listingType, required String reasonId, required String details, String? tripEnquiryId}) {
    submits++;
    return (submit?.call() ?? Future.value(true)).then((ok) {
      if (!ok) AppToast.error('Could not submit report. Please try again.');
      return ok;
    });
  }
}

final _configs = <(double, double)>[(360, 1.0), (360, 1.3), (300, 1.0)];
String _tag(double w, double s) => '${w.toInt()}_${s == 1.0 ? '10' : '13'}';

Future<void> _snap(WidgetTester t, String name) async {
  await settlePhone(t);
  await shot(t, name);
  expect(t.takeException(), isNull);
}

class _Backdrop extends StatelessWidget {
  const _Backdrop(this.type);
  final String type;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Report3D.page(type),
        body: SafeArea(
          child: Column(children: [
            ReportHeader3D(tone: Report3D.tone(type), title: type == 'Taxi' ? 'UK 07 TA 1234' : 'Deodar Cottage', subtitle: 'Kausani, Uttarakhand', onBack: () {}),
          ]),
        ),
      );
}

Future<void> _openPage(WidgetTester t, Widget page, {Object? args, double w = 360, double s = 1.0}) async {
  await pumpPhone(t, const Scaffold(body: SizedBox()), size: Size(w, 800), devicePixelRatio: 1.5, textScale: s);
  Get.to(() => page, arguments: args, transition: Transition.noTransition);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _openSheet(WidgetTester t, String type, {double w = 360, double s = 1.0}) async {
  await pumpPhone(t, _Backdrop(type), size: Size(w, 800), devicePixelRatio: 1.5, textScale: s);
  ReportListingSheet.show(Get.context!, listingId: 'x', listingType: type);
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _fill(WidgetTester t, String reason, String text) async {
  await t.tap(find.byType(DropdownMenu<String>));
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.text(reason).last);
  await t.pump(const Duration(milliseconds: 400));
  await t.enterText(find.byType(TextField).last, text);
  await t.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\reports';
    debugDisableShadows = false;
  });
  tearDown(() {
    debugDisableShadows = true;
    Get.reset();
  });

  for (final (w, s) in _configs) {
    final tag = _tag(w, s);

    testWidgets('my reports list $tag', (t) async {
      Get.put<ReportController>(_Reports(list: _my));
      await _openPage(t, const MyFiledReportsScreen(), w: w, s: s);
      expect(find.byType(ReportRow), findsWidgets);
      await _snap(t, 'my_list_$tag');
      debugDisableShadows = true;
    });

    testWidgets('listing reports stay $tag', (t) async {
      Get.put<ReportController>(_Reports(list: _lrStay));
      await _openPage(t, const ListingReportsScreen(), args: {'listingId': 'a', 'listingType': 'Stay', 'title': 'Deodar Cottage'}, w: w, s: s);
      await _snap(t, 'lr_list_$tag');
      debugDisableShadows = true;
    });

    testWidgets('detail pending $tag', (t) async {
      await _openPage(t, const ReportDetailScreen(), args: _my.first, w: w, s: s);
      expect(find.text(_det1), findsOneWidget);
      await _snap(t, 'det_pending_$tag');
      debugDisableShadows = true;
    });

    testWidgets('sheet empty $tag', (t) async {
      Get.put<ReportController>(_Reports());
      await _openSheet(t, 'Stay', w: w, s: s);
      await _snap(t, 'sheet_empty_$tag');
      debugDisableShadows = true;
    });

    testWidgets('sheet filled $tag', (t) async {
      Get.put<ReportController>(_Reports());
      await _openSheet(t, 'Stay', w: w, s: s);
      await _fill(t, 'Asked for advance', _det1);
      await _snap(t, 'sheet_filled_$tag');
      debugDisableShadows = true;
    });
  }

  testWidgets('my reports loading', (t) async {
    Get.put<ReportController>(_Reports(hang: true));
    await _openPage(t, const MyFiledReportsScreen());
    await _snap(t, 'my_loading');
    debugDisableShadows = true;
  });

  testWidgets('my reports empty and error slot', (t) async {
    Get.put<ReportController>(_Reports());
    await _openPage(t, const MyFiledReportsScreen());
    expect(find.text("You haven't reported any listings"), findsOneWidget);
    await _snap(t, 'my_empty');
    ToastLane.showInHost(ToastKind.error, 'Could not load your reports. Please try again.');
    await t.pump(const Duration(milliseconds: 400));
    await _snap(t, 'my_error_slot');
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
  });

  testWidgets('my reports error toast', (t) async {
    Get.put<ReportController>(_Reports(failMessage: 'Could not load your reports. Please try again.'));
    await _openPage(t, const MyFiledReportsScreen());
    await t.pump(const Duration(milliseconds: 500));
    await _snap(t, 'my_error');
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
  });

  testWidgets('listing reports error toast', (t) async {
    Get.put<ReportController>(_Reports(failMessage: 'Could not load reports. Please try again.'));
    await _openPage(t, const ListingReportsScreen(), args: {'listingId': 'a', 'listingType': 'Stay', 'title': 'Deodar Cottage'});
    await t.pump(const Duration(milliseconds: 500));
    await _snap(t, 'lr_error');
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
  });

  testWidgets('listing reports taxi', (t) async {
    Get.put<ReportController>(_Reports(list: _lrTaxi));
    await _openPage(t, const ListingReportsScreen(), args: {'listingId': 'a', 'listingType': 'Taxi', 'title': 'UK 07 TA 1234'});
    await _snap(t, 'lr_taxi');
    debugDisableShadows = true;
  });

  testWidgets('listing reports loading', (t) async {
    Get.put<ReportController>(_Reports(hang: true));
    await _openPage(t, const ListingReportsScreen(), args: {'listingId': 'a', 'listingType': 'Stay', 'title': 'Deodar Cottage'});
    await _snap(t, 'lr_loading');
    debugDisableShadows = true;
  });

  testWidgets('listing reports empty', (t) async {
    Get.put<ReportController>(_Reports());
    await _openPage(t, const ListingReportsScreen(), args: {'listingId': 'a', 'listingType': 'Stay', 'title': 'Deodar Cottage'});
    expect(find.text('No reports found'), findsOneWidget);
    await _snap(t, 'lr_empty');
    ToastLane.showInHost(ToastKind.error, 'Could not load reports. Please try again.');
    await t.pump(const Duration(milliseconds: 400));
    await _snap(t, 'lr_error_slot');
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
  });

  testWidgets('detail resolved', (t) async {
    await _openPage(t, const ReportDetailScreen(),
        args: _r('4', 'Taxi', 'Rude behaviour', DateTime(2026, 10, 28), 'Resolved', details: 'Driver shouted at us and left us halfway.', resolved: DateTime(2026, 10, 31)));
    expect(find.text('RESOLVED ON'), findsOneWidget);
    await _snap(t, 'det_resolved');
    debugDisableShadows = true;
  });

  testWidgets('detail no details', (t) async {
    await _openPage(t, const ReportDetailScreen(), args: _r('6', 'Stay', 'Wrong photos', DateTime(2026, 11, 6), 'Pending'));
    expect(find.text('No additional details provided.'), findsOneWidget);
    await _snap(t, 'det_nodetails');
    debugDisableShadows = true;
  });

  testWidgets('row tap fires callback', (t) async {
    var taps = 0;
    await pumpPhone(t, Scaffold(body: ListView(children: [ReportRow(report: _my.first, onTap: () => taps++)])));
    await t.tap(find.byType(ReportRow));
    expect(taps, 1);
    debugDisableShadows = true;
  });

  testWidgets('sheet menu open', (t) async {
    Get.put<ReportController>(_Reports());
    await _openSheet(t, 'Stay');
    await t.tap(find.byType(DropdownMenu<String>));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Asked for advance').last);
    await t.pump(const Duration(milliseconds: 1000));
    for (var k = 0; k < 3 && find.byType(MenuItemButton).hitTestable().evaluate().isEmpty; k++) {
      await t.tap(find.byType(TextField).first);
      await t.pump(const Duration(milliseconds: 600));
    }
    expect(find.byType(MenuItemButton).hitTestable(), findsWidgets);
    await _snap(t, 'sheet_menu');
    debugDisableShadows = true;
  });

  testWidgets('sheet no reasons', (t) async {
    Get.put<ReportController>(_Reports(reasons: false));
    await _openSheet(t, 'Stay');
    await t.tap(find.byType(DropdownMenu<String>));
    await t.pump(const Duration(milliseconds: 400));
    await _snap(t, 'sheet_noreasons');
    debugDisableShadows = true;
  });

  testWidgets('sheet confirm, loading, error keeps sheet', (t) async {
    final pending = Completer<bool>();
    final c = _Reports(submit: () => pending.future);
    Get.put<ReportController>(c);
    await _openSheet(t, 'Stay');
    await _fill(t, 'Asked for advance', _det1);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('Submit'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Report this listing?'), findsOneWidget);
    await _snap(t, 'sheet_confirm');
    await t.tap(find.text('Report'));
    await t.pump(const Duration(milliseconds: 400));
    expect(c.submits, 1);
    await _snap(t, 'sheet_loading');
    pending.complete(false);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Report this listing'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 400));
    await _snap(t, 'sheet_error');
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
  });

  testWidgets('sheet submit off until valid, cancel closes', (t) async {
    Get.put<ReportController>(_Reports());
    await _openSheet(t, 'Stay');
    await t.tap(find.text('Submit'), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Report this listing?'), findsNothing);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Report this listing'), findsNothing);
    debugDisableShadows = true;
  });

  testWidgets('sheet taxi filled', (t) async {
    Get.put<ReportController>(_Reports());
    await _openSheet(t, 'Taxi');
    await _fill(t, 'Wrong price', _det2);
    await _snap(t, 'sheet_taxi');
    debugDisableShadows = true;
  });
}
