class StayRegistrationTypeModel {
  final String id;
  final String code;
  final String name;
  final String? helpText;
  final int sortOrder;
  final bool requiresOtherName;

  const StayRegistrationTypeModel({
    required this.id,
    required this.code,
    required this.name,
    this.helpText,
    required this.sortOrder,
    required this.requiresOtherName,
  });

  factory StayRegistrationTypeModel.fromJson(Map<String, dynamic> json) => StayRegistrationTypeModel(
        id: json['id'].toString(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        helpText: json['helpText'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        requiresOtherName: json['requiresOtherName'] == true,
      );
}
