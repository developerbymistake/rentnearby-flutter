import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';
import '../../support/real_phone.dart';

class _Svc extends NotificationService {}

Future<void> _pumpApp(WidgetTester t) => pumpPhone(
      t,
      const Scaffold(body: Text('home')),
      pages: [
        GetPage(name: AppRoutes.myEnquiries, page: () => const Scaffold(body: Text('my enquiries'))),
        GetPage(name: AppRoutes.chatsList, page: () => const Scaffold(body: Text('chats'))),
      ],
    );

const _enquiryChat = {'conversationId': 'c1', 'enquiryId': 'e1'};

void main() {
  setUpAll(() async {
    await initTestStorage('enquiry_push_fallback_test');
    await loadRealFonts();
  });

  late FakeAuth auth;

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    auth = FakeAuth();
    Get.put<AuthController>(auth);
  });
  tearDown(() {
    Get.reset();
    ShellState.current.value = ShellKind.seeker;
  });

  testWidgets('seeker: an enquiry chat push opens My Enquiries', (t) async {
    auth.signIn(role: UserRoleKeys.seeker);
    await _pumpApp(t);
    _Svc().openActionRoute(AppRoutes.chatConversation, {..._enquiryChat});
    await t.pump(const Duration(milliseconds: 500));
    expect(Get.currentRoute, AppRoutes.myEnquiries);
    expect(Get.arguments, {'enquiryId': 'e1'});
  });

  testWidgets('stay owner in the seeker shell: an enquiry chat push opens the chat, never the gated My Enquiries', (t) async {
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Draft');
    expect(ShellState.isOwner, isFalse);
    expect(auth.canOpenRoute(AppRoutes.myEnquiries), isFalse);
    expect(auth.canOpenRoute(AppRoutes.chatConversation), isTrue);
    await _pumpApp(t);
    _Svc().openActionRoute(AppRoutes.chatConversation, {..._enquiryChat});
    await t.pump(const Duration(milliseconds: 500));
    expect(Get.currentRoute, AppRoutes.chatsList);
    expect(find.text('my enquiries'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
