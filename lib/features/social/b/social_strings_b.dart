import '../../buddy/shared/buddy_format.dart';
import '../shared/social_formats.dart';
import '../shared/social_models.dart';

abstract final class SocialStringsB {
  static const String travelBuddies = 'Travel buddies';
  static const String searchHint = 'Search trips, places…';
  static const String filters = 'Filters';
  static const String postYourTrip = 'Post your trip';
  static const String yourPost = 'Your post';
  static const String plusPill = 'Plus';
  static const String postToFindBuddiesLine = 'Opens Post your trip, filled from this trip';
  static const String noRequestsYet = 'No requests yet. They come to your bell.';
  static String requests(int n) => n == 1 ? '1 request' : '$n requests';
  static const String requestToJoin = 'Request to join';
  static const String requested = 'Requested';
  static const String cancelRequest = 'Cancel request';
  static const String notThisTime = 'Not this time';
  static const String full = 'Full';
  static const String openTrip = 'Open trip';
  static const String joinRequestsTitle = 'Join requests';
  static String liveTitle(String city) => 'Your $city trip is live';
  static const String liveBody = 'Travellers can see it and ask to join';
  static const String feedEmptyTitle = 'No trips to join yet';
  static const String feedEmptyBody = 'Post your trip and travellers can ask to join.';
  static String noMatch(String q) => 'No trips for “$q”';
  static const String noMatchFilters = 'No trips for these filters';
  static const String clearFilters = 'Clear filters';

  static String freeLine(SocialLimits l) =>
      'Free: ${_count(l.publicTrips.limit, 'public trip', 'public trips')}, ${_count(l.joinRequests.limit, 'join request', 'join requests')} a month';

  static String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  static String seatsOf(PublicTrip t) {
    if (t.isMine && t.seats > 0 && t.seats < SocialFormats.moreSeats && t.seatsLeft > 0) return '${t.seatsLeft} of ${t.seats} seats left';
    return SocialFormats.seatsLeft(t.seatsLeft, t.seats);
  }

  static String whenDays(PublicTrip t) => '${SocialFormats.when(t.when)} · ${SocialFormats.days(t.days)}';

  static String placeLine(SocialPerson owner, List<String> interests) =>
      [if ((owner.homeCity ?? '').isNotEmpty) owner.homeCity!, if (interests.isNotEmpty) interests.take(2).join(', ')].join(' · ');

  // Filter sheet
  static const String filtersKicker = 'FILTERS';
  static const String trips = 'Trips';
  static const String where = 'WHERE';
  static const String anywhere = 'Anywhere';
  static const String cityOrPlace = 'City or place';
  static const String popular = 'Popular';
  static const List<String> popularPlaces = ['Goa', 'Manali', 'Rishikesh', 'Udaipur'];
  static const String whoCanJoinCaps = 'WHO CAN JOIN';
  static const String anyone = 'Anyone';
  static const String women = 'Women';
  static const String men = 'Men';
  static const String nearMe = 'Near me';
  static const String nearMeLine = 'Only trips starting close to you';
  static const String showTrips = 'Show trips';
  static const String nearMeNoLocation = 'Turn on location to see trips near you.';

  // Spec 22: every poster picks Anyone / Men / Women; Women only is Plus.
  static const List<String> joinCodes = ['A', 'M', 'F'];
  static const List<String> joinLabels = [anyone, men, women];
  static const int womenIndex = 2;

  // In place of Request to join when the trip is for the other gender (spec 22).
  static String onlyFor(String joinGender) => switch (joinGender) {
        'F' => 'This trip is for women only',
        'M' => 'This trip is for men only',
        _ => '',
      };

  // Home rail
  static const String tripsToJoin = 'Trips to join';
  static const String seeAll = 'See all';
  static const String findBuddies = 'Find buddies';

  // Post entries (spec 23.6 + 23.7: the public-post entry never says 'buddies')
  static const String homePostEyebrow = 'Going somewhere?';
  static const String homePostTitle = postYourTrip;
  static const String homePostLine = 'Travellers can ask to join you.';
  static const String post = 'Post';
  static const String myTripsPostTitle = postYourTrip;
  static const String myTripsPostLine = 'Travellers can ask to join you';

