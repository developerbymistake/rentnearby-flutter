import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/design/design.dart';

Widget _page(String name, {String? next}) => Scaffold(
      body: ListView(children: [
        for (var i = 0; i < 40; i++)
          ListTile(key: ValueKey('$name$i'), title: Text('$name $i'), onTap: i == 0 && next != null ? () => Get.toNamed(next) : null),
      ]),
    );

void main() {
  testWidgets('TemplateTransition keeps pages hit-testable and scrollable', (t) async {
    final errors = <Object>[];
    FlutterError.onError = (d) => errors.add(d.exception);
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.theme,
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
      initialRoute: '/a',
      getPages: [
        GetPage(name: '/a', page: () => _page('A', next: '/b'), customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration),
        GetPage(name: '/b', page: () => _page('B'), customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration),
      ],
    ));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, 600));
    await t.pumpAndSettle();
    await t.tap(find.text('A 0'));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    Get.back();
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
  });
}
