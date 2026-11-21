abstract final class PlanWords {
  static const title = 'Plans & Billing';
  static const yourPlan = 'Your plan';
  static const free = 'Free';
  static const plus = 'Plus';
  static const trial = 'Trial';
  static const active = 'Active';
  static const subscription = 'Subscription';
  static const noEndDate = 'No end date';
  static const freeForNow = 'Free for now';
  static const billedByPlay = 'Billed by Google Play';
  static const autoRenewOff = 'Auto-renew is off';
  static const autoRenewOffDot = 'Auto-renew is off.';
  static const paymentOnHold = 'Payment on hold';
  static const paymentIssue = 'Payment issue';
  static const updatePayment = 'Update your payment method to keep your plan.';
  static const plusKeepsWorking = 'Plus keeps working for now.';
  static const fixToContinue = 'Fix the payment in Google Play to continue.';
  static const fixFirst = 'Fix the payment in Google Play first.';
  static const subscriptionEnded = 'Subscription ended';
  static const thenRenews = 'Then it renews. Cancel anytime in Google Play.';
  static const manageInPlay = 'Manage in Google Play';
  static const fix = 'Fix';
  static const subscribeAgain = 'Subscribe again';
  static const continueWithPlus = 'Continue with Plus';
  static const currentPlan = 'Current plan';
  static const useSameAccount = 'Use the Google account you subscribed with.';
  static const whatYouGet = 'What you get';
  static const freeVsPlus = 'Free vs Plus';
  static const pickHowLong = 'Pick how long';
  static const autoRenews = 'Auto-renews. Cancel anytime in Google Play.';
  static const changeDuration = 'Change duration';
  static const nextRenewal = 'Takes effect at your next renewal';
  static const paidPlansComing = 'Paid plans are coming';
  static const thisWeek = 'This week';
  static const whatPlusDid = 'What Plus did for you';
  static const newTag = 'NEW';
  static const seePlus = 'See Plus';
  static const freePlan = 'Free plan';

  static const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static DateTime _local(DateTime d) => d.isUtc ? d.toLocal() : d;
  static String date(DateTime d) {
    final l = _local(d);
    return '${l.day} ${_m[l.month - 1]} ${l.year}';
  }

  static String dayMonth(DateTime d) {
    final l = _local(d);
    return '${l.day} ${_m[l.month - 1]}';
  }

  static String trialEndsOn(DateTime d) => 'Trial ends on ${date(d)}';
  static String renewsOn(DateTime d) => 'Renews on ${date(d)}';
  static String plusTill(DateTime d) => 'Plus till ${date(d)}';
  static String endedOn(DateTime d) => 'Ended on ${date(d)}';
  static String freeUntil(DateTime d) => 'Free until ${dayMonth(d)}';
  static String tryFree(int days) => 'Try free for $days days';
  static String cycle(int months) => months == 1 ? '1 month' : '$months months';
  static String planCycle(String plan, int months) => '$plan · ${cycle(months)}';
  static String of(int used, int limit) => '$used of $limit';

  static String upcoming(int days) => days < 28 ? '$days days' : '${(days / 30.5).round()} months';
  static String monthView(int monthsAhead) => monthsAhead <= 0 ? 'This month' : '+$monthsAhead months';
  static String turn(int weight) => weight <= 1 ? 'Normal' : '${weight}x';

  static String row(String label, String free, String plus) => '$label, Free $free, Plus $plus';
  static const included = 'included';
  static const notIncluded = 'not included';
}
