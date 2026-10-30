import '../../models/plan_purchase_result.dart' show PlanOrder;
import '../../models/store_product.dart';

enum BillingEventKind { pending, purchased, restored, canceled, error, alreadyOwned }

class BillingEvent {
  final BillingEventKind kind;
  final String? productId;
  final String? purchaseToken;
  final OwnedPurchase? purchase;
  final String? message;

  const BillingEvent({required this.kind, this.productId, this.purchaseToken, this.purchase, this.message});
}

abstract class BillingGateway {
  String get provider;
  Future<void> init();
  Stream<BillingEvent> get events;
  Future<bool> isAvailable();
  Future<Map<String, StoreProduct>> loadProducts(Set<String> productIds);
  Future<bool> launch(PlanOrder order, {StoreOffer? offer, OwnedPurchase? oldPurchase});
  Future<void> restore();
  Future<bool> openManage(String? manageUrl);
  void dispose();
}
