import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/wallet_controller.dart';
import '../models/coin_transaction_model.dart';
import '../utils/app_date_format.dart';

/// Earned/Spent are a pure client-side partition of `amount > 0` vs
/// `amount < 0` on whatever page(s) of the paginated ledger are already
/// loaded — `CoinTransactionModel.amount` is already signed, and "Earned"
/// legitimately spans several backend reason codes (RECHARGE, COUPON_REDEEM,
/// WELCOME_BONUS, ADMIN_CREDIT) so a single-reason backend filter wouldn't
/// be correct anyway. Only "All" ever needs a network fetch (which already
/// happens by default on load) — switching tabs never re-fetches.
enum _LedgerFilter { all, earned, spent }

/// Paginated list of the user's own wallet transactions — infinite scroll,
/// mirroring my_listings_screen.dart's pattern. Each row shows the reason
/// label/icon, signed amount (green credit / dark debit), date, and note
/// when present (admin adjustments always have one).
class WalletLedgerScreen extends StatefulWidget {
  const WalletLedgerScreen({super.key});
  @override
  State<WalletLedgerScreen> createState() => _WalletLedgerScreenState();
}

class _WalletLedgerScreenState extends State<WalletLedgerScreen> {
  final _wallet = Get.find<WalletController>();
  final _scrollCtrl = ScrollController();
  _LedgerFilter _filter = _LedgerFilter.all;

  List<CoinTransactionModel> _applyFilter(List<CoinTransactionModel> items) {
    switch (_filter) {
      case _LedgerFilter.all:
        return items;
      case _LedgerFilter.earned:
        return items.where((t) => t.amount > 0).toList();
      case _LedgerFilter.spent:
        return items.where((t) => t.amount < 0).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _wallet.loadTransactions(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _wallet.loadNextTransactionsPage();
    }
  }

  Future<void> _refresh() => _wallet.loadTransactions(reset: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterTabs(),
          Expanded(
            child: Obx(() {
              final loading = _wallet.isLoadingTransactions.value;
              final rawItems = _wallet.transactions;
              final items = _applyFilter(rawItems);
              final hasMore = _wallet.hasMoreTransactions.value;

              if (loading && rawItems.isEmpty) return _buildShimmer();
              if (rawItems.isEmpty) return _buildEmpty();
              if (items.isEmpty) return _buildFilterEmpty();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: items.length + (hasMore || loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      );
                    }
                    return _TransactionTile(txn: items[i], dateText: AppDateFormat.dateTime(items[i].createdAt));
                  },
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
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Transaction History',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                Obx(() => Text('Balance: ${_wallet.balance.value} coins',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(children: [
        _filterTab('All', _LedgerFilter.all),
        const SizedBox(width: 8),
        _filterTab('Earned', _LedgerFilter.earned),
        const SizedBox(width: 8),
        _filterTab('Spent', _LedgerFilter.spent),
      ]),
    );
  }

  Widget _filterTab(String label, _LedgerFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textMedium)),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.primaryLight),
          ),
          const SizedBox(height: 20),
          const Text('No transactions yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Your coin activity will show up here.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        ]),
      );

  Widget _buildFilterEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(Icons.filter_alt_off_rounded, size: 40, color: AppColors.primaryLight),
          ),
          const SizedBox(height: 20),
          Text(_filter == _LedgerFilter.earned ? 'No earned coins yet' : 'No spends yet',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Switch tabs or pull to refresh.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        ]),
      );

  Widget _buildShimmer() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 68,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

class _TransactionTile extends StatelessWidget {
  final CoinTransactionModel txn;
  final String dateText;

  const _TransactionTile({required this.txn, required this.dateText});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final amountColor = isCredit ? AppColors.success : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: amountColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(CoinTransactionModel.icon(txn.reason), size: 18, color: amountColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CoinTransactionModel.label(txn.reason),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(dateText, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                if (txn.note != null && txn.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(txn.note!,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMedium, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isCredit ? '+' : ''}${txn.amount}',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: amountColor)),
              const SizedBox(height: 2),
              Text('Bal: ${txn.balanceAfter}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }
}
