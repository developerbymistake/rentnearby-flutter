abstract final class SocialStringsA {
  static const String obTitle = 'Complete your profile';
  static const String obStep1 = 'Step 1 of 3 · You';
  static const String obStep2 = 'Step 2 of 3 · Your travel style';
  static const String obStep3 = 'Step 3 of 3 · About you';
  static const String changePhoto = 'Change photo';
  static const String addPhoto = 'Add a photo';
  static const String addPhotoWhy = 'Optional. Faces help people trust your plan.';
  static const String fullName = 'Full name';
  static const String fullNameHint = 'Your full name';
  static const String gender = 'Gender';
  static const String male = 'Male';
  static const String female = 'Female';
  static const String other = 'Other';
  static const List<String> genders = [male, female, other];
  static const String birth = 'Birth month and year';
  static const String month = 'Month';
  static const String year = 'Year';
  static const String birthHelp = 'Only to check you are 18 or over. Never shown.';
  static const String verified = 'Verified';
  static const String next = 'Next';
  static const String finish = 'Finish';
  static const String interestsLabel = 'Interests · pick 3 to 5';
  static const String skillsLabel = 'Skills · pick at least 1';
  static const String placesLabel = 'Places you have been · at least 1';
  static const String addPlaceHint = 'Add a city or state';
  static const String aboutYou = 'About you';
  static const String aboutHint = 'A line about how you travel';
  static const String needed = 'Needed';
  static const String tapToStart = 'Tap one to start';
  static const String howOthersSee = 'How others see you';
  static const String writeAbout = 'Write a line about you';
  static const String nameTooLong = 'Name cannot exceed 100 characters';
  static const String skipForNow = 'Skip for now';

  static String stepOf(int step, int total) => 'Step $step of $total';

  static String removeTag(String text) => 'Remove $text';

  static String ofFive(int n) => '$n of 5';

  static String step1Missing({required bool name, required bool gender, required bool birth}) {
    final parts = <String>[if (name) 'your name', if (gender) 'gender', if (birth) 'birth month and year'];
    if (parts.isEmpty) return '';
    final verb = name ? 'Add' : 'Pick your';
    final list = parts.length == 1 ? parts.first : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return '$verb $list';
  }

  static String step2Missing({required int interests, required int skills, required int places}) {
    final parts = <String>[
      if (interests > 0) '$interests more ${interests == 1 ? 'interest' : 'interests'}',
      if (skills > 0) '$skills ${skills == 1 ? 'skill' : 'skills'}',
      if (places > 0) '$places ${places == 1 ? 'place' : 'places'}',
    ];
    if (parts.isEmpty) return '';
    final list = parts.length == 1 ? parts.first : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return 'Pick $list';
  }

  static const String profileTitle = 'Profile';
  static const String profileSub = 'Your traveller profile';
  static const String editProfileBtn = 'Edit Profile';
  static const String settingsLabel = 'Settings';
  static const String trips = 'Trips';
  static const String followers = 'Followers';
  static const String followingTab = 'Following';
  static const String about = 'About';
  static const String interests = 'Interests';
  static const String placesVisited = 'Places visited';
  static const String skills = 'Skills';
  static const String traveller = 'Traveller';

  static String myPublicTrips(int n) => 'My public trips · $n';

  static String publicTrips(int n) => 'Public trips · $n';

  static const String profileLoadFailed = 'Could not load your profile.';
  static const String travellerGone = 'This traveller is not available.';
  static const String privateTitle = 'This profile is private';
  static const String privateLine = 'Follow to see About and public trips.';
  static const String makeBuddyDone = 'Added to My Buddies';
  static const String removeBuddyDone = 'Removed from My Buddies';

  static const String editTitle = 'Edit profile';
  static const String editSub = 'Others see everything except your birth date';
  static const String lockedNote = 'Gender and birth date cannot be changed. Contact support if they are wrong.';
  static const String placesCard = 'Places you have been';
  static const String addPlace = 'Add place';
  static const String homeCity = 'Home city';
  static const String homeCityHint = 'shown on your profile';
  static const String homeCityNote = 'Never shown on your public plan cards.';
  static const String change = 'Change';
  static const String save = 'Save';
  static const String changeToSave = 'Change something to save';
  static const String saved = 'Profile updated';
  static const String pickThreeToFive = 'pick 3 to 5';
  static const String atLeastOne = 'at least 1';
  static const String addHomeCity = 'Add your home city';

  static String changes(int n) => n == 1 ? '1 change' : '$n changes';

  static String placesCount(int n) => n == 1 ? '1 place' : '$n places';

  static String interestsHint(int n) => '${ofFive(n)} · $pickThreeToFive';

  static const String pickPlaceTitle = 'Add a place';
  static const String pickHomeTitle = 'Home city';
  static const String searchPlace = 'Search a city or state';
  static const String stateLine = 'State';
  static const String noPlaceFound = 'No place found';

  static const String accountLabel = 'ACCOUNT';
  static const String privacyLabel = 'PRIVACY';
  static const String notificationsLabel = 'NOTIFICATIONS';
  static const String activityLabel = 'ACTIVITY';
  static const String supportLabel = 'SUPPORT';
  static const String legalLabel = 'LEGAL';
  static const String notVerified = 'Not verified';
  static const String changeRole = 'Change role';
  static const String currentRole = 'Current role';
  static const String requestPending = 'Request pending';
  static const String requestRejected = 'Request rejected';
  static const String paused = 'Paused';
  static const String plus = 'Bakhli Plus';
  static const String plusOn = 'Plus';
  static const String free = 'Free';
  static const String privateProfile = 'Private profile';
  static const String privateProfileLine = 'People ask before they follow you';
  static const String whoCanMessage = 'Who can message me';
  static const String whoCanMessageLine = 'People outside your choice cannot send you a message request.';
  static const String everyone = 'Everyone';
  static const String everyoneLine = 'New people land in Requests first';
  static const String peopleIFollow = 'People I follow';
  static const String buddiesOnly = 'Buddies only';
  static const String blockedPeople = 'Blocked people';
  static String blockedCount(int n) => '$n blocked';
  static const String notifyMessages = 'Messages';
  static const String notifyFollows = 'Follows and requests';
  static const String notifyTrips = 'Plans from people I follow';
  static const String myTrips = 'My Trips';
  static const String jobs = 'Jobs';
  static const String myJourneys = 'My Journeys';
  static const String myReports = 'My Reports';
  static const String contactSupport = 'Contact Support';
  static const String rateApp = 'Rate App';
  static const String shareApp = 'Share App';
  static const String privacyPolicy = 'Privacy Policy';
  static const String terms = 'Terms of Service';
  static const String logout = 'Logout';
  static const String deleteAccount = 'Delete Account';

  static String nowRole(String role) => 'Now: $role';

  static String tryAgainAfter(String when) => 'Try again after $when';

  static String policyLabel(String policy) => switch (policy) {
        'Following' => peopleIFollow,
        'Buddies' => buddiesOnly,
        _ => everyone,
      };

  static const String peopleTitle = 'People';
  static const String myBuddies = 'My Buddies';
  static const List<String> peopleTabs = [followers, followingTab, myBuddies];
  static const String requests = 'Requests';
  static const String wantsToFollow = 'wants to follow you';
  static const String accept = 'Accept';
  static const String decline = 'Decline';
  static const String requestsNote = 'Follow requests come only when your profile is private.';
  static const String addFromFollowers = 'Add from followers';
  static const String onlyYouSee = 'Only you see your buddies list';
  static const String buddiesNote =
      'Buddies are your own list. Inviting a buddy to a private trip still needs them to accept the trip invite. Remove one from the 3 dots.';
  static const String removeFollower = 'Remove follower';
  static const String removeFollowerLine = 'They are not told';
  static const String removeBuddy = 'Remove from My Buddies';
  static const String removeBuddyLine = 'They are not told';
  static const String noFollowers = 'No followers yet';
  static const String noFollowersLine = 'Post a trip and people can follow you.';
  static const String noFollowing = 'You follow no one yet';
  static const String noFollowingLine = 'Follow travellers from their profile.';
  static const String noBuddies = 'No buddies yet';
  static const String noBuddiesLine = 'Add people who follow you.';
  static const String noRequests = 'No requests';

  static String followersCount(int n) => n == 1 ? '1 follower' : '$n followers';

  static String followingCount(int n) => '$n following';

  static String buddiesCount(int n) => n == 1 ? '1 buddy' : '$n buddies';

  static String waiting(int n) => '$n waiting';

  static String requestsLine(String first, int total) => total <= 1 ? '$first wants to follow you' : '$first and ${total - 1} more want to follow you';

  static const String addBuddiesTitle = 'Add to My Buddies';
  static const String addBuddiesSub = 'From your followers';
  static const String searchFollowers = 'Search your followers';
  static const String starNote = 'Tap the star. They are not told.';
  static const String noMatch = 'No follower found';

  static String followersAndBuddies(int followers, int buddies) => '${followersCount(followers)} · ${buddiesCount(buddies)}';
}
