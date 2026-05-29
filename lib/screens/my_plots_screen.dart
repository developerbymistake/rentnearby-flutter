import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';
import '../services/plot_permission_service.dart';
import '../models/plot_model.dart';
import '../utils/app_toast.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/payment_success_dialog.dart';

const _kBrown = Color(0xFF92400E);
const _kBrownDark = Color(0xFF78350F);

class MyPlotsScreen extends StatefulWidget {
  const MyPlotsScreen({super.key});
  @override
  State<MyPlotsScreen> createState() => _MyPlotsScreenState();
}

class _MyPlotsScreenState extends State<MyPlotsScreen> {
  final _ctrl = Get.find<PlotController>();
  final _auth = Get.find<AuthController>();
  final _scrollCtrl = ScrollController();
  Worker? _tabWorker;
  late final _permissionService = PlotPermissionService(
    _ctrl,
    _auth,
    Get.find<LocationController>(),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.loadMyPlots(reset: true);
    _scrollCtrl.addListener(_onScroll);
    _tabWorker = ever(_auth.tabIndex, (int idx) {
      if (idx == 3 && !_ctrl.isLoading.value) _refresh();
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _ctrl.loadNextPage();
    }
  }

  Future<void> _refresh() => _ctrl.loadMyPlots(reset: true);

  void _onAddPlot() async {
    PlotPermissionResult result;
    try {
      result = await _permissionService.check();
    } catch (_) {
      AppToast.info('Adding plot...');
      Get.toNamed(AppRoutes.addPlot);
      return;
    }
    if (!mounted) return;
    switch (result) {
      case PlotAllowed():
        Get.toNamed(AppRoutes.addPlot);
      case PlotNeedsDistrict():
        AppToast.error('Your area is not supported yet. Contact admin to expand coverage.');
      case PlotNeedsName():
        _showNameDialog();
      case PlotNeedsPhoneVerification():
        _showPhoneVerificationRequired();
      case PlotShowLimitDialog():
        _showPlotLimitDialog(maxPlots: result.maxPlots, hasPlan: result.hasPlan);
      case PlotShowUpgradeSheet():
        _showPaidUpgradePlotSheet();
    }
  }

  void _showPhoneVerificationRequired() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.phone_android_rounded, color: AppColors.warning, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Mobile verification required',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('You need to verify your mobile number before posting a plot.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _auth.tabIndex.value = 4;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Go to Profile', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showNameDialog() {
    final nameCtrl = TextEditingController();
    bool saving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (ctx, setDialogState) {
        Future<void> save() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) { AppToast.error('Please enter your name.'); return; }
          setDialogState(() => saving = true);
          final ok = await _auth.updateProfile(name);
          if (ok) {
            if (ctx.mounted) { Navigator.pop(ctx); Get.toNamed(AppRoutes.addPlot); }
          } else {
            setDialogState(() => saving = false);
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Enter Your Name',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your name is shown to interested buyers. Please add it before listing.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Full name',
                  hintStyle: const TextStyle(fontFamily: 'Poppins', color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.person_rounded, color: _kBrown, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBrown, width: 1.5)),
                ),
                onSubmitted: (_) => save(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () { nameCtrl.dispose(); Navigator.pop(ctx); },
              child: const Text('Later', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrown,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
          ],
        );
      }),
    );
  }

  void _showPaymentDialog(String plotId) async {
    final paymentEnabled = await _ctrl.isPlotPaymentFeatureEnabled();
    if (!paymentEnabled) {
      await _ctrl.toggleActive(plotId, false);
      AppToast.success('Plot is now LIVE!');
      return;
    }

    final membership = await _ctrl.getPlotMembershipStatus();
    final hasMembership = membership != null && (membership['hasMembership'] == true);
    final canActivate = (membership ?? {})['canActivate'] as bool? ?? false;

    if (hasMembership && canActivate) {
      // Existing membership with capacity — just toggle active directly
      await _ctrl.toggleActive(plotId, false);
      AppToast.success('Plot is now LIVE! 🎉');
      return;
    }

    if (hasMembership && !canActivate) {
      final maxPlots = (membership['maxPlots'] as num?)?.toInt() ?? 0;
      final planType = membership['planType'] as String? ?? '';
      final plans = await _ctrl.getPlotPlans();
      final currentPlan = plans.firstWhereOrNull((p) => p['planType'] == planType);
      final currentPlanIsFree = currentPlan == null || (currentPlan['price'] as num? ?? 0) == 0;
      if (currentPlanIsFree) {
        final paidPlan = plans.firstWhereOrNull((p) => (p['price'] as num? ?? 0) > 0);
        if (!mounted) return;
        await Get.toNamed(AppRoutes.paymentScreen, arguments: {
          'isPlot': true,
          'plotId': plotId,
          'plan': paidPlan ?? {'planType': 'PAID', 'price': 99, 'days': 30, 'plotLimit': 2},
        });
        _ctrl.loadMyPlots(reset: true);
      } else {
        if (mounted) _showPlotLimitDialog(maxPlots: maxPlots, hasPlan: true);
      }
      return;
    }

    final hasUsedFreePlot = _auth.user.value?.hasUsedFreePlotPlan ?? false;
    if (hasUsedFreePlot) {
      if (mounted) _showPaidUpgradePlotSheet(plotId: plotId);
      return;
    }

    final plans = await _ctrl.getPlotPlans();
    if (!mounted) return;

    final selectedPlan = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PlotPlanSelectionSheet(
        plans: plans,
        hasUsedFreePlotPlan: false,
      ),
    );

    if (selectedPlan == null) return;

    final isFree = (selectedPlan['price'] as num? ?? 0) == 0;
    if (isFree) {
      await _activateFreePlotPlanDirect(plotId, selectedPlan);
      return;
    }

    if (!mounted) return;
    await Get.toNamed(AppRoutes.paymentScreen, arguments: {
      'isPlot': true,
      'plotId': plotId,
      'plan': selectedPlan,
    });
    _ctrl.loadMyPlots(reset: true);
  }

  void _showPaidUpgradePlotSheet({String plotId = ''}) async {
    final plans = await _ctrl.getPlotPlans();
    final paidPlans = plans.where((p) => (p['price'] as num? ?? 0) > 0).toList()
      ..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0));

    if (!mounted) return;

    String? selectedType = paidPlans.isNotEmpty ? (paidPlans.first['planType'] as String? ?? '') : null;

    const golden = Color(0xFFD4A017);
    final screenH = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final selectedPlan = paidPlans.isNotEmpty
              ? paidPlans.firstWhere((p) => p['planType'] == selectedType, orElse: () => paidPlans.first)
              : null;
          final selOrigPrice = (selectedPlan?['originalPrice'] as num?)?.toInt() ?? 0;
          final btnLabel = selOrigPrice == 0 ? 'Activate FREE' : 'Continue  ₹$selOrigPrice';

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 36),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenH * 0.78),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 52, 20, 4),
                          child: Column(children: [
                            const Text('Upgrade Your Plan',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            const Text('Choose a plan to add more plots',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                                textAlign: TextAlign.center),
                          ]),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: paidPlans.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No plans available.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight), textAlign: TextAlign.center),
                                  )
                                : Column(
                                    children: paidPlans.map((p) {
                                      final normalPrice = (p['price'] as num?)?.toInt() ?? 0;
                                      final origPrice = (p['originalPrice'] as num?)?.toInt() ?? 0;
                                      final disc = (p['discountPercent'] as num?)?.toInt() ?? 0;
                                      final hasDiscount = disc > 0 && normalPrice > 0;
                                      final days = (p['days'] as num?)?.toInt() ?? 30;
                                      final plots = (p['plotLimit'] as num?)?.toInt() ?? 2;
                                      final raw = (p['planType'] as String? ?? '');
                                      final label = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
                                      final isSelected = selectedType == raw;
                                      final displayPrice = origPrice == 0 ? 'FREE' : '₹$origPrice';

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: GestureDetector(
                                          onTap: () => setS(() => selectedType = raw),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isSelected ? golden.withValues(alpha: 0.04) : Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected ? golden : AppColors.divider,
                                                width: isSelected ? 2 : 1.5,
                                              ),
                                            ),
                                            child: Row(children: [
                                              Container(
                                                width: 22, height: 22,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: isSelected ? golden : AppColors.textLight, width: 2),
                                                ),
                                                child: isSelected
                                                    ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: golden)))
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Row(children: [
                                                  Text('$label Plan',
                                                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                                  if (hasDiscount) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)),
                                                      child: Text('$disc% Savings',
                                                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                                                    ),
                                                  ],
                                                ]),
                                                Text('Valid for $days days • $plots plot${plots > 1 ? 's' : ''}',
                                                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                                              ])),
                                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                                if (hasDiscount)
                                                  Text('₹$normalPrice',
                                                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, decoration: TextDecoration.lineThrough)),
                                                Text(displayPrice,
                                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700,
                                                        color: origPrice == 0 ? AppColors.success : _kBrown)),
                                              ]),
                                            ]),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: Column(children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: selectedPlan == null ? null : () {
                                  Navigator.pop(ctx);
                                  Get.toNamed(AppRoutes.paymentScreen, arguments: {'isPlot': true, 'plotId': plotId, 'plan': selectedPlan});
                                  _ctrl.loadMyPlots(reset: true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBrown, foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: Text(btnLabel, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Maybe Later', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight, fontSize: 13)),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _kBrown,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: _kBrown.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Text('B', style: TextStyle(fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPlotLimitDialog({required int maxPlots, required bool hasPlan}) {
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
              hasPlan
                  ? 'Your current plan allows up to $maxPlots plot${maxPlots > 1 ? 's' : ''}. Delete an existing plot to add a new one.'
                  : 'Free plan allows 1 plot. Delete your existing plot to replace it, or go live with a Premium plan to add more.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!hasPlan) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); _showPaidUpgradePlotSheet(); },
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Upgrade Plan',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.list_alt_rounded, size: 16),
                  label: const Text('Manage Plots',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else
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

  Future<void> _activateFreePlotPlanDirect(String plotId, Map<String, dynamic> plan) async {
    final planType = plan['planType'] as String? ?? 'FREE';
    final result = await _ctrl.activatePlotPlan(plotId, planType);
    if (result == null) {
      AppToast.error('Could not activate plot. Please try again.');
      return;
    }
    await _ctrl.loadMyPlots(reset: true);
    if (!mounted) return;
    Get.dialog(
      PaymentSuccessDialog(
        planType: planType,
        daysValid: (plan['days'] as num?)?.toInt() ?? 2,
        maxRooms: 0,
        maxPlots: (plan['plotLimit'] as num?)?.toInt() ?? 1,
        isPlot: true,
        onDismiss: () {
          Get.find<AuthController>().tabIndex.value = 3;
        },
      ),
      barrierDismissible: false,
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Plot', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Are you sure? This will also delete all photos.',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () { Navigator.pop(context); _ctrl.deletePlot(id); },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
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
                        onGoLive: () => _showPaymentDialog(plots[i].id),
                        onDelete: () => _confirmDelete(plots[i].id),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Plots',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Manage your listings',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
                ]),
                const Spacer(),
                GestureDetector(
                  onTap: _onAddPlot,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Row(
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

  const _PlotCard({
    required this.plot,
    required this.onToggleActive,
    required this.onGoLive,
    required this.onDelete,
  });

  Color _typeColor(String type) => switch (type) {
    'Commercial'   => const Color(0xFFF59E0B),
    'Agricultural' => const Color(0xFF92400E),
    _              => const Color(0xFF3B82F6),
  };

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
          // Thumbnail strip with status badge overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: plot.photos.isNotEmpty
                      ? Image.network(plot.photos.first, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
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
                          activeColor: const Color(0xFF10B981),
                          activeTrackColor: const Color(0xFFD1FAE5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ] else ...[
                      // Inactive: show "Make it Live" button
                      GestureDetector(
                        onTap: onGoLive,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rocket_launch_rounded, size: 14, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text('Make it Live',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981))),
                            ],
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

class _PlotPlanSelectionSheet extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final bool hasUsedFreePlotPlan;

  const _PlotPlanSelectionSheet({required this.plans, required this.hasUsedFreePlotPlan});

  String _label(Map<String, dynamic> p) {
    final raw = (p['planType'] as String? ?? '');
    if (raw.isEmpty) return '';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final freePlans = plans.where((p) => (p['price'] as num? ?? 0) == 0).toList();
    final paidPlans = plans.where((p) => (p['price'] as num? ?? 0) > 0).toList()
      ..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));

    final tiles = <Widget>[];

    if (!hasUsedFreePlotPlan) {
      for (final p in freePlans) {
        final days = (p['days'] as num?)?.toInt() ?? 2;
        final plots = (p['plotLimit'] as num?)?.toInt() ?? 1;
        tiles.add(_planTile(
          context,
          plan: p,
          title: '${_label(p)} Plan',
          subtitle: '$days days • $plots plot${plots > 1 ? 's' : ''}',
          price: 'Free',
          icon: Icons.star_rounded,
          color: const Color(0xFF92400E),
        ));
        tiles.add(const SizedBox(height: 12));
      }
    }

    for (int i = 0; i < paidPlans.length; i++) {
      final p = paidPlans[i];
      final days = (p['days'] as num?)?.toInt() ?? 30;
      final plots = (p['plotLimit'] as num?)?.toInt() ?? 1;
      final price = (p['price'] as num?)?.toInt() ?? 0;
      tiles.add(_planTile(
        context,
        plan: p,
        title: '${_label(p)} Plan',
        subtitle: '$days days • $plots plot${plots > 1 ? 's' : ''}',
        price: '₹$price',
        icon: Icons.flash_on_rounded,
        color: _kBrown,
        isHighlighted: hasUsedFreePlotPlan && i == 0,
      ));
      if (i < paidPlans.length - 1) tiles.add(const SizedBox(height: 12));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Make Plot Live',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          Text('Choose a plan to activate your plot',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Poppins')),
          const SizedBox(height: 20),
          ...tiles,
        ],
      ),
    );
  }

  Widget _planTile(
    BuildContext context, {
    required Map<String, dynamic> plan,
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required Color color,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, plan),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isHighlighted ? color : color.withValues(alpha: 0.3),
            width: isHighlighted ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isHighlighted ? color.withValues(alpha: 0.05) : Colors.grey[50],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'Poppins')),
                ],
              ),
            ),
            Text(price,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}
