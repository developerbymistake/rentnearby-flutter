import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/wallet_controller.dart';
import '../models/coin_pack_model.dart';
import '../utils/app_toast.dart';
import '../widgets/coin_credited_dialog.dart';
import '../widgets/coin_icon.dart';

/// "Buy Coins" catalog — the wallet home screen. Shows the live balance up
/// top, a grid of purchasable coin packs (tap to drive the Razorpay purchase
/// flow in-place, loading state on the tapped card), and a "Transaction
/// History" entry point into the ledger screen.
class CoinPacksScreen extends StatefulWidget {
  const CoinPacksScreen({super.key});
  @override
  State<CoinPacksScreen> createState() => _CoinPacksScreenState();
}

class _CoinPacksScreenState extends State<CoinPacksScreen> {
  final _wallet = Get.find<WalletController>();
  String? _purchasingId;

  /// Set when this screen was reached from an insufficient-balance/Add-Coins
  /// prompt mid-Go-Live (`arguments: {'returnToGoLive': true}` — see
  /// InsufficientBalanceSheet and the shared GoLivePlanSheet). When true, a
  /// successful purchase pops this screen with `result: true` instead of
  /// leaving the owner stranded here, so the caller can reopen the
  /// plan-selection sheet with the fresh balance rather than requiring a
  /// manual back-and-retry.
  bool _returnToGoLive = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) _returnToGoLive = args['returnToGoLive'] == true;
    _wallet.loadBalance();
    _wallet.loadCoinPacks();
  }

  String _formatPhone(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\s+\-()]'), '');
    if (clean.length == 10) return '+91$clean';
    if (clean.length == 12 && clean.startsWith('91')) return '+$clean';
    return raw;
  }

  Future<void> _purchase(CoinPackModel pack) async {
    if (_purchasingId != null) return;
    setState(() => _purchasingId = pack.id);

    final order = await _wallet.createOrder(pack.id);
    if (order == null) {
      if (mounted) setState(() => _purchasingId = null);
      return; // controller already toasted the reason
    }

    final completer = Completer<void>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) async {
      try {
        final orderId = response.orderId;
        final paymentId = response.paymentId;
        final signature = response.signature;
        if (orderId == null || paymentId == null || signature == null) {
          throw Exception('Invalid payment response from gateway');
        }
        final data = await _wallet.verifyPayment(
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        );
        if (mounted) {
          Get.dialog(
            CoinCreditedDialog(
              coinsCredited: (data['coinsCredited'] as num?)?.toInt() ?? pack.totalCoins,
              newBalance: (data['newBalance'] as num?)?.toInt() ?? _wallet.balance.value,
              continueLabel: _returnToGoLive ? 'Continue to Go Live' : 'Done',
              onDismiss: _returnToGoLive ? () => Get.back(result: true) : null,
            ),
            barrierDismissible: false,
          );
        }
      } catch (_) {
        AppToast.error('Payment verification failed. Please contact support if amount was deducted.');
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      _wallet.cancelOrder(order['orderId'] as String);
      if (response.code != Razorpay.PAYMENT_CANCELLED) {
        AppToast.error('Payment failed. Please try again.');
      }
      if (!completer.isCompleted) completer.complete();
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      AppToast.info('External wallet: ${response.walletName}');
    });

    try {
      final rawPhone = Get.find<AuthController>().user.value?.phoneNumber ?? '';
      razorpay.open({
        'key': order['keyId'],
        'amount': (order['amount'] as int) * 100,
        'currency': order['currency'],
        'order_id': order['orderId'],
        'name': 'Bakhli',
        'description': '${pack.totalCoins} Coins',
        'prefill': {'contact': _formatPhone(rawPhone)},
        'theme': {'color': '#1E3A8A'},
      });
      await completer.future;
    } finally {
      razorpay.clear();
      if (mounted) setState(() => _purchasingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Obx(() {
              final loading = _wallet.isLoadingPacks.value;
              final packs = _wallet.coinPacks;
              if (loading && packs.isEmpty) return _buildShimmer();
              if (packs.isEmpty) return _buildEmpty();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  _wallet.loadBalance();
                  await _wallet.loadCoinPacks();
                },
                child: ListView.separated(
                  // Single-column full-width rows (icon left, coins+bonus middle, price right,
                  // "Best Value" as a corner tag) — matches the approved mockup exactly; a 2-column
                  // grid of centered cards was never what was designed.
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: packs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _PackCard(
                    pack: packs[i],
                    isLoading: _purchasingId == packs[i].id,
                    disabled: _purchasingId != null,
                    onTap: () => _purchase(packs[i]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  ),
                  const Text('Buy Coins',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.walletLedger),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.history_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('History', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const CoinIcon(size: 22),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Your Balance', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white70)),
                      Obx(() => Text(
                            '${_wallet.balance.value} coins',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                          )),
                    ]),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.redeemCode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Redeem Code',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: const CoinIcon(size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No coin packs available',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Please check back later.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        ]),
      );

  Widget _buildShimmer() => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 78,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class _PackCard extends StatelessWidget {
  final CoinPackModel pack;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onTap;

  const _PackCard({required this.pack, required this.isLoading, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final featured = pack.isFeatured;
    // Mockup's .best-tag sits at top:-9px, pulling above the card's own border — reserve room for
    // it here rather than clipping, so it isn't cut off by the list's scroll viewport.
    return Padding(
      padding: EdgeInsets.only(top: featured ? 9 : 0),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedOpacity(
          opacity: disabled && !isLoading ? 0.5 : 1,
          duration: const Duration(milliseconds: 150),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: featured ? AppColors.primary : AppColors.divider, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: featured ? AppColors.primary.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(15),
                child: Row(children: [
                  const CoinIcon(size: 40),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${pack.totalCoins} coins',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 1),
                      Opacity(
                        opacity: pack.bonusCoins > 0 ? 1 : 0,
                        child: Text('+${pack.bonusCoins} bonus coins',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ),
                    ]),
                  ),
                  isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : Text('₹${pack.priceInr}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                ]),
              ),
              if (featured)
                Positioned(
                  top: -9,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.warning, Color(0xFFFBBF24)]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Best Value',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