  // Wizard
  static const String wizardTitle = postYourTrip;
  static const String draftSaved = 'Draft saved';
  static const String stepWhere = 'Where';
  static const String stepWhen = 'When';
  static const String stepAbout = 'About';
  static const String next = 'Next →';
  static const String back = 'Back';
  static const String close = 'Close';
  static const String whereTitle = 'Where are you headed?';
  static const String whereSub = 'Pick one city or more. We plan them as one trip.';
  static const String searchCity = 'Search a city';
  static String inState(String state) => 'In $state';
  static const String whereNote = 'Ready cities only. After the first city, only cities of the same state. The cover comes from the city.';
  static const String whereFromTrip = 'Cities come from your trip.';
  static String maxCities(int n) => 'Up to $n cities';
  static const String noCities = 'No ready cities match your search.';
  static const String citiesFailed = 'Could not load cities.';
  static String whenTitle(String city) => 'When are you off to $city?';
  static const String whenSub = 'An exact date, or roughly when.';
  static const String roughly = 'Roughly';
  static const String exactDate = 'Exact date';
  static const String withinTheNext = 'Within the next';
  static String monthsChip(int n) => n == 1 ? '1 month' : '$n months';
  static String withinSub(int max) => 'Up to $max months ahead';
  static const String whenAndHowLong = 'When and how long';
  static const String withinRowSub = 'Travellers see a window';
  static String windowNote(int months) => 'Your post shows “within ${monthsChip(months)}”, never a date.';
  static const String today = 'Today';
  static const String pickFromCalendar = 'Pick from calendar';
  static const String startDate = 'Start date';
  static const String howLong = 'How long?';
  static const String howLongSub = 'Up to 10 days, or 10+';
  static const String whoCanJoin = 'Who can join';
  static const String genderLockTitle = 'Women-only trips are a Plus feature.';
  static const String genderLockBody = 'Your post stays open to anyone for now.';
  static const String seePlus = 'See Plus';
  static const String seats = 'Seats';
  static const List<String> seatLabels = ['1', '2', '3', '4+'];
  static const List<int> seatValues = [1, 2, 3, SocialFormats.moreSeats];
  static const String aboutTitle = 'Tell travellers about it';
  static const String aboutSub = 'We started it from your answers. Make it yours.';
  static const String whatToWrite = 'What should I write?';
  static const String writeTipsTitle = 'What to write';
  static const String writeTipsBody = 'Tap a line to add it to your post.';
  static const List<String> writeTips = [
    'Where you start from and how you travel.',
    'What you like doing on a trip.',
    'How you plan to share costs.',
  ];
  static const String addToPost = 'Add to your post';
  static String aboutNote(SocialLimits? l) => l == null || l.isPlus
      ? 'Post trip creates the trip in My Trips, public. You plan places, days, stay and taxi as usual.'
      : 'Post trip creates the trip in My Trips, public. You plan places, days, stay and taxi as usual. Free: ${_count(l.publicTrips.limit, 'public trip', 'public trips')} at a time.';
  static const String postTrip = 'Post trip';
  static const String editAnswers = 'Edit answers';
  static String counter(int n, int max) => '$n/$max';
  static const String textRequired = 'Write a few words about the trip.';
  static const List<String> defaultPostChips = [
    'Budget trip',
    'Backpacking',
    'Happy to split a cab',
    'Staying in hostels',
    'First solo trip',
    'Into photography',
    'Up for treks',
  ];

  static String whenLower(String kind, int withinMonths, DateTime? date) {
    if (kind == 'exact' && date != null) return 'in ${SocialFormats.monthName(date.month)}';
    return withinMonths <= 1 ? 'within a month' : 'within $withinMonths months';
  }

  static String whenPhrase(String kind, int withinMonths, DateTime? date) {
    if (kind == 'exact' && date != null) return 'in ${SocialFormats.monthName(date.month)}';
    return withinMonths <= 1 ? 'in the next month' : 'in the next $withinMonths months';
  }

  static String whoLower(String joinGender) => switch (joinGender) {
        'M' => 'men only',
        'F' => 'women only',
        _ => 'open to anyone',
      };

  static String autoText({required String cities, required int days, required String when, required String joinGender}) =>
      'Heading to $cities for ${SocialFormats.days(days)} $when. Looking for a travel buddy, ${whoLower(joinGender)}.';

  static String chipLine(String chip) => chip.endsWith('.') ? chip : '$chip.';

  static String daysOption(int d) => d >= SocialFormats.moreDays ? '10+' : '$d';

  // Trip post page
  static const String tripPost = 'Trip post';
  static String byOwner(String shortName) => 'By $shortName';
  static const String factWhen = 'When';
  static const String factHowLong = 'How long';
  static const String factWho = 'Who can join';
  static const String factSeats = 'Seats';
  static String seatsFact(int left) => left <= 0 ? full : '$left left';
  static const String postGone = 'This trip is not available.';
  static const String reportTrip = 'Report this trip';
  static const String reportTripLine = 'Tell us what is wrong';
  static const String reportTripBody = 'We look at the trip and the person who posted it.';
  static const String reported = 'Thanks. We will look at it.';
  static String blockPerson(String shortName) => 'Block $shortName';
  static const String blockLine = 'They are not told';
  static const String removePost = 'Remove from Travel buddies';
  static const String removePostLine = 'The trip stays in My Trips';
  static const String postRemoved = 'Removed from Travel buddies';
  static const String requestCancelled = 'Request cancelled';
  static const String moreOptions = 'More options';
  static const String notificationsLabel = 'Notifications';

