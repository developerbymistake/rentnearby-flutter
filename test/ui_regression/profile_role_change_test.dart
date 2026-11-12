import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/models/role_model.dart';
import 'package:bakhli/screens/role_change_screen.dart';
import 'package:bakhli/design/extra/template_top_bar.dart';

class _FakeAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> refreshProfile() async {}
  @override
  Future<List<RoleModel>> fetchRoles() async => [
        RoleModel(key: 'SEEKER', name: 'Seeker', description: 'a', sortOrder: 1),
        RoleModel(key: 'STAY_OWNER', name: 'Stay Owner', description: 'b', sortOrder: 2),
        RoleModel(key: 'TAXI_DRIVER', name: 'Taxi Driver', description: 'c', sortOrder: 3),
      ];
}

void main() {
  setUp(() {
    Get.reset();
    Get.put<AuthController>(_FakeAuth());
  });

  testWidgets('role change: top bar is compact and body is tappable', (t) async {
    await t.pumpWidget(const MaterialApp(home: RoleChangeScreen()));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(TemplateTopBar)).height, lessThan(120));
    expect(find.text('Stay Owner').hitTestable(), findsWidgets);
    expect(find.text('Send request').hitTestable(), findsOneWidget);
  });

  testWidgets('TemplateTopBar in a Stack stays compact', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _Host(),
      ),
    ));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.getSize(find.byType(TemplateTopBar)).height, lessThan(120));
    expect(find.text('body').hitTestable(), findsOneWidget);
  });
}

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Center(child: Text('body')),
      TemplateTopBar(
        title: 'T',
        opacity: 1,
        onBack: () {},
        animation: _c,
        animationController: _c,
      ),
    ]);
  }
}
