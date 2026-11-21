import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:bakhli/features/jobs/models/my_job_model.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/jobs_tab/stay_jobs_tab.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';

Map<String, dynamic> _job(String id, String title, int years, int salary, {int daysAgo = 2, bool food = true}) => {
      'id': id,
      'title': title,
      'minimumExperienceYears': years,
      'salaryTypeName': 'Monthly',
      'stayName': 'Deodar Heights Homestay',
      'minSalary': salary,
      'maxSalary': salary,
      'status': 'Active',
      'createdAt': DateTime.now().subtract(Duration(days: daysAgo)).toUtc().toIso8601String(),
      'foodAndStay': food,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {required int max, bool payment = true, bool? canUpgrade, String status = 'Approved'}) {
  final active = items.length;
  return {
    'items': items,
    'activeCount': active,
    'maxActive': max,
    'stayStatus': status,
    'canPost': status == 'Approved' && active < max,
    'paymentEnabled': payment,
    'canUpgrade': canUpgrade ?? payment,
    'overCap': active > max,
  };
}

final _cook = _job('j1', 'Cook', 2, 14000);
final _house = _job('j2', 'Housekeeping', 0, 10000, daysAgo: 5);
final _helper = _job('j3', 'Helper', 3, 15000, daysAgo: 7);

void _setUp(Map<String, dynamic> page, {MyPlanModel plan = const MyPlanModel(paymentEnabled: true, trialAvailable: true)}) {
  Get.reset();
  PlanGate.debugPlan = plan;
  ApiService.init();
  ApiService.dio.httpClientAdapter = _Adapter({'success': true, 'data': page});
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => initTestStorage('a3_jobs'));
  tearDown(() {
    PlanGate.debugPlan = null;
    Get.reset();
  });

  test('MyJobsPage parse never throws over variants', () {
    for (final v in jsonVariants(_page([_cook], max: 1))) {
      expect(() => MyJobsPage.fromJson(v), returnsNormally);
    }
    for (final v in jsonVariants(_cook)) {
      expect(() => MyJobModel.fromJson(v), returnsNormally);
    }
    final p = MyJobsPage.fromJson(_page([_cook, _house, _helper], max: 1));
    expect(p.overCap, isTrue);
    expect(p.blockMessage, 'Your plan allows 1 active job. Close one or upgrade.');
    expect(MyJobsPage.fromJson(_page([_cook], max: 4, status: 'PendingReview')).blockMessage, 'Stay must be live first');
    expect(MyJobsPage.fromJson(_page([_cook, _house, _helper, _cook], max: 4, payment: false)).blockMessage,
        'You can have up to 4 active jobs. Close one to post another.');
  });

  testWidgets('o_st_20_freeAtCap_bannerSeePlusAndGreyPost', (t) async {
    _setUp(_page([_cook], max: 1));
    await pumpPhone(t, const StayJobsTab());
    await _settle(t);
    expect(find.text('My Jobs'), findsOneWidget);
    expect(find.text('1 of 1 active'), findsOneWidget);
    expect(find.text('Your plan allows 1 active job. Close one or upgrade.'), findsOneWidget);
    expect(find.text('See Plus'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Cook'), findsOneWidget);
    expect(find.text('2+ years'), findsOneWidget);
    expect(find.text('Food and stay given'), findsOneWidget);
    expect(find.text('Applicants call or WhatsApp you.'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Post a Job'), findsOneWidget);
  });

  testWidgets('o_st_20_paymentOff_cap4_noBannerNoSeePlusNoUpgradeWord', (t) async {
    _setUp(_page([_cook], max: 4, payment: false), plan: OwnerPlans.paymentOff);
    await pumpPhone(t, const StayJobsTab());
    await _settle(t);
    expect(find.text('1 of 4 active'), findsOneWidget);
    expect(find.text('See Plus'), findsNothing);
    expect(find.textContaining('pgrade'), findsNothing);
    expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
  });

  testWidgets('o_st_21_plus3of4_noBannerPostOpen and experience chips', (t) async {
    _setUp(_page([_cook, _house, _helper], max: 4, canUpgrade: false), plan: OwnerPlans.plus);
    await pumpPhone(t, const StayJobsTab(), size: const Size(392, 1300));
    await _settle(t);
    expect(find.text('3 of 4 active'), findsOneWidget);
    expect(find.text('Fresher'), findsOneWidget);
    expect(find.text('3+ years'), findsOneWidget);
    expect(find.text('See Plus'), findsNothing);
  });

  testWidgets('o_st_69_c_overCapBannerNumbersLive', (t) async {
    _setUp(_page([_cook, _house, _helper], max: 1));
    await pumpPhone(t, const StayJobsTab());
    await _settle(t);
    expect(find.text('3 active · Free allows 1'), findsOneWidget);
    expect(find.text('3 active jobs. Free allows 1. Close 2 to post a new one.'), findsOneWidget);
  });

  testWidgets('o_st_69_b_closeDialogTextAndKeep', (t) async {
    _setUp(_page([_cook], max: 1));
    await pumpPhone(t, const StayJobsTab());
    await _settle(t);
    await t.tap(find.text('Close'));
    await _settle(t);
    expect(find.text('Close this job?'), findsOneWidget);
    expect(find.text('A closed job cannot be opened again. It frees a slot for a new post.'), findsOneWidget);
    expect(find.text('Close job'), findsOneWidget);
    await t.tap(find.text('Keep'));
    await _settle(t);
    expect(find.text('Close this job?'), findsNothing);
  });

  for (final rows in [0, 1, 4]) {
    testOwnerSizes(
      'jobs tab $rows rows',
      () => const StayJobsTab(),
      setUpEach: () => _setUp(_page([for (var i = 0; i < rows; i++) _job('j$i', 'Housekeeping helper $i', i, 99000)], max: 1)),
      arrange: _settle,
    );
  }

  group('renders', () {
    Future<void> render(WidgetTester t, String id, Map<String, dynamic> page, {String? part, MyPlanModel plan = const MyPlanModel(paymentEnabled: true, trialAvailable: true), bool closeDialog = false}) async {
      _setUp(page, plan: plan);
      await renderOwnerFrame(t, id, const StayJobsTab(), part: part, arrange: (t) async {
        await _settle(t);
        if (closeDialog) {
          await t.tap(find.text('Close').first);
          await _settle(t);
        }
      });
    }

    testWidgets('render o_st_20', (t) => render(t, 'o_st_20', _page([_cook], max: 1)));
    testWidgets('render o_st_21', (t) => render(t, 'o_st_21', _page([_cook, _house, _helper], max: 4, canUpgrade: false), plan: OwnerPlans.plus));
    testWidgets('render o_st_69_b', (t) => render(t, 'o_st_69', _page([_cook], max: 1), part: 'B', closeDialog: true));
    testWidgets('render o_st_69_c', (t) => render(t, 'o_st_69', _page([_cook, _job('j2', 'Housekeeping', 0, 11000, daysAgo: 7, food: false), _helper], max: 1), part: 'C'));
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}
