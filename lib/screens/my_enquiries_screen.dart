import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/enquiry_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../models/enquiry_model.dart';
import '../services/enquiry_hub_service.dart';
import '../utils/app_date_format.dart';
import '../utils/enquiry_status.dart';
import '../utils/role_label_format.dart';
import '../widgets/day_header.dart';
import '../widgets/new_pill.dart';

/// A single shared list across ALL catalog categories — no per-category tab
/// split, confirmed design. Each row carries a small category badge (derived
/// from ServiceCategoryName) so the different kinds of leads stay visually
/// distinguishable without separate tabs.
/// Always a fresh, un-paginated fetch on open (matches how ServicePackage
/// List reloads every visit) — nothing here is TTL-cached, since a stale
/// status pill is exactly the failure mode this feature must avoid.
class MyEnquiriesScreen extends StatefulWidget {
  const MyEnquiriesScreen({super.key});

  @override
  State<MyEnquiriesScreen> createState() => _MyEnquiriesScreenState();
}

class _MyEnquiriesScreenState extends State<MyEnquiriesScreen> with WidgetsBindingObserver {
  final _ctrl = Get.find<EnquiryController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.loadMyEnquiries();
    // EnquiryHubService is now connected app-wide from main_screen.dart's initState() — this
    // call is a harmless redundant no-op once that connection is already live, kept only as
    // extra insurance in case it quietly died between then and this screen opening. Gated on
    // Services being admin-active so it can't fight MainScreen's own connect/disconnect
    // reconciliation (see _reconcileServicesHub) by blindly reconnecting a hub that's meant to
    // stay dark while the tab is deactivated.
    if (!Get.isRegistered<TabConfigController>() || Get.find<TabConfigController>().isServicesActive) {
      EnquiryHubService.to.connect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mobile OSes can silently suspend a socket while backgrounded without a
    // clean close event — MainScreen's own resume handler already reconnects this hub
    // app-wide now; this is a redundant no-op safety net while this screen is active. Same
    // Services-active gate as initState above.
    if (state == AppLifecycleState.resumed &&
        (!Get.isRegistered<TabConfigController>() || Get.find<TabConfigController>().isServicesActive)) {
      EnquiryHubService.to.connect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openDetail(EnquiryModel enquiry) {
    Get.toNamed(AppRoutes.enquiryDetail, arguments: {'id': enquiry.id});
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
              final loading = _ctrl.isLoadingMyEnquiries.value;
              final items = _ctrl.myEnquiries;
              if (loading && items.isEmpty) return _buildShimmer();
              if (items.isEmpty) return _buildEmpty();

              // Same flat header+item cell approach as NotificationsScreen — this list is
              // un-paginated (small per-user volume), so no footer-loader row to account for.
              final cells = groupByDay<EnquiryModel>(items, (i) => i.createdAt);

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _ctrl.loadMyEnquiries,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: cells.length,
                  itemBuilder: (_, i) {
                    final cell = cells[i];
                    return switch (cell) {
                      DayHeaderCell<EnquiryModel>() => DayHeader(cell.label),
                      DayItemCell<EnquiryModel>(item: final enquiry) => _EnquiryRow(
                          enquiry: enquiry,
                          dateText: AppDateFormat.time(enquiry.createdAt),
                          onTap: () => _openDetail(enquiry),
                        ),
                    };
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
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'My Enquiries',
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
            const Text('No enquiries yet',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('Enquire about a package to see it show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          ]),
        ),
      );

  Widget _buildShimmer() => ListView.builder(
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
      );
}

class _EnquiryRow extends StatelessWidget {
  final EnquiryModel enquiry;
  final String dateText;
  final VoidCallback onTap;

  const _EnquiryRow({required this.enquiry, required this.dateText, required this.onTap});

  // Deliberately time-window based, not a persisted "last viewed" flag — EnquiryModel has no
  // isRead/isSeen concept, and building one (local storage, cross-device sync) is out of scope
  // for what was asked. updatedAt (not createdAt) covers both "just submitted" (they're equal at
  // creation) and "something changed recently" (a status/agent change bumps updatedAt) in one
  // check. Accepted wrinkle: this is a different clock than the day-group header above it (rolling
  // 24h vs calendar day), so an 11pm-yesterday item can still show NEW a few hours into today.
  bool get _isRecent => DateTime.now().difference(enquiry.updatedAt) < const Duration(hours: 24);

  @override
  Widget build(BuildContext context) {
    final statusColor = EnquiryStatus.color(enquiry.status);
    final hasAgent = enquiry.assignedAgentCount > 0;
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
                        enquiry.servicePackageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enquiry.serviceName,
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
                    enquiry.status,
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
                  label: enquiry.serviceCategoryName,
                  background: AppColors.surface,
                  foreground: AppColors.primary,
                  border: AppColors.primaryLight.withValues(alpha: 0.25),
                ),
                // "No agent yet" is a normal, expected pipeline state (matches
                // enquiry_detail_screen.dart's own _buildNoAgentCard: neutral textLight +
                // Iconsax.user_search, "An agent will be assigned to your enquiry shortly" — not an
                // error), so it uses the same neutral treatment here, not AppColors.error. Suppressed
                // entirely when a report is under review (below) — an agent can be unassigned while
                // an escalation about them is still being looked into, and showing both together
                // ("No agent yet" + "Report under review") would read as more alarming than either
                // fact alone; the escalation chip already communicates "this is being handled."
                if (hasAgent || !enquiry.hasPendingEscalation)
                  _Chip(
                    label: hasAgent
                        ? '${enquiry.assignedAgentCount} ${enquiry.assignedAgentCount > 1 ? RoleLabelFormat.plural(enquiry.agentRoleLabel) : enquiry.agentRoleLabel} assigned'
                        : 'No ${enquiry.agentRoleLabel} yet',
                    background: (hasAgent ? AppColors.success : AppColors.textLight).withValues(alpha: 0.1),
                    foreground: hasAgent ? AppColors.success : AppColors.textLight,
                    icon: hasAgent ? Iconsax.tick_circle : Iconsax.user_search,
                  ),
                // Matches enquiry_detail_screen.dart's own _buildEscalateSection convention exactly:
                // once a report is actually Pending, that's a green "under review" confirmation, not
                // an orange "you should report this" call-to-action — the orange/flag treatment is
                // reserved for the opposite (not-yet-reported) state, which this list row never shows
                // at all (unlike Detail, there's no tappable "report an issue" affordance here).
                if (enquiry.hasPendingEscalation)
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
