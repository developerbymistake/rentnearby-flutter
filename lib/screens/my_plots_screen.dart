import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_shadows.dart';
import '../controllers/config_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';
import '../controllers/wallet_controller.dart';
import '../models/go_live_result.dart';
import '../models/plan_selection_result.dart';
import '../models/plot_model.dart';
import '../services/listing_share_service.dart';
import '../services/plot_permission_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/go_live_plan_sheet.dart';
import '../widgets/go_live_submitted_dialog.dart';
import '../widgets/go_live_success_dialog.dart';
import '../widgets/insufficient_balance_sheet.dart';
import '../widgets/listing_limit_reached_sheet.dart';
import '../widgets/pulse_once.dart';

const _kBrown = AppColors.plot;

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
    _dataReady = _ctrl.loadMyPlots(reset: true).catchError((_) => false);
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
      _dataReady = _ctrl.loadMyPlots(reset: true).catchError((_) => false);
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
        Get.find<WalletController>().loadBalance(forceRefresh: true),
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
          ListingLimitReachedSheet.show(context, cap: result.cap, unitSingular: 'plot', unitPlural: 'plots', accent: AppColors.plot);
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
      final paymentEnabled = Get.find<ConfigController>().paymentEnabled.value;

      if (stillWithinValidity || !paymentEnabled) {
        // Free reactivation — owner turned it off, is turning it back on
        // before the previously-paid window expired. Also taken whenever the
        // payment kill switch is off, regardless of validity, since the
        // backend accepts a null-planType go-live for free in that case. No
        // plan dialog needed either way.
        final result = await _ctrl.goLivePlot(plot.id);
        if (mounted) await _handleGoLiveResult(result, spentCredits: 0);
        return;
      }

      // Loop rather than a single pass: picking "Add Credits" on an
      // unaffordable row (or hitting a 409 INSUFFICIENT_BALANCE despite the
      // client-side check, e.g. balance changed elsewhere) routes to
      // CreditPacksScreen and, on a successful purchase, comes back here to
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

        if (selection is PlanSelectionAddCredits) {
          final toppedUp = await Get.toNamed(AppRoutes.creditPacks, arguments: {'returnToGoLive': true});
          if (toppedUp == true && mounted) continue;
          return;
        }

        final selectedPlan = (selection as PlanSelected).plan;
        final planType = selectedPlan['planType'] as String? ?? '';
        final price = (selectedPlan['originalPrice'] as num?)?.toInt() ?? 0;
        final result = await _ctrl.goLivePlot(plot.id, planType: planType, requiredCredits: price);
        if (!mounted) return;
        final retry = await _handleGoLiveResult(result, spentCredits: price);
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
  Future<bool> _handleGoLiveResult(GoLiveResult result, {required int spentCredits}) async {
    switch (result) {
      case GoLiveSuccess():
        Get.dialog(
          GoLiveSuccessDialog(
            isPlot: true,
            planType: result.planType,
            creditsSpent: spentCredits,
            validUntil: result.validUntil,
            onDismiss: _refresh,
          ),
          barrierDismissible: false,
        );
        return false;
      case GoLiveSubmittedForReview():
        Get.dialog(
          GoLiveSubmittedDialog(
            isPlot: true,
            creditsSpent: result.creditsSpent,
            onDismiss: _refresh,
          ),
          barrierDismissible: false,
        );
        return false;
      case GoLiveInsufficientBalance g:
        if (!mounted) return false;
        return InsufficientBalanceSheet.show(
          context,
          required: g.requiredCredits,
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

  // Credits are only "at risk" while the paid ValidUntil window hasn't lapsed yet — reactivating
  // within that window is free, so a paused (isActive: false) listing can still be sitting on
  // unused paid days that a delete would forfeit. isActive alone would miss that case.
  bool _hasUnusedPaidWindow(PlotModel plot) =>
      plot.validUntil != null && plot.validUntil!.isAfter(DateTime.now());

  Future<void> _shareListing(BuildContext ctx, PlotModel plot) async {
    _ctrl.isSharing.value = true;
    try {
      await shareListing(
        context: ctx,
        type: 'p',
        slug: plot.slug!,
        photoUrl: plot.photos.isNotEmpty ? plot.photos.first : null,
        priceOrArea: plot.areaDisplay,
        typeLabel: plot.plotType,
        locality: [plot.cityName, plot.districtName].whereType<String>().join(', '),
      );
    } finally {
      _ctrl.isSharing.value = false;
    }
  }

  void _confirmDelete(String id, bool hasUnusedPaidWindow) {
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
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Are you sure? This will also delete all photos.',
                          style: TextStyle(fontFamily: 'Poppins')),
                      if (hasUnusedPaidWindow) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You still have unused paid days on this listing. Deleting it '
                                  'will not refund the credits you spent — they will be lost.',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.5,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
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
        isLoading: _ctrl.isDeleting.value || _ctrl.isTogglingActive.value || _ctrl.isSharing.value,
        message: _ctrl.isSharing.value
            ? 'Sharing...'
            : (_ctrl.isTogglingActive.value ? 'Updating...' : 'Deleting...'),
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
                        onDelete: () => _confirmDelete(plots[i].id, _hasUnusedPaidWindow(plots[i])),
                        isGoLiveLoading: _goLiveLoadingId == plots[i].id,
                        onReportsTap: () => Get.toNamed(AppRoutes.listingReports, arguments: {
                          'listingId': plots[i].id,
                          'listingType': 'Plot',
                          'title': plots[i].areaDisplay,
                        }),
                        onPreview: () => Get.toNamed(AppRoutes.plotDetail, arguments: {'id': plots[i].id}),
                        onShare: (plots[i].isActive && plots[i].slug != null)
                            ? () => _shareListing(context, plots[i])
                            : null,
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
          gradient: AppColors.plotGradient,
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
                    GestureDetector(
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
                  ],
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
        itemBuilder: (_, _) => Shimmer.fromColors(
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
  final VoidCallback? onPreview;
  final VoidCallback? onShare;

  const _PlotCard({
    required this.plot,
    required this.onToggleActive,
    required this.onGoLive,
    required this.onDelete,
    this.isGoLiveLoading = false,
    this.onReportsTap,
    this.onPreview,
    this.onShare,
  });

  Color _typeColor(String type) => switch (type) {
    'Commercial'   => const Color(0xFFF59E0B),
    'Agricultural' => AppColors.plot,
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
    final location = [plot.districtName, plot.cityName].whereType<String>().join(', ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.premium(typeColor, alpha: 0.10, blur: 16, offset: const Offset(0, 6)),
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

                if (location.isNotEmpty || plot.validUntil != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (location.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Locality'),
                              const SizedBox(height: 3),
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
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (plot.validUntil != null) ...[
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Expires in'),
                            const SizedBox(height: 3),
                            _expiryLabel(plot.validUntil!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],

                if (plot.address != null && plot.address!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Address'),
                      const SizedBox(height: 3),
                      Text(plot.address!,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                _buildActionsRow(),
              ],
            ),
          ),
          if (plot.isRejected) _buildRejectionStrip(),
        ],
      ),
    );
  }

  // Whichever of these mutually-exclusive Live-state widgets applies becomes the row's
  // first cell — always exactly one, since isActive/isPendingReview/isRejected/(neither)
  // is an exhaustive chain.
  Widget _stateWidget() {
    if (plot.isActive) {
      // Stacked (switch above, label below) to match the other three cells' icon-above-label
      // shape — a horizontal Text+Switch pair needs more width than an equal 1/4 column has.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: true,
              onChanged: (_) => onToggleActive(),
              activeThumbColor: const Color(0xFF10B981),
              activeTrackColor: const Color(0xFFD1FAE5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 2),
          const Text('Live',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981))),
        ],
      );
    } else if (!plot.isPendingReview && !plot.isRejected) {
      // Inactive (and never submitted, or previously approved and now expired): show
      // "Make it Live" button. Pending/Rejected must not resurrect a request the backend
      // has no resubmit path for.
      return PulseOnce(
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
      );
    } else if (plot.isPendingReview) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.clock, size: 14, color: Color(0xFFD97706)),
            SizedBox(width: 6),
            Text('In Review',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706))),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.close_circle, size: 14, color: AppColors.error),
            SizedBox(width: 6),
            Text('Rejected',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error)),
          ],
        ),
      );
    }
  }

  Widget _buildActionsRow() {
    final cells = <Widget>[
      FittedBox(fit: BoxFit.scaleDown, child: _stateWidget()),
      if (onPreview != null)
        _actionCell(icon: Iconsax.eye, label: 'View', color: AppColors.primary, onTap: onPreview),
      if (onShare != null)
        _actionCell(icon: Icons.share_rounded, label: 'Share', color: AppColors.primary, onTap: onShare),
      _actionCell(icon: Icons.delete_outline_rounded, label: 'Delete', color: AppColors.error, onTap: onDelete),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.divider),
            Expanded(child: cells[i]),
          ],
        ],
      ),
    );
  }

  // One equal-width cell of the actions row: icon above a visible text label, whole
  // cell tappable (not just the icon/text glyphs).
  Widget _actionCell({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionStrip() {
    final reason = plot.rejectionReason;
    final text = reason != null && reason.isNotEmpty ? 'Rejected: $reason' : 'Rejected';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        width: double.infinity,
        color: AppColors.error,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge() {
    final String label;
    final List<Color> colors;
    if (plot.isActive) {
      label = 'LIVE';
      colors = [const Color(0xFF10B981), const Color(0xFF059669)];
    } else {
      label = 'OFFLINE';
      colors = [const Color(0xFF94A3B8), const Color(0xFF64748B)];
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
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
            label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.textHint,
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
          gradient: AppColors.plotGradient,
        ),
        child: const Center(child: Icon(Icons.terrain_rounded, size: 40, color: Colors.white54)),
      );
}
