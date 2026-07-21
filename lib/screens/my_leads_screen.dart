import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/agent_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/inquiry_model.dart';
import '../utils/inquiry_status.dart';
import '../widgets/max_width_content.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The Agent-facing mirror of MyInquiriesScreen — same shared, un-paginated,
/// always-fresh-on-open list shape, but scoped server-side to the caller's
/// own linked Agent (GET /agents/me/leads) instead of their own submissions.
/// Row layout additionally surfaces the customer's name/mobile, which an
/// Agent needs to actually work the lead but a consumer viewing their own
/// inquiry never does.
class MyLeadsScreen extends StatefulWidget {
  const MyLeadsScreen({super.key});

  @override
  State<MyLeadsScreen> createState() => _MyLeadsScreenState();
}

class _MyLeadsScreenState extends State<MyLeadsScreen> {
  final _ctrl = Get.find<AgentController>();

  @override
  void initState() {
    super.initState();
    _ctrl.loadMyLeads();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  void _openDetail(InquiryModel lead) {
    Get.toNamed(AppRoutes.leadDetail, arguments: {'id': lead.id});
  }

  // Reachable from more than the Profile tab (push-notification taps) so a plain back button
  // doesn't reliably return to Settings — jump there explicitly instead.
  void _goToProfileSettings() {
    Get.find<AuthController>().tabIndex.value = AppTabs.profile;
    Get.until((route) => route.settings.name == AppRoutes.main);
  }

  Widget _profileSettingsRow() {
    return InkWell(
      onTap: _goToProfileSettings,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Iconsax.setting_2, color: AppColors.primaryLight, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Profile Settings',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textLight),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.isLoadingLeads.value;
              final items = _ctrl.myLeads;
              if (loading && items.isEmpty) return _buildShimmer();
              if (items.isEmpty) return _buildEmpty();
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _ctrl.loadMyLeads,
                child: MaxWidthContent(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                    itemCount: items.length + 1,
                    itemBuilder: (_, i) => i < items.length
                        ? _LeadRow(
                            lead: items[i],
                            dateText: _formatDate(items[i].createdAt),
                            onTap: () => _openDetail(items[i]),
                          )
                        : _profileSettingsRow(),
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
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'My Leads',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              child: const Icon(Icons.assignment_ind_outlined, size: 40, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 20),
            const Text('No leads yet',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('Inquiries assigned to you will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 24),
            _profileSettingsRow(),
          ]),
        ),
      );

  Widget _buildShimmer() => MaxWidthContent(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(
              height: 108,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
}

class _LeadRow extends StatelessWidget {
  final InquiryModel lead;
  final String dateText;
  final VoidCallback onTap;

  const _LeadRow({required this.lead, required this.dateText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = InquiryStatus.color(lead.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
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
                      Text(
                        lead.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lead.mobile,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    lead.status,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${lead.servicePackageName} · ${lead.serviceName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textMedium, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    lead.serviceCategoryName,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                Text(dateText, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
