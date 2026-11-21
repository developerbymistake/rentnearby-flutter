abstract final class StayNoticeStrings {
  static const tagStay = 'STAY';
  static const tagPrice = 'PRICE';
  static const tagPlan = 'PLAN';
  static const changeLive = 'Your change is live';
  static String nameUpdated(String name) => 'Name updated to $name';
  static const detailsUpdated = 'Your stay details are updated';
  static const changeNotApproved = 'Change not approved';
  static String festivalStarts(String name, String date) => '$name week starts $date';
  static String festivalWeek(String name) => '$name week';
  static const setYourPrice = 'Set your price for those days.';
  static const plansStarted = 'Plans have started';
  static String hiddenOnFree(int photos, int roomTypes) {
    final parts = [
      if (photos > 0) photos == 1 ? '1 photo' : '$photos photos',
      if (roomTypes > 0) roomTypes == 1 ? '1 room type' : '$roomTypes room types',
    ];
    final one = photos + roomTypes == 1;
    return '${parts.join(' and ')} ${one ? 'is' : 'are'} hidden on Free. Nothing is deleted.';
  }

  static String plansStartOn(String date) => 'Plans start on $date';
  static String freeKeeps({required bool trial}) =>
      trial ? 'Free keeps 2 photos and 2 room types. Try Plus free for 7 days.' : 'Free keeps 2 photos and 2 room types.';
}
