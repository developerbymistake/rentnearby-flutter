import 'dart:async';
import 'dart:math' as math;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/plan_purchase_result.dart' show PlanOrder;
import '../../models/store_product.dart';
import 'billing_gateway.dart';

class PlayBillingGateway implements BillingGateway {
  static const subscriptionsUrl = 'https://play.google.com/store/account/subscriptions';

  final InAppPurchase _iap = InAppPurchase.instance;
  // Sync so a restore batch is fully delivered before restore() returns.
  final _events = StreamController<BillingEvent>.broadcast(sync: true);
  final _details = <String, GooglePlayProductDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _disposed = false;

  @override
  String get provider => 'Play';

  @override
  Stream<BillingEvent> get events => _events.stream;

  @override
  Future<void> init() async {
    if (_sub != null || _disposed) return;
    try {
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => _emit(BillingEvent(kind: BillingEventKind.error, message: e.toString())),
      );
    } catch (_) {}
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, StoreProduct>> loadProducts(Set<String> productIds) async {
    if (productIds.isEmpty) return const {};
    final res = await _iap.queryProductDetails(productIds);
    final error = res.error;
    if (error != null && res.productDetails.isEmpty) throw StateError(error.message);
    final offers = <String, List<StoreOffer>>{};
    final titles = <String, String>{};
    for (final d in res.productDetails) {
      if (d is! GooglePlayProductDetails) continue;
      final offer = _offerOf(d);
      if (offer == null) continue;
      _details[offer.offerToken] = d;
      offers.putIfAbsent(offer.productId, () => []).add(offer);
      titles[offer.productId] = d.productDetails.name;
    }
    return {
      for (final e in offers.entries)
        e.key: StoreProduct(productId: e.key, title: titles[e.key] ?? e.key, offers: List.unmodifiable(e.value)),
    };
  }

  @override
  Future<bool> launch(PlanOrder order, {StoreOffer? offer, OwnedPurchase? oldPurchase}) async {
    if (offer == null) return false;
    final details = _details[offer.offerToken];
    if (details == null) return false;
    final old = oldPurchase?.platformDetails;
    final change = old is GooglePlayPurchaseDetails
        ? ChangeSubscriptionParam(oldPurchaseDetails: old, replacementMode: _replacementMode(order.playReplacementMode))
        : null;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: details,
          applicationUserName: order.obfuscatedAccountId,
          offerToken: offer.offerToken,
          changeSubscriptionParam: change,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> restore() async {
    final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final res = await addition.queryPastPurchases();
    final error = res.error;
    if (error != null && res.pastPurchases.isEmpty) throw StateError(error.message);
    for (final p in res.pastPurchases) {
      if (p.status == PurchaseStatus.error) continue;
      final owned = _owned(p);
      if (owned == null) continue;
      _emit(BillingEvent(
        kind: BillingEventKind.restored,
        productId: owned.productId,
        purchaseToken: owned.purchaseToken,
        purchase: owned,
      ));
    }
  }

  Future<void> showInAppMessages() async {
    try {
      await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().showInAppMessages();
    } catch (_) {}
  }

  @override
  Future<bool> openManage(String? manageUrl) async {
    final uri = Uri.tryParse(manageUrl ?? subscriptionsUrl) ?? Uri.parse(subscriptionsUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    _details.clear();
    _events.close();
  }

  void _emit(BillingEvent e) {
    if (!_disposed && !_events.isClosed) _events.add(e);
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      final owned = _owned(p);
      final message = p.error?.message;
      final kind = switch (p.status) {
        PurchaseStatus.pending => BillingEventKind.pending,
        PurchaseStatus.purchased => BillingEventKind.purchased,
        PurchaseStatus.restored => BillingEventKind.restored,
        PurchaseStatus.canceled => BillingEventKind.canceled,
        PurchaseStatus.error => (message ?? '').contains('itemAlreadyOwned')
            ? BillingEventKind.alreadyOwned
            : BillingEventKind.error,
      };
      _emit(BillingEvent(
        kind: kind,
        productId: p.productID.isEmpty ? null : p.productID,
        purchaseToken: owned?.purchaseToken,
        purchase: owned,
        message: message,
      ));
    }
  }

  OwnedPurchase? _owned(PurchaseDetails p) {
    final token = p is GooglePlayPurchaseDetails
        ? p.billingClientPurchase.purchaseToken
        : p.verificationData.serverVerificationData;
    if (token.isEmpty || p.productID.isEmpty) return null;
    final orderId = p is GooglePlayPurchaseDetails ? p.billingClientPurchase.orderId : p.purchaseID;
    return OwnedPurchase(
      productId: p.productID,
      purchaseToken: token,
      orderId: (orderId == null || orderId.isEmpty) ? null : orderId,
      isAcknowledged: p is GooglePlayPurchaseDetails && p.billingClientPurchase.isAcknowledged,
      autoRenewing: p is GooglePlayPurchaseDetails && p.billingClientPurchase.isAutoRenewing,
      platformDetails: p,
    );
  }

  StoreOffer? _offerOf(GooglePlayProductDetails d) {
    final index = d.subscriptionIndex;
    final token = d.offerToken;
    final all = d.productDetails.subscriptionOfferDetails;
    if (index == null || token == null || all == null || index < 0 || index >= all.length) return null;
    final o = all[index];
    final phases = o.pricingPhases;
    if (phases.isEmpty) return null;
    final recurring = phases.last;
    var trialDays = 0;
    for (final ph in phases) {
      if (ph.priceAmountMicros == 0) trialDays += _periodDays(ph.billingPeriod) * math.max(1, ph.billingCycleCount);
    }
    return StoreOffer(
      productId: d.id,
      basePlanId: o.basePlanId,
      offerId: o.offerId,
      offerToken: token,
      price: StorePrice(
        formatted: recurring.formattedPrice,
        raw: recurring.priceAmountMicros / 1000000,
        currencyCode: recurring.priceCurrencyCode,
        billingPeriod: recurring.billingPeriod,
      ),
      isTrial: o.offerId != null && trialDays > 0,
      trialDays: trialDays,
    );
  }

  static final _isoPeriod = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$');

  static int _periodDays(String period) {
    final m = _isoPeriod.firstMatch(period);
    if (m == null) return 0;
    int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    return g(1) * 365 + g(2) * 30 + g(3) * 7 + g(4);
  }

  static ReplacementMode? _replacementMode(String? mode) => switch (mode) {
        'chargeFullPrice' => ReplacementMode.chargeFullPrice,
        'withoutProration' => ReplacementMode.withoutProration,
        'deferred' => ReplacementMode.deferred,
        _ => null,
      };
}
