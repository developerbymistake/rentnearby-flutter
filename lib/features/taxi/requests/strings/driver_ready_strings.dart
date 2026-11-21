class DriverReadyStrings {
  static const String title = 'Get ready for requests';
  static const String subtitle = 'Four quick checks so your phone rings';
  static const String missedLine = 'You missed 3 requests. Run a test ring to get requests again.';

  static const String notificationsTitle = 'Notifications';
  static const String notificationsDone = 'Notifications are on';
  static const String notificationsFix = 'Turn them on so requests can reach you';

  static const String ringTitle = 'Ring sound';
  static const String ringDone = 'The ring is not muted';
  static const String ringFix = 'Un-mute the Taxi requests sound';

  static const String batteryTitle = 'Battery';
  static const String batteryDone = 'Battery is not limiting the app';
  static const String batteryFix = 'Let the app run in the background';

  static const String testTitle = 'Test ring';
  static const String testDone = 'Your phone rang';
  static const String testFix = 'Did your phone ring? Run a test to see';

  static const String done = 'Done';
  static const String fix = 'Fix';
  static const String openSettings = 'Open settings';
  static const String runTest = 'Run test ring';
  static const String runTestAgain = 'Test again';
  static const String running = 'Ringing your phone...';
  static const String testShown = 'Your phone rang.';
  static const String testNotShown = 'We did not see the ring.';
  static const String testFailed = 'Could not send the test ring.';
  static const String testNotSaved = 'Your phone rang, but we could not save it. Test again.';

  static const String probeFailedTitle = 'Could not check your phone';
  static const String probeFailedBody = 'Something went wrong while checking. Try again.';
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
