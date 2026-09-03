class AppTabConfigModel {
  final String tabKey;
  final String displayName;
  final bool isActive;
  final int sortOrder;

  AppTabConfigModel({
    required this.tabKey,
    required this.displayName,
    required this.isActive,
    required this.sortOrder,
  });

  factory AppTabConfigModel.fromJson(Map<String, dynamic> j) => AppTabConfigModel(
        tabKey: j['tabKey'] ?? '',
        displayName: j['displayName'] ?? '',
        isActive: j['isActive'] ?? true,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );
}
