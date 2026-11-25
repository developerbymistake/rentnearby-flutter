import '../../../design/design.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class StayGateStringsWork {
  static String jobsCap(int max) => max == 1 ? 'Your plan allows 1 active job. Close one or upgrade.' : 'Your plan allows $max active jobs. Close one or upgrade.';
  static const quietWeek = 'Quiet week? Plus puts your stay first in trip plans.';
  static const reminderLocked = 'Plus sends it at 8:00 am';

  static String activeJobs(int n) => n == 1 ? '1 active job' : '$n active jobs';
  static String jobTitle(int free) => '${activeJobs(free)} on Free';
  static String jobBody(int plus) => 'Get Plus to post up to $plus.';
  static String jobInactive(int free) => 'Inactive: the Free plan allows ${activeJobs(free)}.';
  static const experienceLabel = 'EXPERIENCE';
  static const benefitsLabel = 'BENEFITS';

  static GateSpec jobGate({int? free}) {
    free ??= PlanGate.limit(PlanKey.jobsPosts);
    final plus = PlanKeys.plusSeed[PlanKey.jobsPosts] ?? free;
    return GateSpec(
      id: 'G7',
      title: jobTitle(free),
      body: jobBody(plus),
      taxi: false,
      art: ListingArt.briefcase,
      rows: [GateRow(label: OwnerSharedStrings.free, value: activeJobs(free)), GateRow(label: OwnerSharedStrings.plus, value: activeJobs(plus), highlight: true)],
    );
  }
}
