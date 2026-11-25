import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/widgets/tab_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<void> _pump(WidgetTester t) =>
    t.pumpWidget(const GetMaterialApp(home: Scaffold(body: Center(child: TabHeaderIcons()))));

void main() {
  tearDown(Get.reset);

  testWidgets('seeker shell shows Enquiries beside Notifications and Chats', (t) async {
    Get.put<AuthController>(_Auth()).shellKind.value = ShellKind.seeker;
    await _pump(t);
    expect(find.bySemanticsLabel('Enquiries'), findsOneWidget);
    expect(find.bySemanticsLabel('Chats'), findsOneWidget);
  });

  testWidgets('owner shell keeps two icons', (t) async {
    Get.put<AuthController>(_Auth()).shellKind.value = ShellKind.stayOwner;
    await _pump(t);
    expect(find.bySemanticsLabel('Enquiries'), findsNothing);
    expect(find.bySemanticsLabel('Chats'), findsOneWidget);
  });
}
