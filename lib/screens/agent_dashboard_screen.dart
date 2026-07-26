import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/agent_controller.dart';
import '../models/agent_stats_model.dart';

/// Reached from Profile's AGENT section. Current-year snapshot only, no year switcher — that's the
/// admin Agent Stats page's feature (see APP_TOUR_FEATURE-style plan doc). Pure display: no actions
/// here beyond the "View My Leads" jump, since acting on a lead happens on My Leads/Lead Detail.
class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  final _agentCtrl = Get.find<AgentController>();

  @override
  void initState() {
    super.initState();
    _agentCtrl.loadMyStats();
  }

  Future<void> _refresh() => _agentCtrl.loadMyStats();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: Obx(() {
                final loading = _agentCtrl.isLoadingStats.value;
                final stats = _agentCtrl.stats.value;

                if (loading && stats == null) return _buildShimmer();

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPendingCard(),
                      const SizedBox(height: 4),
                      if (stats != null) ...[
                        _buildSectionLabel('This month'),
                        _buildKpiRow(stats),
                        const SizedBox(height: 4),
                        _buildStatusBreakdown(stats),
                      ],
                      _buildViewLeadsCta(),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dashboard',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  Obx(() {
                    final name = _agentCtrl.stats.value?.agentName;
                    return Text(
                      name != null && name.isNotEmpty ? 'Welcome back, $name' : 'Your leads at a glance',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Same recipe as ProfileScreen._buildWalletCard — the hero-card idiom this app already uses.
  Widget _buildPendingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Iconsax.notification_status, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pending Leads', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                const SizedBox(height: 3),
                Obx(() => Text('${_agentCtrl.pendingLeadCount.value}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark))),
              ],
            ),
          ),
          Obx(() => _agentCtrl.pendingLeadCount.value > 0
              ? const Text('Needs your attention',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.warning))
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 20, 8),
        child: Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.6)),
      );

  Widget _buildKpiRow(AgentLeadStatsModel stats) {
    final month = stats.currentMonth;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _kpiTile(icon: Icons.add_rounded, iconColor: AppColors.primaryLight, value: month.submitted, label: 'New leads')),
          const SizedBox(width: 10),
          Expanded(child: _kpiTile(icon: Iconsax.call, iconColor: AppColors.warning, value: month.contacted, label: 'Contacted')),
          const SizedBox(width: 10),
          Expanded(child: _kpiTile(icon: Icons.check_rounded, iconColor: AppColors.success, value: month.closed, label: 'Closed')),
        ],
      ),
    );
  }

  Widget _kpiTile({required IconData icon, required Color iconColor, required int value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(AgentLeadStatsModel stats) {
    final total = stats.totalLeads == 0 ? 1 : stats.totalLeads; // avoid divide-by-zero on an empty year
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${stats.year} status breakdown',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
          const SizedBox(height: 12),
          _barRow('Submitted', stats.totalSubmitted, total, AppColors.warning),
          const SizedBox(height: 10),
          _barRow('Contacted', stats.totalContacted, total, AppColors.primaryLight),
          const SizedBox(height: 10),
          _barRow('Closed', stats.totalClosed, total, AppColors.success),
        ],
      ),
    );
  }

  Widget _barRow(String label, int count, int total, Color color) {
    final fraction = count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textMedium)),
            Text('$count', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildViewLeadsCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.myLeads),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('View My Leads', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white)),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(height: 84, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          ),
        ],
      );
}
