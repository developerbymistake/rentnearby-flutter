import 'dart:async';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/auth_controller.dart';
import '../../models/plan_purchase_result.dart' show PlanOrder;
import '../../models/store_product.dart';
import '../../utils/app_toast.dart';
import 'billing_gateway.dart';

class RazorpayGateway implements BillingGateway {
  final _events = StreamController<BillingEvent>.broadcast();
  Completer<PaymentSuccessResponse?>? _checkout;
  bool _disposed = false;

  @override
  String get provider => 'Razorpay';

  @override
  Stream<BillingEvent> get events => _events.stream;

  @override
  Future<void> init() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, StoreProduct>> loadProducts(Set<String> productIds) async => const {};

  @override
  Future<bool> launch(PlanOrder order, {StoreOffer? offer, OwnedPurchase? oldPurchase}) async {
    final paid = await checkout(order);
    if (!_disposed && !_events.isClosed) {
      _events.add(BillingEvent(
        kind: paid == null ? BillingEventKind.canceled : BillingEventKind.purchased,
        purchaseToken: paid?.paymentId,
      ));
    }
    return true;
  }

  @override
  Future<void> restore() async {}

  @override
  Future<bool> openManage(String? manageUrl) async {
    final uri = manageUrl == null ? null : Uri.tryParse(manageUrl);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<PaymentSuccessResponse?> checkout(PlanOrder order) async {
    final completer = Completer<PaymentSuccessResponse?>();
    _checkout = completer;
    final razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!completer.isCompleted) completer.complete(r);
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (r.code != Razorpay.PAYMENT_CANCELLED) AppToast.error('Payment failed. Try again.');
      if (!completer.isCompleted) completer.complete(null);
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      AppToast.info('External wallet: ${r.walletName}');
    });
    try {
      final phone = Get.find<AuthController>().user.value?.phoneNumber ?? '';
      razorpay.open({
        'key': order.keyId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'order_id': order.razorpayOrderId,
        'name': 'Bakhli',
        'description': order.planName,
        'prefill': {'contact': _formatPhone(phone)},
        'theme': {'color': '#1E3A8A'},
      });
      return await completer.future;
    } catch (_) {
      AppToast.error('Could not open payment. Try again.');
      return null;
    } finally {
      _checkout = null;
      razorpay.clear();
    }
  }

  String _formatPhone(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\s+\-()]'), '');
    if (clean.length == 10) return '+91$clean';
    if (clean.length == 12 && clean.startsWith('91')) return '+$clean';
    return raw;
  }

  void onAppResumed() {
    final c = _checkout;
    if (c == null) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (!c.isCompleted) c.complete(null);
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final c = _checkout;
    if (c != null && !c.isCompleted) c.complete(null);
    _events.close();
  }
}
