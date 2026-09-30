import 'package:get/get.dart';
import '../services/api_service.dart';
import 'listing_controller.dart';
import 'location_controller.dart';
import 'plot_controller.dart';

class HomeRoomModel {
  final String id;
  final String
  userId; // the listing owner — used to hide "Chat" on a user's own listing
  final int priceMonthly;
  final String? roomTypeName;
  final String? thumbnailUrl;
  final String? cityName;
  final String districtName;
  final String furnishedStatus;
  final DateTime? createdAt;

  HomeRoomModel({
    required this.id,
    required this.userId,
    required this.priceMonthly,
    this.roomTypeName,
    this.thumbnailUrl,
    this.cityName,
    required this.districtName,
    required this.furnishedStatus,
    this.createdAt,
  });

  factory HomeRoomModel.fromJson(Map<String, dynamic> json) => HomeRoomModel(
    id: json['id'] as String,
    userId: json['userId'] as String? ?? '',
    priceMonthly: (json['priceMonthly'] as num?)?.toInt() ?? 0,
    roomTypeName: json['roomTypeName'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    cityName: json['cityName'] as String?,
    districtName: json['districtName'] as String? ?? '',
    furnishedStatus: json['furnishedStatus'] as String? ?? 'None',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class HomePlotModel {
  final String id;
  final String
  userId; // the listing owner — used to hide "Chat" on a user's own listing
  final double areaValue;
  final String areaUnit;
  final String? plotTypeName;
  final String? thumbnailUrl;
  final String? cityName;
  final String districtName;
  final DateTime? createdAt;

  HomePlotModel({
    required this.id,
    required this.userId,
    required this.areaValue,
    required this.areaUnit,
    this.plotTypeName,
    this.thumbnailUrl,
    this.cityName,
    required this.districtName,
    this.createdAt,
  });

  factory HomePlotModel.fromJson(Map<String, dynamic> json) => HomePlotModel(
    id: json['id'] as String,
    userId: json['userId'] as String? ?? '',
    areaValue: (json['areaValue'] as num?)?.toDouble() ?? 0,
    areaUnit: json['areaUnit'] as String? ?? '',
    plotTypeName: json['plotTypeName'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    cityName: json['cityName'] as String?,
    districtName: json['districtName'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class HomeRecentItem {
  final HomeRoomModel? room;
  final HomePlotModel? plot;

  const HomeRecentItem.room(HomeRoomModel this.room) : plot = null;
  const HomeRecentItem.plot(HomePlotModel this.plot) : room = null;

  DateTime? get createdAt => room?.createdAt ?? plot?.createdAt;
}

/// Home tab's data source. Loads 5 most-recent (district-scoped "for you"
/// and district-free "recently added") rooms/plots per active tab.
class HomeController extends GetxController {
  final recentRooms = <HomeRoomModel>[].obs;
  final recentPlots = <HomePlotModel>[].obs;

  // "Recently added" — same district scope as recentRooms/recentPlots above,
  // but sorted newest-first via the existing /home/{rooms|plots}/browse
  // endpoint instead of
  // whatever ranking /home/rooms and /home/plots use for "X for you". Kept
  // as separate lists/loading flags so the two sections never get confused.
  final recentlyAddedRooms = <HomeRoomModel>[].obs;
  final recentlyAddedPlots = <HomePlotModel>[].obs;

  final roomsLoading = true.obs;
  final plotsLoading = true.obs;
  final recentlyAddedRoomsLoading = true.obs;
  final recentlyAddedPlotsLoading = true.obs;

  Worker? _districtWorker;
  Worker? _plotRefreshWorker;
  Worker? _roomRefreshWorker;
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

    // Bumped after the server confirms a genuine data change: toggleActive
    // (listingStatusChangedTrigger) or Go Live (listingPostedTrigger/
    // plotPostedTrigger — separate trigger, was missing here entirely, which
    // is why a newly-live listing never showed on Home until a manual
    // pull-to-refresh). Deliberately NOT exploreRefreshTrigger: that one is
    // also bumped unconditionally on every switch to the Rooms/Plots bottom
    // tab (main_screen.dart, for Explore's own unrelated refresh needs), so
    // listening to it here would silently reload Home on plain navigation —
    // exactly the behaviour this fix must not reintroduce.
    _plotRefreshWorker = everAll(
      [
        Get.find<PlotController>().listingStatusChangedTrigger,
        Get.find<PlotController>().plotPostedTrigger,
      ],
      (_) => _forceReload(),
    );
    _roomRefreshWorker = everAll(
      [
        Get.find<ListingController>().listingStatusChangedTrigger,
        Get.find<ListingController>().listingPostedTrigger,
      ],
      (_) => _forceReload(),
    );

    final current = locationCtrl.effectiveDistrict;
    if (current != null) loadHomeData(current.id);
  }

  @override
  void onClose() {
    _districtWorker?.dispose();
    _plotRefreshWorker?.dispose();
    _roomRefreshWorker?.dispose();
    super.onClose();
  }

  void _forceReload() {
    final district = Get.find<LocationController>().effectiveDistrict;
    if (district == null) return;
    _loadedDistrictId = null;
    loadHomeData(district.id);
  }

  List<HomeRecentItem> recentMixed({
    bool rooms = true,
    bool plots = true,
    int count = 6,
  }) {
    final all = <HomeRecentItem>[
      if (rooms) ...recentlyAddedRooms.map(HomeRecentItem.room),
      if (plots) ...recentlyAddedPlots.map(HomeRecentItem.plot),
    ];
    all.sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return all.take(count).toList();
  }

  Future<void> loadHomeData(String districtId) async {
    if (_loadedDistrictId == districtId) return;
    _loadedDistrictId = districtId;
    roomsLoading.value = true;
    plotsLoading.value = true;
    recentlyAddedRoomsLoading.value = true;
    recentlyAddedPlotsLoading.value = true;

    await Future.wait([
      _loadList(
        path: '/home/rooms',
        params: {'districtId': districtId, 'limit': 5},
        target: recentRooms,
        loading: roomsLoading,
        parse: HomeRoomModel.fromJson,
      ),
      _loadList(
        path: '/home/plots',
        params: {'districtId': districtId, 'limit': 5},
        target: recentPlots,
        loading: plotsLoading,
        parse: HomePlotModel.fromJson,
      ),
      // "Recently added" — deliberately NOT district-scoped, unlike
      // recentRooms/recentPlots above. Dedicated backend endpoints
      // (/home/rooms/recent, /home/plots/recent — no districtId param at
      // all, server-side cached since the result is identical for every
      // caller) so this genuinely shows the newest listings across every
      // district, not a relabeled copy of "X for you".
      _loadList(
        path: '/home/rooms/recent',
        params: {'limit': 10},
        target: recentlyAddedRooms,
        loading: recentlyAddedRoomsLoading,
        parse: HomeRoomModel.fromJson,
      ),
      _loadList(
        path: '/home/plots/recent',
        params: {'limit': 10},
        target: recentlyAddedPlots,
        loading: recentlyAddedPlotsLoading,
        parse: HomePlotModel.fromJson,
      ),
    ]);
  }

  // Shared fetch+parse+loading-flag plumbing for every Home rail — endpoint
  // path, query params, target list, and model parser are the only things
  // that ever differ between "for you" and "recently added" (Room vs Plot).
  Future<void> _loadList<M>({
    required String path,
    required Map<String, dynamic> params,
    required RxList<M> target,
    required RxBool loading,
    required M Function(Map<String, dynamic>) parse,
  }) async {
    try {
      final res = await ApiService.get(path, params: params);
      final list = (res['data']?['items'] as List?) ?? const [];
      target.value = list.map((e) => parse(e as Map<String, dynamic>)).toList();
    } catch (_) {
    } finally {
      loading.value = false;
    }
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
}
