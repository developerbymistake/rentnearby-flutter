import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/stay_owner/enquiries_tab/widgets/enquiry_card_parts.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/enquiries/my_enquiries_controller.dart';
import 'package:bakhli/features/trip/enquiries/my_enquiries_screen.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/trip_strings_enquiry_simple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../social/c/social_c_test_kit.dart';

class _Repo extends TripEnquiryRepository {
  final calls = <String>[];

  @override
  Future<MyEnquiryPage> mine({required String bucket, String? cursor, bool counts = true, int pageSize = 20}) async {
    calls.add(bucket);
    return MyEnquiryPage.fromJson({
      'items': const [],
      'hasMore': false,
      'nextCursor': null,
      'counts': {'waiting': 2, 'offers': 1, 'booked': 3, 'past': 4},
    });
  }
}

void main() {
  tearDown(Get.reset);

  for (final w in socialWidths) {
    for (final s in socialScales) {
      testWidgets('My enquiries uses the Chats segmented tabs with counts (${w.toInt()} x$s)', (t) async {
        final repo = _Repo();
        final c = Get.put(MyEnquiriesController(repo: repo));
        await pumpSocial(t, const MyEnquiriesScreen(), width: w, scale: s);
        expect(find.byType(BucketPill), findsNothing);
        final tabs = find.byKey(const ValueKey('my_enquiries_tabs'));
        expect(tabs, findsOneWidget);
        final seg = t.widget<SegmentTabs>(tabs);
        expect(seg.labels, [TripStringsEnq.boxWaiting, TripStringsEnq.boxOffers, TripStringsEnq.boxBooked]);
        expect(seg.selected, 0);
        expect(seg.counts, {0: 2, 1: 1, 2: 3});
        for (final n in ['2', '1', '3']) {
          expect(find.descendant(of: tabs, matching: find.text(n)), findsOneWidget);
        }
        await t.tap(find.descendant(of: tabs, matching: find.text(TripStringsEnq.boxOffers)));
        await t.pump(const Duration(milliseconds: 300));
        expect(c.bucket.value, MyEnquiryBucket.offers);
        expect(repo.calls.last, MyEnquiryBucket.offers);
        expect(t.widget<SegmentTabs>(tabs).selected, 1);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  testWidgets('Past enquiries keeps its link and no tab is selected there', (t) async {
    final repo = _Repo();
    final c = Get.put(MyEnquiriesController(repo: repo));
    await pumpSocial(t, const MyEnquiriesScreen());
    await t.tap(find.textContaining(TripStringsEnq.pastEnquiries));
    await t.pump(const Duration(milliseconds: 300));
    expect(c.bucket.value, MyEnquiryBucket.past);
    expect(t.widget<SegmentTabs>(find.byKey(const ValueKey('my_enquiries_tabs'))).selected, -1);
    await disposeSocial(t);
  });
}
