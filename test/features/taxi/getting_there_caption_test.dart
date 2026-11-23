import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Change 16: the from-to route text sits inside the body card, no label-only header card above it.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  testWidgets('note shows the route caption above its text and keeps the action', (t) async {
    var taps = 0;
    await t.pumpWidget(host(GettingThereNote(
      tone: ListingTone.forest,
      art: ListingArt.bus,
      text: 'No ways yet',
      caption: 'From Haldwani to Kathgodam',
      actionLabel: 'See ways to go',
      onAction: () => taps++,
    )));
    final caption = find.text('From Haldwani to Kathgodam');
    expect(caption, findsOneWidget);
    expect(t.getTopLeft(caption).dy, lessThan(t.getTopLeft(find.text('No ways yet')).dy));
    await t.tap(find.text('See ways to go'));
    expect(taps, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('note without a caption draws no extra line', (t) async {
    await t.pumpWidget(host(GettingThereNote(tone: ListingTone.forest, art: ListingArt.bus, text: 'No ways yet')));
    expect(find.byType(Text), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });
}
