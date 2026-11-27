import 'dart:io';

import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/utils/account_delete_message.dart';
import 'package:bakhli/widgets/account_blockers_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

// Q20: an auto-renewing subscription blocks deletion with one clear step (all roles).
void main() {
  final block = AccountDeleteBlock.fromJson({
    'code': 'ActiveSubscription',
    'message': 'You have an active subscription. Cancel it in Google Play first, then delete your account.',
    'action': 'ManagePlay',
    'args': {'manageUrl': 'https://play.google.com/store/account/subscriptions?sku=x&package=y'},
  })!;

  test('the block row: title, sub, Manage in Google Play button', () {
    expect(AccountBlockerActions.titleOf(block), AccountBlockerStrings.cancelFirst);
    expect(AccountBlockerActions.subOf(block), AccountBlockerStrings.cancelSub);
    expect(AccountBlockerActions.buttonOf(block), AccountBlockerStrings.manageInPlay);
    expect(block.args['manageUrl'], startsWith('https://play.google.com/'));
    expect(AccountDeleteMessage.lineOf(block), contains('Cancel it in Google Play first'));
  });

  test('a failed fresh check adds the try-again line', () {
    final stale = AccountDeleteBlock.fromJson({
      'code': 'ActiveSubscription',
      'message': 'You have an active subscription. ${AccountBlockerStrings.justCancelled}',
      'action': 'ManagePlay',
    })!;
    expect(AccountBlockerActions.subOf(stale), contains(AccountBlockerStrings.justCancelled));
  });

  test('the sheet opens Google Play, re-checks once on return and offers support', () {
    final src = File('lib/widgets/account_blockers_sheet.dart').readAsStringSync();
    expect(src, contains('openManageSubscription()'));
    expect(src, contains('AppLifecycleState.resumed && _recheck'));
    expect(src, contains('refreshPlan(force: true)'));
    expect(src, contains('ProfileActions.contactSupport'));
    expect(src, isNot(contains("'/account'")), reason: 'returning from Play never deletes by itself');
  });

  test('the confirm dialog says the paid time is lost for a cancelled plan that still runs', () {
    PlaySubInfo play({required bool renew, String state = 'SUBSCRIPTION_STATE_CANCELED'}) => PlaySubInfo.fromJson({
          'state': state,
          'autoRenewEnabled': renew,
          'expiryAt': '2026-12-20T00:00:00Z',
          'productId': 'stay_plus',
        });
    final src = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(src, contains('Your plan ends now. The paid time left is lost.'));
    expect(src, contains('static bool paidTimeLeft(MyPlanModel plan, DateTime now)'));
    expect(play(renew: false).autoRenewEnabled, isFalse);
    expect(play(renew: true, state: 'SUBSCRIPTION_STATE_ACTIVE').renewsAutomatically, isTrue);
  });
}
