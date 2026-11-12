class TripStringsShortlist {
  static const shortlist = 'Shortlist';
  static const shortlisted = 'Shortlisted';
  static const done = 'Done';
  static const full = 'Your shortlist is full. Remove one to add another.';
  static const noReply = 'No reply';
  static const reviewTitle = 'Great picks';
  static const yesSendAll = 'Yes, send to all';
  static const notNow = 'Not now';
  static const sending = 'Sending';
  static const taxiFallback = 'Taxi';

  static String barCount(int n, int max) => '$n of $max shortlisted';

  static String reviewBody(int n, {required bool taxi}) =>
      'Send an enquiry to all your shortlisted ${taxi ? 'taxis' : 'stays'} together?';

  static String sentTitle(int n) => 'Enquiry sent';

  static String sentBody(int n, {bool taxi = false}) {
    final who = taxi ? 'driver' : 'host';
    return 'We told $n ${n == 1 ? who : '${who}s'}. You will see replies here.';
  }

  static String failedNote(int n, {required bool taxi}) {
    final who = taxi ? 'driver' : 'host';
    return n == 1 ? 'One $who could not be reached.' : '$n ${who}s could not be reached.';
  }

  static String remove(String name) => 'Remove $name';
  static const leadLimit = 'You have reached the daily limit for taxi enquiries on this trip. Try again tomorrow.';
  static const sendFailedNote = 'Could not send. Please try again.';

  static String reasonLine(String status, {required bool taxi}) {
    final who = taxi ? 'driver' : 'host';
    return switch (status) {
      'NotAvailable' => taxi ? 'This taxi is not available any more' : 'This stay is not available any more',
      'Blocked' => 'This $who cannot be reached',
      'LimitReached' => 'You already have 3 open enquiries for these dates',
      'OpenInAnotherTrip' => 'You already asked this $who for these dates in another trip',
      _ => 'Could not reach this $who. Try again.',
    };
  }

  static String startsAt(String place) => 'Starts at $place';

  static const sent = 'Sent';
  static const alreadyOpen = 'Already sent earlier';
  static const replayed = 'Already sent';
  static const notAvailable = 'Not available';
  static const blocked = "Can't be reached";
  static const limitReached = 'Limit reached';
  static const openInAnotherTrip = 'Asked in another trip';
  static const failed = 'Try again';

  static String statusLabel(String status) => switch (status) {
        'Sent' => sent,
        'AlreadyOpen' => alreadyOpen,
        'Replayed' => replayed,
        'NotAvailable' => notAvailable,
        'Blocked' => blocked,
        'LimitReached' => limitReached,
        'OpenInAnotherTrip' => openInAnotherTrip,
        _ => failed,
      };

  static bool isOk(String status) => status == 'Sent' || status == 'AlreadyOpen' || status == 'Replayed';
}
