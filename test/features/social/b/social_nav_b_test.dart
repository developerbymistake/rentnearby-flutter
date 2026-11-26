import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/b/social_nav_b.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FeedStub extends StatefulWidget {
  const _FeedStub();

  @override
  State<_FeedStub> createState() => _FeedStubState();
}

class _FeedStubState extends State<_FeedStub> {
  @override
  void initState() {
    super.initState();
    SocialNavB.feedOpened();
  }

  @override
  void dispose() {
    SocialNavB.feedClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Text('FEED ${(Get.arguments as Map?)?['posted']}'));
}

Future<void> _app(WidgetTester t) async {
  await t.pumpWidget(GetMaterialApp(
    initialRoute: '/home',
    getPages: [
      GetPage(name: '/home', page: () => const Scaffold(body: Text('HOME'))),
      GetPage(name: AppRoutes.travelBuddies, page: () => const _FeedStub()),
      GetPage(name: AppRoutes.postTrip, page: () => const Scaffold(body: Text('WIZARD'))),
      GetPage(name: AppRoutes.tripPost, page: () => const Scaffold(body: Text('POST'))),
    ],
  ));
  await t.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  testWidgets('posting from the feed goes back to that feed, not a second copy', (t) async {
    await _app(t);
    Get.toNamed(AppRoutes.travelBuddies);
    await t.pumpAndSettle();
    Get.toNamed(AppRoutes.tripPost);
    await t.pumpAndSettle();
    Get.toNamed(AppRoutes.postTrip);
    await t.pumpAndSettle();
    final before = SocialNavB.posted.value;
    SocialNavB.backToTravelBuddies(posted: true);
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.travelBuddies);
    expect(SocialNavB.posted.value, before + 1);
    Get.back();
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(SocialNavB.feedInStack, isFalse);
  });

  testWidgets('posting from a trip menu with no feed open replaces the wizard with the feed', (t) async {
    await _app(t);
    Get.toNamed(AppRoutes.postTrip);
    await t.pumpAndSettle();
    SocialNavB.backToTravelBuddies(posted: true);
    await t.pumpAndSettle();
    expect(find.text('FEED true'), findsOneWidget);
    Get.back();
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
