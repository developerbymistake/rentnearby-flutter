import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/auth_controller.dart';
import '../controllers/inquiry_controller.dart';
import '../models/inquiry_model.dart';
import '../services/inquiry_hub_service.dart';
import '../utils/inquiry_status.dart';
import '../widgets/max_width_content.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A single shared list across ALL catalog categories — no per-category tab
/// split, confirmed design. Each row carries a small category badge (derived
/// from ServiceCategoryName) so the different kinds of leads stay visually
/// distinguishable without separate tabs.
/// Always a fresh, un-paginated fetch on open (matches how ServicePackage
/// List reloads every visit) — nothing here is TTL-cached, since a stale
/// status pill is exactly the failure mode this feature must avoid.
class MyInquiriesScreen extends StatefulWidget {
  const MyInquiriesScreen({super.key});

  @override
  State<MyInquiriesScreen> createState() => _MyInquiriesScreenState();
}

class _MyInquiriesScreenState extends State<MyInquiriesScreen> with WidgetsBindingObserver {
  final _ctrl = Get.find<InquiryController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.loadMyInquiries();
    // Connected lazily here rather than app-wide (see main_screen.dart) — a
    // no-op if already connected from a prior visit this session.
    InquiryHubService.to.connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mobile OSes can silently suspend a socket while backgrounded without a
    // clean close event — reconnect on resume while this screen is open,
    // same as MainScreen already does for Chat/Wallet. connect() no-ops if
    // the connection is still alive.
    if (state == AppLifecycleState.resumed) InquiryHubService.to.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  void _openDetail(InquiryModel inquiry) {
    Get.toNamed(AppRoutes.inquiryDetail, arguments: {'id': inquiry.id});
  }

  // This screen is reachable from more than the Services tab (push-notification taps,
  // inquiry_confirmation_screen.dart) so a plain back button doesn't reliably return to
  // Services — jump there explicitly instead.
  void _goToServices() {
    Get.find<AuthController>().tabIndex.value = AppTabs.services;
    Get.until((route) => route.settings.name == AppRoutes.main);
  }

  Widget _servicesShortcutRow() {
    return InkWell(
      onTap: _goToServices,
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
            child: const Icon(Iconsax.briefcase, color: AppColors.primaryLight, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Services',
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
              final loading = _ctrl.isLoadingMyInquiries.value;
              final items = _ctrl.myInquiries;
              if (loading && items.isEmpty) return _buildShimmer();
              if (items.isEmpty) return _buildEmpty();
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _ctrl.loadMyInquiries,
                child: MaxWidthContent(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                    itemCount: items.length + 1,
                    itemBuilder: (_, i) => i < items.length
                        ? _InquiryRow(
                            inquiry: items[i],
                            dateText: _formatDate(items[i].createdAt),
                            onTap: () => _openDetail(items[i]),
                          )
                        : _servicesShortcutRow(),
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
                  'My Inquiries',
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
              child: const Icon(Icons.list_alt_rounded, size: 40, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 20),
            const Text('No inquiries yet',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('Enquire about a package to see it show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 24),
            _servicesShortcutRow(),
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
              height: 92,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
}

class _InquiryRow extends StatelessWidget {
  final InquiryModel inquiry;
  final String dateText;
  final VoidCallback onTap;

  const _InquiryRow({required this.inquiry, required this.dateText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = InquiryStatus.color(inquiry.status);
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
                        inquiry.servicePackageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inquiry.serviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    inquiry.status,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
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
                    inquiry.serviceCategoryName,
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
