/// A purchasable credit pack from the admin-managed catalog (GET /credit-packs/).
class CreditPackModel {
  final String id;
  final int credits;
  final int bonusCredits;
  final int totalCredits;
  final int priceInr;
  final bool isFeatured;
  final int sortOrder;

  CreditPackModel({
    required this.id,
    required this.credits,
    required this.bonusCredits,
    required this.totalCredits,
    required this.priceInr,
    required this.isFeatured,
    required this.sortOrder,
  });

  factory CreditPackModel.fromJson(Map<String, dynamic> json) => CreditPackModel(
        id: json['id'] as String,
        credits: (json['credits'] as num?)?.toInt() ?? 0,
        bonusCredits: (json['bonusCredits'] as num?)?.toInt() ?? 0,
        totalCredits: (json['totalCredits'] as num?)?.toInt() ?? 0,
        priceInr: (json['priceInr'] as num?)?.toInt() ?? 0,
        isFeatured: json['isFeatured'] == true,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}
