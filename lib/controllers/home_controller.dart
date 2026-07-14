import 'package:get/get.dart';
import '../services/api_service.dart';
import 'location_controller.dart';

class HomeRoomModel {
  final String id;
  final int priceMonthly;
  final String? roomTypeName;
  final String? thumbnailUrl;
  final String? cityName;
  final String districtName;
  final String furnishedStatus;

  HomeRoomModel({
    required this.id,
    required this.priceMonthly,
    this.roomTypeName,
    this.thumbnailUrl,
    this.cityName,
    required this.districtName,
    required this.furnishedStatus,
  });

  factory HomeRoomModel.fromJson(Map<String, dynamic> json) => HomeRoomModel(
        id: json['id'] as String,
        priceMonthly: (json['priceMonthly'] as num?)?.toInt() ?? 0,
        roomTypeName: json['roomTypeName'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        cityName: json['cityName'] as String?,
        districtName: json['districtName'] as String? ?? '',
        furnishedStatus: json['furnishedStatus'] as String? ?? 'None',
      );
}

class HomePlotModel {
  final String id;
  final double areaValue;
  final String areaUnit;
  final String? plotTypeName;
  final String? thumbnailUrl;
  final String? cityName;
  final String districtName;

  HomePlotModel({
    required this.id,
    required this.areaValue,
    required this.areaUnit,
    this.plotTypeName,
    this.thumbnailUrl,
    this.cityName,
    required this.districtName,
  });

  factory HomePlotModel.fromJson(Map<String, dynamic> json) => HomePlotModel(
        id: json['id'] as String,
        areaValue: (json['areaValue'] as num?)?.toDouble() ?? 0,
        areaUnit: json['areaUnit'] as String? ?? '',
        plotTypeName: json['plotTypeName'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        cityName: json['cityName'] as String?,
        districtName: json['districtName'] as String? ?? '',
      );
}

/// Home tab's data source. Loads a district-scoped summary + 5 most-recent
/// rooms/plots + relies on LocationController.nearbyCities (already fetched
/// by the existing GPS/district-resolution flow) for Popular Areas.
class HomeController extends GetxController {
  final roomsCount = 0.obs;
  final plotsCount = 0.obs;
  final recentRooms = <HomeRoomModel>[].obs;
  final recentPlots = <HomePlotModel>[].obs;

  final summaryLoading = true.obs;
  final roomsLoading = true.obs;
  final plotsLoading = true.obs;

  /// 'rooms' | 'plots' — which rail the toggle is currently showing.
  final activeTab = 'rooms'.obs;

  Worker? _districtWorker;
  String? _loadedDistrictId;

  @override
  void onInit() {
    super.onInit();
    final locationCtrl = Get.find<LocationController>();
    _districtWorker = everAll(
      [locationCtrl.selectedDistrict, locationCtrl.browsingDistrict],
      (_) {
        final district = locationCtrl.effectiveDistrict;
        if (district != null) loadHomeData(district.id);
      },
    );
    final current = locationCtrl.effectiveDistrict;
    if (current != null) loadHomeData(current.id);
  }

  @override
  void onClose() {
    _districtWorker?.dispose();
    super.onClose();
  }

  void setActiveTab(String tab) => activeTab.value = tab;

  Future<void> loadHomeData(String districtId) async {
    if (_loadedDistrictId == districtId) return;
    _loadedDistrictId = districtId;
    summaryLoading.value = true;
    roomsLoading.value = true;
    plotsLoading.value = true;

    await Future.wait([
      _loadSummary(districtId),
      _loadRooms(districtId),
      _loadPlots(districtId),
    ]);
  }

  /// Force a reload of the current district — used by pull-to-refresh.
  /// (Named reloadDistrict, not refresh — GetxController already defines a
  /// synchronous refresh() for GetBuilder rebuilds; reusing that name here
  /// would shadow it with an incompatible async signature.)
  Future<void> reloadDistrict() async {
    final districtId = _loadedDistrictId;
    if (districtId == null) return;
    _loadedDistrictId = null;
    await loadHomeData(districtId);
  }

  Future<void> _loadSummary(String districtId) async {
    try {
      final res = await ApiService.get('/home/summary', params: {'districtId': districtId});
      final data = res['data'] as Map<String, dynamic>?;
      roomsCount.value = (data?['roomsCount'] as num?)?.toInt() ?? 0;
      plotsCount.value = (data?['plotsCount'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Leave last-known counts on failure — a stale number beats a blank one.
    } finally {
      summaryLoading.value = false;
    }
  }

  Future<void> _loadRooms(String districtId) async {
    try {
      final res = await ApiService.get('/home/rooms', params: {'districtId': districtId, 'limit': 5});
      final list = (res['data']?['items'] as List?) ?? const [];
      recentRooms.value = list.map((e) => HomeRoomModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
    } finally {
      roomsLoading.value = false;
    }
  }

  Future<void> _loadPlots(String districtId) async {
    try {
      final res = await ApiService.get('/home/plots', params: {'districtId': districtId, 'limit': 5});
      final list = (res['data']?['items'] as List?) ?? const [];
      recentPlots.value = list.map((e) => HomePlotModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
    } finally {
      plotsLoading.value = false;
    }
  }
}
