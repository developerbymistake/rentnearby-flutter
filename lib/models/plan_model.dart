class PlanPriceModel {
  final int cycleMonths;
  final int priceInr;
  final int perMonthInr;
  final int savePercent;

  const PlanPriceModel({
    required this.cycleMonths,
    required this.priceInr,
    required this.perMonthInr,
    required this.savePercent,
  });

  factory PlanPriceModel.fromJson(Map<String, dynamic> j) => PlanPriceModel(
        cycleMonths: (j['cycleMonths'] as num?)?.toInt() ?? 1,
        priceInr: (j['priceInr'] as num?)?.toInt() ?? 0,
        perMonthInr: (j['perMonthInr'] as num?)?.toInt() ?? 0,
        savePercent: (j['savePercent'] as num?)?.toInt() ?? 0,
      );
}

class PlanFeatureKeys {
  const PlanFeatureKeys._();
  static const listingLimit = 'ListingLimit';
  static const priority = 'Priority';
  static const featured = 'Featured';
  static const jobsPosts = 'JobsPosts';
}

class PlanModel {
  final String id;
  final String featureKey;
  final String code;
  final String name;
  final String? tagline;
  final bool isDefault;
  final int trialDays;
  final Map<String, int> features;
  final List<PlanPriceModel> prices;

  const PlanModel({
    required this.id,
    required this.featureKey,
    required this.code,
    required this.name,
    required this.tagline,
    required this.isDefault,
    required this.trialDays,
    required this.features,
    required this.prices,
  });

  int feature(String key) => features[key] ?? 0;
  int get listingLimit => feature(PlanFeatureKeys.listingLimit);
  bool get isFeatured => feature(PlanFeatureKeys.featured) > 0;
  bool get hasPriority => feature(PlanFeatureKeys.priority) > 0;
  int get jobsPosts => feature(PlanFeatureKeys.jobsPosts);

  PlanPriceModel? priceFor(int cycleMonths) {
    for (final p in prices) {
      if (p.cycleMonths == cycleMonths) return p;
    }
    return null;
  }

  factory PlanModel.fromJson(Map<String, dynamic> j, String featureKey) => PlanModel(
        id: j['id'] as String,
        featureKey: featureKey,
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        tagline: j['tagline'] as String?,
        isDefault: j['isDefault'] == true,
        trialDays: (j['trialDays'] as num?)?.toInt() ?? 0,
        features: ((j['features'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        prices: ((j['prices'] as List?) ?? const [])
            .map((e) => PlanPriceModel.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.cycleMonths.compareTo(b.cycleMonths)),
      );
}

class PlanCatalogModel {
  final Map<String, List<PlanModel>> byFeature;
  const PlanCatalogModel(this.byFeature);

  List<PlanModel> plansOf(String? featureKey) => byFeature[featureKey] ?? const [];

  factory PlanCatalogModel.fromJson(Map<String, dynamic> j) {
    final out = <String, List<PlanModel>>{};
    for (final f in (j['features'] as List? ?? const [])) {
      final m = f as Map<String, dynamic>;
      final key = m['featureKey'] as String;
      out[key] = (m['plans'] as List? ?? const [])
          .map((e) => PlanModel.fromJson(e as Map<String, dynamic>, key))
          .toList();
    }
    return PlanCatalogModel(out);
  }
}
