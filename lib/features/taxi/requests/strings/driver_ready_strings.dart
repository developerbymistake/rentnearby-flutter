import '../../../../widgets/ring/ready_check_row.dart';

class DriverReadyStrings {
  static const String title = 'Get ready for requests';
  static const String subtitle = 'Four quick checks so your phone rings';
  static const String missedLine = 'You missed 3 requests. Run a test ring to get requests again.';

  static const String notificationsTitle = RingReadyStrings.notificationsTitle;
  static const String notificationsDone = RingReadyStrings.notificationsDone;
  static const String notificationsFix = 'Turn them on so requests can reach you';

  static const String ringTitle = RingReadyStrings.ringTitle;
  static const String ringDone = RingReadyStrings.ringDone;
  static const String ringFix = 'Un-mute the Taxi requests sound';

  static const String batteryTitle = RingReadyStrings.batteryTitle;
  static const String batteryDone = RingReadyStrings.batteryDone;
  static const String batteryFix = RingReadyStrings.batteryFix;

  static const String testTitle = RingReadyStrings.testTitle;
  static const String testDone = RingReadyStrings.testDone;
  static const String testFix = 'Did your phone ring? Run a test to see';

  static const String done = RingReadyStrings.done;
  static const String fix = RingReadyStrings.fix;
  static const String openSettings = RingReadyStrings.openSettings;
  static const String runTest = RingReadyStrings.runTest;
  static const String runTestAgain = RingReadyStrings.runTestAgain;
  static const String running = RingReadyStrings.running;
  static const String testShown = 'Your phone rang.';
  static const String testNotShown = 'We did not see the ring.';
  static const String testFailed = RingReadyStrings.testFailed;
  static const String testNotSaved = 'Your phone rang, but we could not save it. Test again.';

  static const String probeFailedTitle = RingReadyStrings.probeFailedTitle;
  static const String probeFailedBody = RingReadyStrings.probeFailedBody;
  static const String retry = 'Try again';

  static const String stripTitle = 'Get ready for requests';
  static const String stripBody = 'Your phone may not ring for new requests.';
  static const String stripMissedBody = 'You missed requests. Run a test ring.';
  static const String stripAction = 'Check now';

  static const Map<String, String> batteryByMaker = {
    'xiaomi': 'On Xiaomi, set Battery saver to No restrictions for this app.',
    'oneplus': 'On OnePlus, allow Background activity for this app.',
    'samsung': 'On Samsung, set Battery to Unrestricted for this app.',
    'oppo': 'On Oppo, allow Auto launch and Background activity for this app.',
    'vivo': 'On Vivo, allow High background power use for this app.',
    'realme': 'On realme, allow Auto launch and Background activity for this app.',
  };

  static String? batteryMakerLine(String manufacturer) => batteryByMaker[manufacturer.trim().toLowerCase()];
}
