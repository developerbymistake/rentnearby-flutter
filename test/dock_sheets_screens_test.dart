import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/guest/stay_bottom_sheet.dart';
import 'package:bakhli/features/stay/guest/stay_guest_controller.dart';
import 'package:bakhli/features/stay/guest/stay_nearby_list_sheet.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/widgets/nearest_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _bar = Key('bar');

Future<void> _open(WidgetTester t, void Function(BuildContext) open) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final nested = Navigator(
    onGenerateRoute: (_) => MaterialPageRoute(
      builder: (_) => Builder(builder: (ctx) => Center(child: ElevatedButton(onPressed: () => open(ctx), child: const Text('open')))),
    ),
  );
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      extendBody: true,
      body: DockInsetScope(child: nested),
      bottomNavigationBar: const SizedBox(key: _bar, height: 80, child: ColoredBox(color: Colors.green)),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

double _barTop(WidgetTester t) => t.getTopLeft(find.byKey(_bar)).dy;

void main() {
  tearDown(Get.reset);

  testWidgets('showDockSheet edit-name style Save and Cancel sit above the dock', (t) async {
    await _open(t, (c) => showDockSheet<void>(
          c,
          backgroundColor: Colors.transparent,
          builder: (_) => const Material(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: 120),
              SizedBox(height: 48, child: Text('Save')),
              SizedBox(height: 48, child: Text('Cancel')),
            ]),
          ),
        ));
    expect(t.getBottomLeft(find.text('Cancel')).dy, lessThanOrEqualTo(_barTop(t)));
    expect(t.getBottomLeft(find.text('Save')).dy, lessThanOrEqualTo(_barTop(t)));
  });

  testWidgets('nearest confirm buttons sit above the dock', (t) async {
    await _open(t, (c) => NearestConfirmSheet.show(c, itemLabel: 'stay', onConfirm: () {}));
    expect(t.getBottomLeft(find.text('Not Now')).dy, lessThanOrEqualTo(_barTop(t)));
    expect(find.text('Not Now').hitTestable(), findsOneWidget);
    await t.tap(find.text('Not Now'));
    await t.pumpAndSettle();
    expect(find.text('Not Now'), findsNothing);
    expect(find.byKey(_bar), findsOneWidget);
  });

  testWidgets('stay pin sheet sits above the dock', (t) async {
    final stay = StayNearbyModel(id: 's', name: 'Deodar Cottage', latitude: 29.3, longitude: 79.5, minPricePerNight: 3600, distanceKm: 1, isActive: true);
    await _open(t, (c) => StayBottomSheet.show(c, stay));
    final sheet = find.byType(StayBottomSheet);
    expect(sheet, findsOneWidget);
    expect(t.getBottomLeft(sheet).dy, lessThanOrEqualTo(_barTop(t) + 0.5));
  });

  testWidgets('view list sheet sits above the dock', (t) async {
    final guest = Get.put(StayGuestController());
    await _open(t, (c) => StayNearbyListSheet.show(c, guest));
    final sheet = find.byType(StayNearbyListSheet);
    expect(sheet, findsOneWidget);
    expect(t.getBottomLeft(sheet).dy, lessThanOrEqualTo(_barTop(t) + 0.5));
  });
}
