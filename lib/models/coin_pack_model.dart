/// A purchasable coin pack from the admin-managed catalog (GET /coin-packs/).
class CoinPackModel {
  final String id;
  final int coins;
  final int bonusCoins;
  final int totalCoins;
  final int priceInr;
  final bool isFeatured;
  final int sortOrder;

  CoinPackModel({
    required this.id,
    required this.coins,
    required this.bonusCoins,
    required this.totalCoins,
    required this.priceInr,
    required this.isFeatured,
    required this.sortOrder,
  });

  factory CoinPackModel.fromJson(Map<String, dynamic> json) => CoinPackModel(
        id: json['id'] as String,
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        bonusCoins: (json['bonusCoins'] as num?)?.toInt() ?? 0,
        totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
        priceInr: (json['priceInr'] as num?)?.toInt() ?? 0,
        isFeatured: json['isFeatured'] == true,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}
