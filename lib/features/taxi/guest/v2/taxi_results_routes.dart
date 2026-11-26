import 'package:get/get.dart';
import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../../models/place_result_model.dart';
import 'taxi_popular_routes.dart';
import 'taxi_results_screen.dart';

typedef TaxiResultsOpener = Future<void>? Function({
  required PlaceResult? from,
  required bool fromNearYou,
  required PlaceResult to,
  required DateTime date,
  TaxiCityPair? cities,
});

final List<GetPage> taxiSeekerPages = [
  GetPage(
    name: AppRoutes.taxiRouteResults,
    page: () => const TaxiResultsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
];

abstract final class TaxiResultsNav {
  static Future<void>? open({
    required PlaceResult? from,
    required bool fromNearYou,
    required PlaceResult to,
    required DateTime date,
    TaxiCityPair? cities,
  }) {
    final f = from;
    if (f == null) return null;
    final args = TaxiResultsArgs(from: f, fromNearYou: fromNearYou, to: to, date: date, cities: cities);
    return Get.toNamed<void>(AppRoutes.taxiRouteResults, arguments: args.toMap());
  }
}
