import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_easy_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('T4 every part own or skipped: 3 of 3 handled, nothing asked', () async {
    final c = TripPlanController();
    c.plan.value = journeyPlan([2, 1]);
    expect(c.easyProgress.total, 3);
    expect(c.easyProgress.done, 1);
    expect(c.easyProgress.percent, 33);

    expect(await c.markOwn(const TripEasyRowKey(TripEasyRowKind.stay, 1)), isA<TripMarked>());
    expect(await c.markOwn(const TripEasyRowKey(TripEasyRowKind.stay, 2)), isA<TripMarked>());
    c.skipRow(const TripEasyRowKey(TripEasyRowKind.taxi));

    final rows = c.easyRows;
    expect(rows.where((r) => r.state == TripRowState.skipped), hasLength(1));
    final progress = c.easyProgress;
    expect(progress.total, 3);
    expect(progress.done, 3);
    expect(progress.percent, 100);
    expect(TripEasyRules.allResolved(rows), isTrue);
    expect(TripEasyRules.hasOwnMark(c.plan.value!), isTrue);
    expect(c.enquiryList, isEmpty);

    c.undoMark(const TripEasyRowKey(TripEasyRowKind.stay, 2));
    expect(c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.stay, 2))!.state, TripRowState.todo);
    expect(c.easyProgress.done, 3);

    c.clearSkip(const TripEasyRowKey(TripEasyRowKind.taxi));
    expect(c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.taxi))!.state, TripRowState.todo);
    expect(c.easyProgress.done, 2);
    c.clearSkip(const TripEasyRowKey(TripEasyRowKind.stay, 1));
    expect(c.easyRowOf(const TripEasyRowKey(TripEasyRowKind.stay, 1))!.state, TripRowState.own);
  });
}
