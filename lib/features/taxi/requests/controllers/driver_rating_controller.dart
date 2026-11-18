import 'package:get/get.dart';

import '../../../trip/utils/taxi_result.dart';
import '../data/driver_request_repository.dart';
import '../models/driver_request_models.dart';

class DriverRatingController extends GetxController {
  DriverRatingController({this._repo = const DriverRequestRepository()});

  static DriverRatingController get to =>
      Get.isRegistered<DriverRatingController>() ? Get.find<DriverRatingController>() : Get.put(DriverRatingController());

  final DriverRequestRepository _repo;

  final rating = Rxn<DriverRating>();
  final loading = false.obs;
  final failed = false.obs;

  Future<TaxiResult<DriverRating>>? _loading;

  Future<TaxiResult<DriverRating>> load() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<TaxiResult<DriverRating>> _load() async {
    loading.value = true;
    failed.value = false;
    try {
      final r = await _repo.rating();
      if (r case TaxiOk<DriverRating>(:final value)) rating.value = value;
      failed.value = r is! TaxiOk<DriverRating>;
      return r;
    } finally {
      loading.value = false;
    }
  }
}
