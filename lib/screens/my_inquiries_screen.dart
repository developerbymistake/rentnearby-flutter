import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/inquiry_controller.dart';
import '../models/inquiry_model.dart';
import '../services/inquiry_hub_service.dart';
import '../utils/app_date_format.dart';
import '../utils/inquiry_status.dart';
import '../utils/role_label_format.dart';
import '../widgets/day_header.dart';
import '../widgets/max_width_content.dart';
import '../widgets/new_pill.dart';

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

  void _openDetail(InquiryModel inquiry) {
    Get.toNamed(AppRoutes.inquiryDetail, arguments: {'id': inquiry.id});
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

              // Same flat header+item cell approach as NotificationsScreen — this list is
              // un-paginated (small per-user volume), so no footer-loader row to account for.
              final cells = groupByDay<InquiryModel>(items, (i) => i.createdAt);

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _ctrl.loadMyInquiries,
                child: MaxWidthContent(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                    itemCount: cells.length,
                    itemBuilder: (_, i) {
                      final cell = cells[i];
                      return switch (cell) {
                        DayHeaderCell<InquiryModel>() => DayHeader(cell.label),
                        DayItemCell<InquiryModel>(item: final inquiry) => _InquiryRow(
                            inquiry: inquiry,
                            dateText: AppDateFormat.time(inquiry.createdAt),
                            onTap: () => _openDetail(inquiry),
                          ),
                      };
                    },
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
              height: 106,
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

  // Deliberately time-window based, not a persisted "last viewed" flag — InquiryModel has no
  // isRead/isSeen concept, and building one (local storage, cross-device sync) is out of scope
  // for what was asked. updatedAt (not createdAt) covers both "just submitted" (they're equal at
  // creation) and "something changed recently" (a status/agent change bumps updatedAt) in one
  // check. Accepted wrinkle: this is a different clock than the day-group header above it (rolling
  // 24h vs calendar day), so an 11pm-yesterday item can still show NEW a few hours into today.
  bool get _isRecent => DateTime.now().difference(inquiry.updatedAt) < const Duration(hours: 24);

  @override
  Widget build(BuildContext context) {
    final statusColor = InquiryStatus.color(inquiry.status);
    final hasAgent = inquiry.assignedAgentCount > 0;
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
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(
                  label: inquiry.serviceCategoryName,
                  background: AppColors.surface,
                  foreground: AppColors.primary,
                  border: AppColors.primaryLight.withValues(alpha: 0.25),
                ),
                // "No agent yet" is a normal, expected pipeline state (matches
                // inquiry_detail_screen.dart's own _buildNoAgentCard: neutral textLight +
                // Iconsax.user_search, "An agent will be assigned to your inquiry shortly" — not an
                // error), so it uses the same neutral treatment here, not AppColors.error. Suppressed
                // entirely when a report is under review (below) — an agent can be unassigned while
                // an escalation about them is still being looked into, and showing both together
                // ("No agent yet" + "Report under review") would read as more alarming than either
                // fact alone; the escalation chip already communicates "this is being handled."
                if (hasAgent || !inquiry.hasPendingEscalation)
                  _Chip(
                    label: hasAgent
                        ? '${inquiry.assignedAgentCount} ${inquiry.assignedAgentCount > 1 ? RoleLabelFormat.plural(inquiry.agentRoleLabel) : inquiry.agentRoleLabel} assigned'
                        : 'No ${inquiry.agentRoleLabel} yet',
                    background: (hasAgent ? AppColors.success : AppColors.textLight).withValues(alpha: 0.1),
                    foreground: hasAgent ? AppColors.success : AppColors.textLight,
                    icon: hasAgent ? Iconsax.tick_circle : Iconsax.user_search,
                  ),
                // Matches inquiry_detail_screen.dart's own _buildEscalateSection convention exactly:
                // once a report is actually Pending, that's a green "under review" confirmation, not
                // an orange "you should report this" call-to-action — the orange/flag treatment is
                // reserved for the opposite (not-yet-reported) state, which this list row never shows
                // at all (unlike Detail, there's no tappable "report an issue" affordance here).
                if (inquiry.hasPendingEscalation)
                  _Chip(
                    label: 'Report under review',
                    background: AppColors.success.withValues(alpha: 0.1),
                    foreground: AppColors.success,
                    icon: Icons.check_circle_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_isRecent) ...[const NewPill(), const SizedBox(width: 8)],
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

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final IconData? icon;

  const _Chip({required this.label, required this.background, required this.foreground, this.border, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10.5, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}
