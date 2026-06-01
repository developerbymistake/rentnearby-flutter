class BannerModel {
  final String id;
  final String imageUrl;
  final String? contactNumber;
  final String? redirectUrl;

  const BannerModel({
    required this.id,
    required this.imageUrl,
    this.contactNumber,
    this.redirectUrl,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
        id: json['id'] as String,
        imageUrl: json['imageUrl'] as String,
        contactNumber: json['contactNumber'] as String?,
        redirectUrl: json['redirectUrl'] as String?,
      );
}
