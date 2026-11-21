import 'package:bakhli/features/owner_core/sheets/sheet_disposables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _disposed(ChangeNotifier n) {
  try {
    n.addListener(() {});
    return false;
  } on FlutterError {
    return true;
  }
}

void main() {
  testWidgets('controllers live through the exit animation and are disposed when the sheet route is gone', (t) async {
    final text = TextEditingController(text: '1800');
    late BuildContext root;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      root = c;
      return const SizedBox.expand();
    })));
    showModalBottomSheet<void>(
      context: root,
      builder: (_) => SheetDisposables(notifiers: [text], child: Material(child: TextField(controller: text))),
    );
    await t.pumpAndSettle();
    Navigator.of(root).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(t.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget, reason: 'still animating out');
    expect(text.text, '1800');
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(_disposed(text), isTrue);
  });
}
