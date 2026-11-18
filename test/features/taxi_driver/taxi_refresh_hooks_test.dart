import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/taxi_list_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/taxi_status_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class _Repo extends TaxiFeedRepository {
  int calls = 0;
  bool fail = false;

  @override
  Future<NearbyPage<TaxiFeedItem>> local({
    required double lat,
    required double lng,
    String? pageToken,
    int pageSize = 20,
    String? category,
  }) {
    calls++;
    return fail ? Future.error(StateError('offline')) : Future.value(const NearbyPage<TaxiFeedItem>(items: []));
  }
}

class _V1 extends TaxiListController {
  @override
  // ignore: must_call_super
  void onInit() {
  }
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TaxiListControllerV2 _v2(_Repo repo, RxInt tab) => Get.put(
      TaxiListControllerV2(repo: repo, centre: () => const LatLng(28, 77), centreVersion: 0.obs, tabIndex: tab),
      tag: TaxiListControllerV2.tag,
    );

void main() {
  tearDown(Get.reset);

  test('driver_save_refreshes_the_registered_taxi_lists', () async {
    final pushed = Get.put<TaxiListController>(_V1(), tag: TaxiListController.pushTag);
    final rootV1 = Get.put<TaxiListController>(_V1(), tag: TaxiListController.tag);
    final repo = _Repo();
    final v2 = _v2(repo, AppTabs.taxi.obs);
    await _settle();
    final before = repo.calls;
    TaxiStatusSync.refreshLists();
    await _settle();
    expect(pushed.refreshTrigger.value, 1);
    expect(rootV1.refreshTrigger.value, 1);
    expect(v2.refreshTrigger.value, 1);
    expect(repo.calls, before + 1);
  });

  test('driver_save_is_safe_when_no_list_is_registered', () {
    TaxiStatusSync.refreshLists();
  });

  test('tab_tap_refreshes_the_v2_root_list', () async {
    final repo = _Repo()..fail = true;
    final v2 = _v2(repo, AppTabs.taxi.obs);
    await _settle();
    expect(repo.calls, 1);
    expect(v2.loadFailed.value, isTrue);
    repo.fail = false;
    TaxiStatusSync.onTaxiTabTap();
    await _settle();
    expect(repo.calls, 2);
    expect(v2.loadFailed.value, isFalse);
  });

  test('tab_tap_without_a_list_does_nothing', () {
    TaxiStatusSync.onTaxiTabTap();
  });
}
