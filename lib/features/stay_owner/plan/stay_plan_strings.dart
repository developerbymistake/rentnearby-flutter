abstract final class StayPlanStrings {
  static const subtitle = 'Stay plan';
  static String photos(int n) => n == 1 ? '1 photo' : '$n photos';
  static String roomTypes(int n) => n == 1 ? '1 room type' : '$n room types';
  static String jobPosts(int n) => n == 1 ? '1 job post' : '$n job posts';
  static String jobs(int n) => n == 1 ? '1 job' : '$n jobs';
  static const notFirst = 'Not first in trip plans';
  static const listedByDistance = 'Listed by distance';
  static const firstInTripPlans = 'First in trip plans';
  static const featuredNearYou = 'Featured near you';
  static String photosRooms(int p, int r) => '${photos(p)}, ${roomTypes(r)}';
  static String photosRoomsJobs(int p, int r, int j) => '${photos(p)}, ${roomTypes(r)}, ${jobs(j)}';
  static const photosLabel = 'Photos';
  static String roomTypesMeter(int used, int limit) => 'Room types $used of $limit';
  static const coverStays = 'Cover and next photo stay. Extras are hidden, not deleted.';
  static String openNow(int p, int r) => '${photos(p)} and ${roomTypes(r)} are open now.';
  static String keepAfter(int p, int r) => 'After that, you keep ${photos(p)} and ${roomTypes(r)}.';
  static String keepUntil(int p, int r) => 'Until then, you keep ${photos(p)} and ${roomTypes(r)}.';
  static String hidden(int p, int r) {
    if (p > 0 && r > 0) return 'Up to ${photos(p)} and ${roomTypes(r)} are hidden. Nothing is deleted.';
    if (p > 0) return 'Up to ${photos(p)} ${p == 1 ? 'is' : 'are'} hidden. Nothing is deleted.';
    return 'Up to ${roomTypes(r)} ${r == 1 ? 'is' : 'are'} hidden. Nothing is deleted.';
  }

  static const chooseWhatStays = 'Choose what stays';
  static const offLine = 'Plus will put your stay first in trip plans. Not open yet.';

  static const rowFirst = 'First in trip plans';
  static const rowFeatured = 'Featured near you';
  static const rowPhotos = 'Photos';
  static const rowRoomTypes = 'Room types';
  static const rowJobs = 'Job posts';
  static const rowEnquiries = 'Enquiries and offers';
  static const rowUpcoming = 'Upcoming list';
  static const rowMonth = 'Month calendar';
  static const rowBookings = 'Bookings you add';
  static const rowBlocked = 'Blocked day ranges';
  static const rowMoneyNotes = 'Money notes on each booking';
  static const rowReminder = 'Morning reminder';
  static const rowSummary = 'Month money summary';
  static const rowSpecial = 'Special prices';

  static const timesShown = 'Times shown';
  static const enquiries = 'Enquiries';

  static String shownTimes(int n) => 'Shown $n times';
  static String firstForTrip(String city) => 'Plus stays come first when travellers plan a trip to $city.';
  static String enquiriesRenews(int n, String date) => '${n == 1 ? '1 enquiry' : '$n enquiries'} this week. Renews on $date.';
  static String enquiriesWeek(int n) => '${n == 1 ? '1 enquiry' : '$n enquiries'} this week.';
  static String renews(String date) => 'Renews on $date.';
  static String profileLine(String plan, int used, int limit) => '$plan · $used of ${photos(limit)}';
}
