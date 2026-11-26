import 'package:bakhli/features/social/a/onboarding/onboarding_controller.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_steps.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Drives the 3-step OnboardingScreen to the Finish button: name typed, the rest set on the screen's controller.
abstract final class OnboardingWalk {
  static const Key nameKey = ValueKey('ob_name');

  static OnboardingController controllerOf(WidgetTester t) => t.widget<OnboardingStepYou>(find.byType(OnboardingStepYou)).c;

  static Future<void> _pump(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  static Future<void> _next(WidgetTester t) async {
    await t.tap(find.byKey(OnboardingBottom.buttonKey), warnIfMissed: false);
    await _pump(t);
  }

  static Future<void> toFinish(WidgetTester t, {String? name}) async {
    final c = controllerOf(t);
    if (name != null) await t.enterText(find.byKey(nameKey), name);
    c.gender.value = SocialStringsA.male;
    c.birthMonth.value = 1;
    c.birthYear.value = DateTime.now().year - ProfileRules.adultYears;
    await _pump(t);
    await _next(t);
    c.interests.assignAll(const ['Mountains', 'Treks', 'Food']);
    c.skills.assignAll(const ['Driver']);
    c.places.assignAll(const ['Rishikesh']);
    await _pump(t);
    await _next(t);
    c.about.value = 'Weekend trekker. Happy to share a cab.';
    await _pump(t);
  }

  static Finder get finish => find.byKey(OnboardingBottom.buttonKey);
}
