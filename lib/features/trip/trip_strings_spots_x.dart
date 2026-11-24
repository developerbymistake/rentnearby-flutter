class TripStringsSpotsX {
  static String mustSee(String city) => 'Must see in $city';
  static const String featuredFirst = 'Featured first';
  static const String featured = 'Featured';
  static const String add = 'Add';
  static const String addToTrip = 'Add to trip';
  static const String addedToTrip = 'Added';
  static const String dismiss = 'No thanks';
  static String away(String d) => '$d away';
  static String aboutKmAway(String km) => 'about $km km away';
  static const String offline = 'Offline. Showing your saved list.';
  static String fewPlaces(int n) => 'Only $n ${n == 1 ? 'place' : 'places'} here so far.';
  static String noneIn(String chip) => 'No places in $chip';
  static const String showAll = 'Show all';
  static const String remove = 'Remove';
  static const String more = 'more';
  static const String gallery = 'Gallery';
  static String photoCount(int n) => n == 1 ? '1 photo' : '$n photos';
  static String morePhotos(int n) => '+$n more';
  static const String galleryError = "Couldn't load photos";
  static const String galleryErrorBody = 'Check your connection and try again';
  static String photoOf(String title, int i, int n) => '$title, photo $i of $n';
}
