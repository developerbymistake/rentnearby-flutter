class TripStringsSpotsX {
  static String mustSee(String city) => 'Must see in $city';
  static const String featuredFirst = 'Featured first';
  static const String featured = 'Featured';
  static const String add = 'Add';
  static const String addWishlist = 'Wishlist';
  static const String addedWishlist = 'Added';
  static const String addToWishlist = 'Add to wishlist';
  static const String dismiss = 'No thanks';
  static const String offline = 'Offline. Showing your saved list.';
  static String fewPlaces(int n) => 'Only $n ${n == 1 ? 'place' : 'places'} here so far.';
  static String noneIn(String chip) => 'No places in $chip';
  static const String showAll = 'Show all';
  static const String remove = 'Remove';
  static const String readMore = 'Read more';
  static const String showLess = 'Show less';
  static const String gallery = 'Gallery';
  static String photoCount(int n) => n == 1 ? '1 photo' : '$n photos';
  static String morePhotos(int n) => '+$n more';
  static const String galleryError = "Couldn't load photos";
  static const String galleryErrorBody = 'Check your connection and try again';
  static String photoOf(String title, int i, int n) => '$title, photo $i of $n';
}
