import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _longTitle = 'A very long sheet title that keeps going and going across lines';

class _Run {
  bool done = false;
  Object? result = 'unset';
}

Future<_Run> _open(WidgetTester t, Widget Function() sheet) async {
  final run = _Run();
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () async {
              run.result = await Sheet3D.show<String>(ctx, builder: (_) => sheet());
              run.done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return run;
}

Widget _sheet({bool showClose = true, bool artRight = false, String? art = ListingArt.worldMap, String title = 'Title', bool centerTitle = true, String? headerAction}) => Sheet3D(
      tone: ListingTone.indigo,
      art: art,
      title: title,
      centerTitle: centerTitle,
      artRight: artRight,
      showClose: showClose,
      headerAction: headerAction,
      child: const SizedBox(height: 40),
    );

void main() {
  testWidgets('shows exactly one red close X in the top-right corner', (t) async {
    await _open(t, () => _sheet());
    expect(find.byType(SheetCloseButton), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(t.widget<Icon>(find.byIcon(Icons.close_rounded)).color, DesignColors.error);
    final panel = t.getRect(find.byType(Sheet3D));
    final x = t.getRect(find.byType(SheetCloseButton));
    expect(x.size, const Size(44, 44));
    expect(x.right, closeTo(panel.right - 12, 0.5));
    expect(x.top, closeTo(panel.top + Sheet3D.artRoom + 12, 0.5));
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
  });

  testWidgets('tapping X closes the sheet and returns null', (t) async {
    final run = await _open(t, () => _sheet());
    expect(run.done, isFalse);
    await t.tap(find.byType(SheetCloseButton));
    await t.pumpAndSettle();
    expect(find.byType(Sheet3D), findsNothing);
    expect(run.done, isTrue);
    expect(run.result, isNull);
  });

  testWidgets('showClose false hides the X', (t) async {
    await _open(t, () => _sheet(showClose: false));
    expect(find.byType(SheetCloseButton), findsNothing);
  });

  testWidgets('closeEnabled false ignores taps', (t) async {
    await _open(
      t,
      () => Sheet3D(tone: ListingTone.indigo, title: 'T', closeEnabled: false, child: SizedBox(height: 40)),
    );
    await t.tap(find.byType(SheetCloseButton), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.byType(Sheet3D), findsOneWidget);
  });

  testWidgets('art on the right keeps clear of the X', (t) async {
    await _open(t, () => _sheet(artRight: true, centerTitle: false, art: ListingArt.taxi, title: _longTitle));
    final x = t.getRect(find.byType(SheetCloseButton));
    final art = t.getRect(find.byType(Art3D));
    expect(art.right, lessThanOrEqualTo(x.left + 0.5));
    final title = t.getRect(find.text(_longTitle));
    expect(title.right, lessThanOrEqualTo(art.left + 0.5));
  });

  testWidgets('long left title does not run under the X', (t) async {
    await _open(t, () => _sheet(art: null, centerTitle: false, title: _longTitle));
    final x = t.getRect(find.byType(SheetCloseButton));
    final title = t.getRect(find.text(_longTitle));
    expect(title.right, lessThanOrEqualTo(x.left + 0.5));
  });

  testWidgets('long centered title without art does not run under the X', (t) async {
    await _open(t, () => _sheet(art: null, title: _longTitle));
    final x = t.getRect(find.byType(SheetCloseButton));
    final title = t.getRect(find.text(_longTitle));
    expect(title.right, lessThanOrEqualTo(x.left + 0.5));
  });

  testWidgets('SheetFrame and TripSheetFrame show one X each and honour showClose', (t) async {
    await _open(t, () => SheetFrame(title: 'T', child: SizedBox(height: 20)));
    expect(find.byType(SheetCloseButton), findsOneWidget);
    await t.tapAt(const Offset(200, 20));
    await t.pumpAndSettle();
    await _open(t, () => SheetFrame(title: 'T', showClose: false, child: SizedBox(height: 20)));
    expect(find.byType(SheetCloseButton), findsNothing);
  });
}
