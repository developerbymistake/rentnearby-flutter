import '../features/stay/models/stay_browse_item.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import 'browse_item.dart';

class HomeRoomModel {
  final String id;
  final String userId;
  final int priceMonthly;
  final String? roomTypeName;
  final String? thumbnailUrl;
  final String? cityName;
  final String districtName;
  final String furnishedStatus;
  final bool? isAc;
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
    this.isAc,
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
    isAc: json['isAc'] as bool?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class HomePlotModel {
  final String id;
  final String userId;
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

class HomeStayModel {
  final BrowseItem item;
  final String districtName;
  final DateTime? createdAt;

  const HomeStayModel({required this.item, required this.districtName, this.createdAt});

  factory HomeStayModel.fromJson(Map<String, dynamic> json) => HomeStayModel(
    item: StayBrowseItem.fromJson(json),
    districtName: json['districtName'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class HomeRecentItem {
  final HomeRoomModel? room;
  final HomePlotModel? plot;
  final HomeStayModel? stay;

  const HomeRecentItem.room(HomeRoomModel this.room) : plot = null, stay = null;
  const HomeRecentItem.plot(HomePlotModel this.plot) : room = null, stay = null;
  const HomeRecentItem.stay(HomeStayModel this.stay) : room = null, plot = null;

  DateTime? get createdAt => room?.createdAt ?? plot?.createdAt ?? stay?.createdAt;
}

class HomeFeedModel {
  final List<HomeRoomModel>? rooms;
  final List<HomePlotModel>? plots;
  final List<HomeStayModel>? stays;
  final List<TaxiBrowseItem>? taxis;
  final List<HomeRoomModel>? recentRooms;
  final List<HomePlotModel>? recentPlots;
  final List<HomeStayModel>? recentStays;
  final Map<String, bool> tabs;

  const HomeFeedModel({
    this.tabs = const {},
    this.rooms,
    this.plots,
    this.stays,
    this.taxis,
    this.recentRooms,
    this.recentPlots,
    this.recentStays,
  });

  static const _sectionTab = {
    'rooms': 'rooms',
    'recentRooms': 'rooms',
    'plots': 'plots',
    'recentPlots': 'plots',
    'stays': 'stays',
    'recentStays': 'stays',
    'taxis': 'taxi',
  };

  /// True only when the server explicitly reported the section's tab as off.
  bool isSectionTabOff(String section) => tabs[_sectionTab[section]] == false;

  factory HomeFeedModel.fromJson(Map<String, dynamic> json) => HomeFeedModel(
    tabs: {
      for (final e in (json['tabs'] as Map? ?? const {}).entries)
        if (e.value is bool) e.key.toString(): e.value as bool,
    },
    rooms: _list(json['rooms'], HomeRoomModel.fromJson),
    plots: _list(json['plots'], HomePlotModel.fromJson),
    stays: _list(json['stays'], HomeStayModel.fromJson),
    taxis: _list(json['taxis'], TaxiBrowseItem.fromJson),
    recentRooms: _list(json['recentRooms'], HomeRoomModel.fromJson),
    recentPlots: _list(json['recentPlots'], HomePlotModel.fromJson),
    recentStays: _list(json['recentStays'], HomeStayModel.fromJson),
  );

  static List<T>? _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
      raw is List ? raw.whereType<Map<String, dynamic>>().map(parse).toList() : null;
}