  // Request sheet
  static String sheetSummary(PublicTrip t) => '${SocialFormats.cities(t.cityNames)} · ${SocialFormats.days(t.days)}';
  static String sheetSub(PublicTrip t) =>
      '${t.owner.shortName} · ${SocialFormats.when(t.when).toLowerCase()} · ${SocialFormats.seatsLeft(t.seatsLeft, t.seats)}';
  static String noteLabel(String firstName) => 'A short note to $firstName';
  static const String optional = '(optional)';
  static String noteSeen(String firstName) => '$firstName sees it with your request';
  static String joinFreeLine(LimitUse u) {
    final base = 'Free: ${_count(u.limit, 'join request', 'join requests')} a month.';
    if (u.left == 1) return '$base This one is it.';
    if (u.left > 1) return '$base ${u.left} left.';
    return base;
  }

  static const String sendRequest = 'Send request';
  static const String requestSent = 'Request sent. The answer comes to your bell.';

  // Join requests page
  static String requestsSub(PublicTrip t) =>
      '${SocialFormats.cities(t.cityNames)} · ${SocialFormats.when(t.when).toLowerCase()} · ${SocialFormats.seatsLeft(t.seatsLeft, t.seats)}';
  static String sectionBuddies(int n) => 'My Buddies · $n';
  static String sectionFollowers(int n) => 'Followers · $n';
  static String sectionOthers(int n) => 'Other requests · $n';
  static const String yourBuddy = 'Your buddy';
  static const String followsYou = 'Follows you';
  static const String alsoAddToBuddies = 'Also add to My Buddies';
  static const String accept = 'Accept';
  static const String decline = 'Decline';
  static const String acceptNote = 'Accept makes the person a trip member: the trip shows in their My Trips and the trip chat opens.';
  static const String noRequestsTitle = 'No requests yet';
  static const String noRequestsBody = 'They come to your bell.';
  static String joinedTrip(String shortName) => '$shortName joined your trip';
  static String declined(String shortName) => 'Declined $shortName';
  static const String requestGone = 'This request is no longer waiting.';

  // Notify travellers near me (post wizard)
  static const String notifyNearby = 'Notify travellers near me';
  static String notifyNearbyLine(LimitUse u) => 'Sent at 7 am · ${u.left} of ${u.limit} left this week';
  static String notifyUsedLine(LimitUse u) => 'Used ${u.limit} of ${u.limit} this week';
  static const String notifyPrivateLine = 'Not available with a private profile';
  static const String notifyGenderLine = 'For trips open to anyone or to your own gender';
  static const String notifyUsedUp = 'Notifications for this post are used up this week. Your trip is still posted.';
  static String notifyBackOn(DateTime at) => 'They are back on ${BuddyFormat.weekdayDate(at)}.';
  static String notifyUsedUpNote(DateTime? back) => back == null ? notifyUsedUp : '$notifyUsedUp ${notifyBackOn(back)}';
  static const String notifyUsedUpPosted = 'Notifications for this post are used up this week. Your trip is still posted.';
  static const String nearbyTomorrow = 'Travellers near you hear about it at 7 am.';
  static String notifyTooFar(int days) => 'For trips starting in the next $days days';
  static String publishLimit(DateTime? next) =>
      next == null ? 'You have posted a lot this week. Try again later.' : 'You have posted a lot this week. Try again on ${BuddyFormat.weekdayDate(next)}.';

  // Post entries when the live post cap is reached
  static const String freeLimitHint = 'Free limit reached. Get Plus.';
  static String liveLimitHint(int n) => n == 1 ? '1 live post. Remove it to post again.' : '$n live posts. Remove one to post again.';
  static String postEntryHint(SocialLimits? l) {
    if (l == null || !l.publicTrips.reached) return '';
    return l.postNeedsPlus ? freeLimitHint : liveLimitHint(l.publicTrips.limit);
  }

  // Full and removed states
  static const String requestsFullLine = 'Not taking more requests';
  static String fullLabel(int seatsLeft) => seatsLeft > 0 ? '$full · $requestsFullLine' : full;
  static const String cannotRejoin = 'You can no longer join this trip';
  static const String requestsFullNow = 'This trip is not taking more requests.';
  static String requestsFullOwner(int n) => '$n requests waiting. Review them to take more.';

  // Trip overview seam
  static const String postToFindBuddies = 'Post your trip';
  static const String openJoinRequests = 'Join requests';
  static const String tripChat = 'Trip chat';
  static const String detailsLocked = 'Stay, taxi and money details open when the trip starts.';
}
