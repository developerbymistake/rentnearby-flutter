class StorePrice {
  final String formatted;
  final double raw;
  final String currencyCode;
  final String billingPeriod;

  const StorePrice({
    required this.formatted,
    required this.raw,
    required this.currencyCode,
    required this.billingPeriod,
  });
}

class StoreOffer {
  final String productId;
  final String basePlanId;
  final String? offerId;
  final String offerToken;
  final StorePrice price;
  final bool isTrial;
  final int trialDays;

  const StoreOffer({
    required this.productId,
    required this.basePlanId,
    required this.offerId,
    required this.offerToken,
    required this.price,
    required this.isTrial,
    required this.trialDays,
  });
}

class StoreProduct {
  final String productId;
  final String title;
  final List<StoreOffer> offers;

  const StoreProduct({required this.productId, required this.title, required this.offers});

  StoreOffer? basePlan(String basePlanId) {
    for (final o in offers) {
      if (o.basePlanId == basePlanId && o.offerId == null) return o;
    }
    return null;
  }

  StoreOffer? trialOffer(String basePlanId, String offerId) {
    for (final o in offers) {
      if (o.basePlanId == basePlanId && o.offerId == offerId) return o;
    }
    return null;
  }
}

class OwnedPurchase {
  final String productId;
  final String purchaseToken;
  final String? orderId;
  final bool isAcknowledged;
  final bool autoRenewing;
  final Object platformDetails;

  const OwnedPurchase({
    required this.productId,
    required this.purchaseToken,
    required this.orderId,
    required this.isAcknowledged,
    required this.autoRenewing,
    required this.platformDetails,
  });
}

enum StoreState { idle, loading, ready, unavailable }
