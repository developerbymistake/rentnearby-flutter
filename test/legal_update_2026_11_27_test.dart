import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/screens/privacy_policy_screen.dart';
import 'package:bakhli/screens/terms_of_service_screen.dart';

const _date = 'Last updated: November 27, 2026';

Finder _text(String s) => find.textContaining(s, findRichText: true, skipOffstage: false);

void main() {
  testWidgets('privacy screen shows the new date and the traveller visibility text, no Seeker', (tester) async {
    final src = File('lib/screens/privacy_policy_screen.dart').readAsStringSync();
    expect(src, contains("'$_date'"));
    expect(src, isNot(contains('November 6, 2026')));
    expect(src, isNot(contains('Seeker')));
    expect(src, isNot(contains('from the app (Profile)')));
    expect(src, contains('If you use Bakhli as a Traveller, your profile, including your name, Bakhli ID, photo, gender, home city'));
    expect(src, contains('Traveller profile details — the details you add to your traveller profile'));
    expect(src, contains('You can delete your account from within the app, or on the web at the account deletion page.'));

    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    await tester.pump();
    expect(_text(_date), findsWidgets);
    expect(_text('If you use Bakhli as a Traveller'), findsWidgets);
    expect(_text('Seeker'), findsNothing);
  });

  testWidgets('terms screen shows the new date and the travellers section, no Seeker', (tester) async {
    final src = File('lib/screens/terms_of_service_screen.dart').readAsStringSync();
    expect(src, contains("'$_date'"));
    expect(src, isNot(contains('November 6, 2026')));
    expect(src, isNot(contains('Seeker')));
    expect(src, isNot(contains("'Stay Owners and Taxi Drivers may choose a paid plan")));
    expect(src, contains("_sb('Travellers, Public Trips and Meeting Other Users', 'Travellers can create a profile"));
    expect(src.indexOf("_sb('Enquiries, Bookings and Payments'"),
        lessThan(src.indexOf("_sb('Travellers, Public Trips and Meeting Other Users'")));
    expect(src.indexOf("_sb('Travellers, Public Trips and Meeting Other Users'"),
        lessThan(src.indexOf("_sb('Responsibility of Taxi Drivers and Stay Owners'")));
    expect(src, contains('Travellers, Stay Owners and Taxi Drivers may choose a paid plan with the features shown in the app.'));

    await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));
    await tester.pump();
    expect(_text(_date), findsWidgets);
    expect(_text('Travellers, Public Trips and Meeting Other Users'), findsWidgets);
    expect(_text('Bakhli does not check the identity, age, gender, background or conduct of any user'), findsWidgets);
    expect(_text('Seeker'), findsNothing);
  });
}
