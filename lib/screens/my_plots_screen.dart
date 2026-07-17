import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/config_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';
import '../controllers/wallet_controller.dart';
import '../models/go_live_result.dart';
import '../models/plan_selection_result.dart';
import '../models/plot_model.dart';
import '../services/plot_permission_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/coin_balance_chip.dart';
import '../widgets/go_live_plan_sheet.dart';
import '../widgets/go_live_success_dialog.dart';
import '../widgets/insufficient_balance_sheet.dart';
import '../widgets/pulse_once.dart';

const _kBrown = Color(0xFF92400E);
const _kBrownDark = Color(0xFF78350F);

class MyPlotsScreen extends StatefulWidget {
  const MyPlotsScreen({super.key});
  @override
  State<MyPlotsScreen> createState() => _MyPlotsScreenState();
}

class _MyPlotsScreenState extends State<MyPlotsScreen>
    with WidgetsBindingObserver {
  final _ctrl = Get.find<PlotController>();
  final _scrollCtrl = ScrollController();
  bool _isAddingPlot = false;
  String? _goLiveLoadingId;
  Future<void> _dataReady = Future.value();
  late final _permissionService = PlotPermissionService(
    _ctrl,
    Get.find<LocationController>(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dataReady = _ctrl.loadMyPlots(reset: true).catchError((_) {});
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No longer gated on tabIndex — this screen is now a pushed route (not a
    // resident IndexedStack tab), so "app resumed while this screen is on
    // top" is itself the correct condition for a refresh.
    if (state == AppLifecycleState.resumed) {
      _dataReady = _ctrl.loadMyPlots(reset: true).catchError((_) {});
      Get.find<WalletController>().loadBalance();
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _ctrl.loadNextPage();
    }
  }

  Future<void> _refresh() => Future.wait([
        _ctrl.loadMyPlots(reset: true),
        Get.find<WalletController>().loadBalance(),
      ]);

  void _onAddPlot() async {
    if (_isAddingPlot) return;
    setState(() => _isAddingPlot = true);
    try {
      await _dataReady;
      final result = await _permissionService.check();
      if (!mounted) return;
      switch (result) {
        case PlotAllowed():
          Get.toNamed(AppRoutes.addPlot);
        case PlotNeedsDistrict():
          AppToast.error('Your area is not supported yet. Contact admin to expand coverage.');
        case PlotLimitReached():
          _showPlotLimitDialog(cap: result.cap);
      }
    } catch (_) {
      AppToast.error('Could not verify your listing limit. Please try again.');
    } finally {
      if (mounted) setState(() => _isAddingPlot = false);
    }
  }

  void _onGoLiveTap(PlotModel plot) async {
    if (_goLiveLoadingId != null) return;
    setState(() => _goLiveLoadingId = plot.id);
    try {
      final stillWithinValidity = plot.validUntil != null &&
          plot.validUntil!.toUtc().isAfter(DateTime.now().toUtc());

      if (stillWithinValidity) {
        // Free reactivation — owner turned it off, is turning it back on
        // before the previously-paid window expired. No plan dialog needed.
        final result = await _ctrl.goLivePlot(plot.id);
        if (mounted) await _handleGoLiveResult(result, spentCoins: 0);
        return;
      }

      // Loop rather than a single pass: picking "Add Coins" on an
      // unaffordable row (or hitting a 409 INSUFFICIENT_BALANCE despite the
      // client-side check, e.g. balance changed elsewhere) routes to
      // CoinPacksScreen and, on a successful purchase, comes back here to
      // reopen the plan sheet against the refreshed balance — same loading
      // state (`_goLiveLoadingId`) held the whole way through instead of a
      // fragile recursive re-entry into this method.
      while (true) {
        final plans = await _ctrl.getPlotPlans();
        if (!mounted) return;
        final selection = await GoLivePlanSheet.show(
          context,
          plans: plans,
          unitLimitKey: 'plotLimit',
          unitSingular: 'plot',
          unitPlural: 'plots',
          accentColor: _kBrown,
        );
        if (selection == null) return; // "Maybe Later" / dismissed

        if (selection is PlanSelectionAddCoins) {
          final toppedUp = await Get.toNamed(AppRoutes.coinPacks, arguments: {'returnToGoLive': true});
          if (toppedUp == true && mounted) continue;
          return;
        }

        final selectedPlan = (selection as PlanSelected).plan;
        final planType = selectedPlan['planType'] as String? ?? '';
        final price = (selectedPlan['originalPrice'] as num?)?.toInt() ?? 0;
        final result = await _ctrl.goLivePlot(plot.id, planType: planType, requiredCoins: price);
        if (!mounted) return;
        final retry = await _handleGoLiveResult(result, spentCoins: price);
        if (retry && mounted) continue;
        return;
      }
    } finally {
      if (mounted) setState(() => _goLiveLoadingId = null);
    }
  }

  /// Returns true when the caller should loop back and re-show the plan
  /// sheet (owner topped up from the insufficient-balance sheet and wants to
  /// resume), false for every other outcome.
  Future<bool> _handleGoLiveResult(GoLiveResult result, {required int spentCoins}) async {
    switch (result) {
      case GoLiveSuccess():
        Get.dialog(
          GoLiveSuccessDialog(
            isPlot: true,
            planType: result.planType,
            coinsSpent: spentCoins,
            validUntil: result.validUntil,
            onDismiss: _refresh,
          ),
          barrierDismissible: false,
        );
        return false;
      case GoLiveInsufficientBalance g:
        if (!mounted) return false;
        return InsufficientBalanceSheet.show(
          context,
          required: g.requiredCoins,
          current: Get.find<WalletController>().balance.value,
        );
      case GoLiveConcurrentUpdate g:
        AppToast.error(g.message);
        return false;
      case GoLiveFailure g:
        AppToast.error(g.message);
        return false;
    }
  }

  void _showPlotLimitDialog({required int cap}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 30, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Plot Limit Reached',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              'You can list up to $cap plot${cap > 1 ? 's' : ''}. Delete an existing plot to add a new one.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: const Text('Manage Plots',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBrown,
                  side: const BorderSide(color: _kBrown),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Each plot already carries its own validUntil/isActive (see _PlotCard's
  /// own expiry label) — this strip just shows the flat creation cap usage,
  /// sourced from ConfigController, with no separate membership call needed.
  Widget _buildPlotCapStrip() {
    final cap = Get.find<ConfigController>().plotLimit.value;
    final used = _ctrl.myPlots.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kBrown.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBrown.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.terrain_rounded, size: 13, color: _kBrown),
        const SizedBox(width: 6),
        Text('$used / $cap plots used',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                color: _kBrown, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: isDeleting ? null : const Text('Delete Plot',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            content: isDeleting
                ? const SizedBox(
                    height: 80,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.error, strokeWidth: 2.5),
                          SizedBox(height: 14),
                          Text('Deleting...',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textMedium)),
                        ],
                      ),
                    ),
                  )
                : const Text('Are you sure? This will also delete all photos.',
                    style: TextStyle(fontFamily: 'Poppins')),
            actions: isDeleting ? null : [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                onPressed: () async {
                  setDialogState(() => isDeleting = true);
                  await _ctrl.deletePlot(id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => AppLoadingOverlay(
        isLoading: _ctrl.isDeleting.value || _ctrl.isTogglingActive.value,
        message: _ctrl.isTogglingActive.value ? 'Updating...' : 'Deleting...',
        indicatorColor: _kBrown,
        child: Column(
        children: [
          _buildHeader(),
          Obx(() => _buildPlotCapStrip()),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.isLoading.value;
              final plots = _ctrl.myPlots;
              final hasMore = _ctrl.hasMorePlots.value;

              if (loading && plots.isEmpty) return _buildShimmer();
              if (plots.isEmpty) return _buildEmpty();

              return RefreshIndicator(
                color: _kBrown,
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: plots.length + (hasMore || loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == plots.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kBrown)),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PlotCard(
                        plot: plots[i],
                        onToggleActive: () => _ctrl.toggleActive(plots[i].id, plots[i].isActive),
                        onGoLive: () => _onGoLiveTap(plots[i]),
                        onDelete: () => _confirmDelete(plots[i].id),
                        isGoLiveLoading: _goLiveLoadingId == plots[i].id,
                        onReportsTap: () => Get.toNamed(AppRoutes.listingReports, arguments: {
                          'listingId': plots[i].id,
                          'listingType': 'Plot',
                          'title': plots[i].areaDisplay,
                        }),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
        ),
      )),
    );
  }

  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kBrown, _kBrownDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                    ),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('My Plots',
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('Manage your listings',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
                    ]),
                    const Spacer(),
                    const CoinBalanceChip(color: Colors.white),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _isAddingPlot ? null : _onAddPlot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: _isAddingPlot
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _kBrown),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 16, color: _kBrown),
                                SizedBox(width: 4),
                                Text('Add Plot',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _kBrown)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(color: _kBrown.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Iconsax.map, size: 40, color: _kBrown),
          ),
          const SizedBox(height: 20),
          const Text('No plots yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Add your first plot listing',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
        ]),
      );

  Widget _buildShimmer() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class _PlotCard extends StatelessWidget {
  final PlotModel plot;
  final VoidCallback onToggleActive;
  final VoidCallback onGoLive;
  final VoidCallback onDelete;
  final bool isGoLiveLoading;
  final VoidCallback? onReportsTap;

  const _PlotCard({
    required this.plot,
    required this.onToggleActive,
    required this.onGoLive,
    required this.onDelete,
    this.isGoLiveLoading = false,
    this.onReportsTap,
  });

  Color _typeColor(String type) => switch (type) {
    'Commercial'   => const Color(0xFFF59E0B),
    'Agricultural' => const Color(0xFF92400E),
    'Farmhouse'    => const Color(0xFF16A34A),
    _              => const Color(0xFF3B82F6),
  };

  Widget _buildReportAlertStrip() {
    final count = plot.pendingReportCount;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: GestureDetector(
        onTap: onReportsTap,
        child: Container(
          width: double.infinity,
          color: AppColors.reportAlert,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Iconsax.warning_2, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$count report${count == 1 ? '' : 's'} on this listing',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(plot.plotType);
    final location = [plot.cityName, plot.districtName].whereType<String>().join(', ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          if (plot.pendingReportCount > 0) _buildReportAlertStrip(),
          // Thumbnail strip with status badge overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: plot.pendingReportCount > 0 ? Radius.zero : const Radius.circular(16),
                ),
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: plot.photos.isNotEmpty
                      ? Image.network(plot.photos.first, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder())
                      : _placeholder(),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _statusBadge(),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plot.areaDisplay,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(plot.plotType,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: typeColor)),
                    ),
                  ],
                ),

                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 13, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(location,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (plot.validUntil != null) ...[
                        const SizedBox(width: 8),
                        _expiryLabel(plot.validUntil!),
                      ],
                    ],
                  ),
                ],

                if (plot.address != null && plot.address!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(plot.address!,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                Row(
                  children: [
                    if (plot.isActive) ...[
                      // Active: show deactivate switch
                      const Text('Live',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981))),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: true,
                          onChanged: (_) => onToggleActive(),
                          activeThumbColor: const Color(0xFF10B981),
                          activeTrackColor: const Color(0xFFD1FAE5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ] else ...[
                      // Inactive: show "Make it Live" button
                      PulseOnce(
                        child: GestureDetector(
                        onTap: isGoLiveLoading ? null : onGoLive,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isGoLiveLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('Make it Live',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white)),
                                  ],
                                ),
                        ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Delete button
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                            const SizedBox(width: 4),
                            Text('Delete',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    final isLive = plot.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLive
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            isLive ? 'LIVE' : 'OFFLINE',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _expiryLabel(DateTime validUntil) {
    final days = validUntil.toUtc().difference(DateTime.now().toUtc()).inDays;
    final String label;
    final Color color;
    if (days > 3) {
      label = '$days days left';
      color = AppColors.textHint;
    } else if (days > 0) {
      label = '$days day${days == 1 ? '' : 's'} left';
      color = const Color(0xFFF59E0B);
    } else if (days == 0) {
      label = 'Expires today';
      color = AppColors.error;
    } else {
      label = 'Expired';
      color = AppColors.error;
    }
    return Text(
      label,
      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: color, fontWeight: FontWeight.w500),
    );
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF92400E), Color(0xFF78350F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(child: Icon(Icons.terrain_rounded, size: 40, color: Colors.white54)),
      );
}
