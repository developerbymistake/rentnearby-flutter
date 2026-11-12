import '../features/nearby/models/nearby_models.dart';
import '../features/stay/models/stay_browse_item.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import 'browse_item.dart';

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
  final HomeStayModel? stay;

  const HomeRecentItem.stay(HomeStayModel this.stay);

  DateTime? get createdAt => stay?.createdAt;
}

class HomeFeedModel {
  final List<HomeStayModel>? stays;
  final List<TaxiBrowseItem>? taxis;
  final List<HomeStayModel>? recentStays;
  final Map<String, bool> tabs;
  final NearbyHeader header;

  const HomeFeedModel({
    this.tabs = const {},
    this.header = NearbyHeader.empty,
    this.stays,
    this.taxis,
    this.recentStays,
  });

  static const _sectionTab = {
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
    stays: _list(json['stays'], HomeStayModel.fromJson),
    taxis: _list(json['taxis'], TaxiBrowseItem.fromJson),
    recentStays: _list(json['recentStays'], HomeStayModel.fromJson),
  );

  static List<T>? _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
      raw is List ? raw.whereType<Map<String, dynamic>>().map(parse).toList() : null;
}
