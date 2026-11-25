import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/stay_owner/home/stay_owner_home_screen.dart';
import 'package:bakhli/features/stay_owner/stay_owner_deps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../core/stay_fixtures.dart';

void main() {
  setUpAll(() => initTestStorage('stay_home_numbers_tap'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    StayOwnerDeps.debugReset();
    OwnerApi.debugReset();
    resetOwnerTestState();
  });

  for (final (label, bucket) in [('New enquiries', 'New'), ('Offers waiting', 'Offered'), ('Confirmed', 'Confirmed')]) {
    testWidgets('home number "$label" opens the $bucket box', (t) async {
      final h = StayHarness.setUp(homeJson());
      await pumpPhone(t, const StayOwnerHomeScreen());
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      await t.ensureVisible(find.text(label).last);
      await t.tap(find.text(label).last);
      await t.pump();
      expect(h.auth.tabIndex.value, AppTabs.centre);
      expect(h.auth.tabIntent.value?.args['bucket'], bucket);
    });
  }
}
