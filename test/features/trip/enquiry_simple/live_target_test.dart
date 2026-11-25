import 'package:bakhli/config/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trip-plan with open myEnquiries opens My enquiries even with a row', () {
    final t = AppRoutes.liveTarget(AppRoutes.tripPlan, {'tripId': 't1', 'row': 'r1', 'open': 'myEnquiries', 'enquiryId': 'e1', 'bucket': 'offers'})!;
    expect(t.route, AppRoutes.myEnquiries);
    expect(t.args, {'enquiryId': 'e1', 'bucket': 'offers'});
  });

  test('my-trips with open myEnquiries opens My enquiries', () {
    final t = AppRoutes.liveTarget(AppRoutes.myTrips, {'open': 'myEnquiries', 'enquiryId': 'e2', 'similar': true})!;
    expect(t.route, AppRoutes.myEnquiries);
    expect(t.args, {'enquiryId': 'e2', 'similar': true});
  });

  test('trip-plan with a row and no open still goes to the overview', () {
    final t = AppRoutes.liveTarget(AppRoutes.tripPlan, {'tripId': 't1', 'row': 'r1'})!;
    expect(t.route, AppRoutes.tripOverview);
  });
}
