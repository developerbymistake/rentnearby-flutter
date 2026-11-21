abstract final class StayGateStringsWork {
  static String jobsCap(int max) => max == 1 ? 'Your plan allows 1 active job. Close one or upgrade.' : 'Your plan allows $max active jobs. Close one or upgrade.';
  static const quietWeek = 'Quiet week? Plus puts your stay first in trip plans.';
  static String overCap(int active, int max) =>
      '$active active jobs. Free allows $max. Close ${active - max} to post a new one.';
  static String overCapHeader(int active, int max) => '$active active · Free allows $max';
  static const reminderLocked = 'Plus sends it at 8:00 am';
}
