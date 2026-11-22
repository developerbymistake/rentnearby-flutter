abstract final class TaxiPlanStrings {
  static const subtitle = 'Taxi plan';
  static String routesCount(int n) => n == 1 ? '1 route' : '$n routes';
  static const normalTurn = 'Normal turn for requests';
  static String upToRoutes(int n) => 'Up to $n routes';
  static String turnAsOften(int w) => 'Your turn ${w}x as often';
  static const featuredInLists = 'Featured in taxi lists';
  static String upToRoutesRing(int n) => 'Up to $n routes ring';
  static const requestsBookingsRating = 'Requests, bookings, rating';
  static const routes = 'Routes';
  static String freeMeterNote(int free, int plus) => 'Free plan: ${routesCount(free)}. Plus allows up to $plus.';
  static const firstRouteStays = 'Your first route stays. Extra routes are hidden, not deleted.';
  static String keepAfter(int n) => 'After that, you keep ${routesCount(n)}.';
  static String keepUntil(int n) => 'Until then, you keep ${routesCount(n)}.';
  static const extraHidden = 'Extra routes are hidden. Nothing is deleted.';
  static const chooseYourRoute = 'Choose your route';
  static const offLine = 'Featured in taxi lists and your turn 2x as often. Not open yet.';

  static const rowRoutes = 'Routes';
  static const rowTurn = 'Your turn for requests';
  static const rowFeatured = 'Featured in taxi lists';
  static const rowRequests = 'Requests, bookings, rating';
  static const rowUpcoming = 'Upcoming list';
  static const rowMonth = 'Month calendar';
  static const rowTrips = 'Trips you add';
  static const rowReminder = 'Morning reminder';
  static const rowSummary = 'Month money summary';
  static const rowMoneyNotes = 'Money notes on each trip';

  static String noRouteRequests(int n) => '$n requests this week were for cities you have no route to.';
  static const moreRoutes = 'More routes, more requests.';
  static String routesOpenNow(int n) => 'Up to $n routes are open now.';
  static String requestsOnRoutes(int n) => n == 1 ? '1 request on your routes' : '$n requests on your routes';
  static String acceptedRenews(int n, String date) => 'You accepted $n. Renews on $date.';
  static String accepted(int n) => 'You accepted $n.';
  static String renews(String date) => 'Renews on $date.';
  static const weekRequests = 'Requests on your routes';
  static const weekAccepted = 'You accepted';
  static const weekTurn = 'Your turn';
  static String turnValue(int w) => '${w}x as often';
  static String profileLine(String plan, int used, int limit) => '$plan · $used of ${routesCount(limit)}';
}
