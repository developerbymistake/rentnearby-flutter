import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/wallet_controller.dart';
import '../utils/input_formatters.dart';
import '../widgets/coin_credited_dialog.dart';
import '../widgets/gradient_button.dart';

/// Simple text-field + submit screen for redeeming a promo/coupon code —
/// calls WalletController.redeemCode and shows the same coin-credited
/// success moment as a coin-pack purchase on success. Errors surface via
/// AppToast (WalletController.redeemCode already toasts the exact
/// server-provided message), matching this app's existing error-display
/// convention rather than an inline error box.
class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({super.key});
  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _wallet = Get.find<WalletController>();
  final _codeCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final data = await _wallet.redeemCode(code);
      if (data == null || !mounted) return; // controller already toasted the reason

      final campaignLabel = data['campaignLabel'] as String?;
      Get.dialog(
        CoinCreditedDialog(
          coinsCredited: (data['coinsCredited'] as num?)?.toInt() ?? 0,
          newBalance: (data['newBalance'] as num?)?.toInt() ?? _wallet.balance.value,
          title: campaignLabel != null && campaignLabel.isNotEmpty ? campaignLabel : 'Code Redeemed!',
          onDismiss: () => _codeCtrl.clear(),
        ),
        barrierDismissible: false,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Have a code?',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        const Text('Enter a promo or redeem code to add coins to your wallet.',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, height: 1.5)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _codeCtrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: redeemCodeInputFormatters,
                          onSubmitted: (_) => _submit(),
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 3),
                          decoration: InputDecoration(
                            hintText: 'ENTER CODE',
                            hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 15, letterSpacing: 2, color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.redeem_rounded, color: AppColors.primaryLight, size: 20),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GradientButton(
                          label: 'Redeem',
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textLight),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Each code can only be redeemed once per account.',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Text('Redeem Code',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
