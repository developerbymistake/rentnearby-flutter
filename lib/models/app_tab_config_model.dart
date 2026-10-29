class AppTabConfigModel {
  final String tabKey;
  final String displayName;
  final bool isActive;
  final int sortOrder;
  final bool apiGated;
  final String? linkedRoleKey;

  AppTabConfigModel({
    required this.tabKey,
    required this.displayName,
    required this.isActive,
    required this.sortOrder,
    this.apiGated = false,
    this.linkedRoleKey,
  });

  factory AppTabConfigModel.fromJson(Map<String, dynamic> j) => AppTabConfigModel(
        tabKey: j['tabKey'] ?? '',
        displayName: j['displayName'] ?? '',
        isActive: j['isActive'] ?? true,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        apiGated: j['apiGated'] as bool? ?? false,
        linkedRoleKey: j['linkedRoleKey'] as String?,
      );
}
