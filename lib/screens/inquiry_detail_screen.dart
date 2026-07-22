import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/inquiry_controller.dart';
import '../models/agent_model.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_status_history_model.dart';
import '../services/inquiry_hub_service.dart';
import '../utils/app_date_format.dart';
import '../utils/inquiry_status.dart';
import '../utils/role_label_format.dart';
import '../widgets/escalate_inquiry_sheet.dart';
import '../widgets/max_width_content.dart';

enum _StepState { completed, active, pending, terminalNegative }

/// Full Inquiry Detail — a vertical status stepper (Submitted -> Contacted
/// -> Confirmed, with Cancelled/Rejected as terminal red branches off that
/// path rather than steps on it) plus an assigned-Agent card with two
/// genuinely separate Call/WhatsApp buttons (agent.phone vs
/// agent.whatsAppNumber are confirmed-separate fields — never one combined
/// button). MaxWidthContent-wrapped like every other single-column screen
/// in this feature.
class InquiryDetailScreen extends StatefulWidget {
  const InquiryDetailScreen({super.key});

  @override
  State<InquiryDetailScreen> createState() => _InquiryDetailScreenState();
}

class _InquiryDetailScreenState extends State<InquiryDetailScreen> with WidgetsBindingObserver {
  final _ctrl = Get.find<InquiryController>();
  late final String _inquiryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final args = (Get.arguments as Map?) ?? const {};
    _inquiryId = args['id'] as String? ?? '';
    if (_inquiryId.isNotEmpty) _ctrl.loadInquiryDetail(_inquiryId);
    // Connected lazily here rather than app-wide (see main_screen.dart) — this
    // screen can be reached directly from a push notification tap, not only
    // via My Inquiries, so it needs its own connect() too; a no-op if already
    // connected.
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
    // Prevents a late-arriving loadInquiryDetail() response for THIS inquiry from silently
    // clobbering currentDetail after the user has already navigated to a different inquiry's
    // detail screen (out-of-order network responses) — currentDetail must never point at an
    // inquiry no screen is actually showing.
    _ctrl.clearCurrentDetail();
    super.dispose();
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
              final loading = _ctrl.isLoadingDetail.value;
              final detail = _ctrl.currentDetail.value;
              if (loading && (detail == null || detail.id != _inquiryId)) return _buildShimmer();
              if (detail == null || detail.id != _inquiryId) return _buildNotFound();
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => _ctrl.loadInquiryDetail(_inquiryId),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                  child: MaxWidthContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(detail),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Status'),
                        const SizedBox(height: 10),
                        _buildStatusTimeline(detail),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Your Details'),
                        const SizedBox(height: 10),
                        _buildDetailsCard(detail),
                        const SizedBox(height: 20),
                        _buildSectionTitle(detail.assignedAgents.length > 1
                            ? 'Assigned ${RoleLabelFormat.plural(detail.agentRoleLabel)}'
                            : 'Assigned ${detail.agentRoleLabel}'),
                        const SizedBox(height: 10),
                        if (detail.assignedAgents.isEmpty)
                          _buildNoAgentCard(detail.agentRoleLabel)
                        else ...[
                          for (final agent in detail.assignedAgents) ...[
                            _buildAgentCard(agent, detail.agentRoleLabel),
                            const SizedBox(height: 10),
                          ],
                          _buildEscalateSection(detail),
                        ],
                      ],
                    ),
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
                  'Inquiry Details',
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

  Widget _buildSectionTitle(String title) =>
      Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark));

  Widget _buildSummaryCard(InquiryDetailModel detail) {
    final statusColor = InquiryStatus.color(detail.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  detail.serviceCategoryName,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  detail.status,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(detail.servicePackageName,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(detail.serviceName,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text('Submitted on ${AppDateFormat.date(detail.createdAt)}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
        ],
      ),
    );
  }

  InquiryStatusHistoryModel? _historyFor(InquiryDetailModel detail, String status) {
    for (final h in detail.statusHistory.reversed) {
      if (h.status == status) return h;
    }
    return null;
  }

  Widget _buildStatusTimeline(InquiryDetailModel detail) {
    final steps = InquiryStatus.steps;
    final isNegativeTerminal = InquiryStatus.isTerminalNegative(detail.status);
    final currentIndex = steps.indexOf(detail.status);
    final reached = detail.statusHistory.map((h) => h.status).toSet();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++)
            _StepTile(
              label: steps[i],
              state: isNegativeTerminal
                  ? (reached.contains(steps[i]) ? _StepState.completed : _StepState.pending)
                  : (i < currentIndex
                      ? _StepState.completed
                      : (i == currentIndex ? _StepState.active : _StepState.pending)),
              isLast: i == steps.length - 1 && !isNegativeTerminal,
              timestampText: reached.contains(steps[i]) ? AppDateFormat.dateTime(_historyFor(detail, steps[i])!.createdAt) : null,
            ),
          if (isNegativeTerminal)
            _StepTile(
              label: detail.status,
              state: _StepState.terminalNegative,
              isLast: true,
              timestampText: _historyFor(detail, detail.status) != null ? AppDateFormat.dateTime(_historyFor(detail, detail.status)!.createdAt) : null,
              note: _historyFor(detail, detail.status)?.note,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(InquiryDetailModel detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Iconsax.user, 'Name', detail.fullName),
          _infoRow(Iconsax.call, 'Mobile', detail.mobile),
          if (detail.email != null && detail.email!.isNotEmpty) _infoRow(Iconsax.sms, 'Email', detail.email!),
          if (detail.preferredDateOrTripStart != null)
            _infoRow(Iconsax.calendar_1, 'Preferred Date', AppDateFormat.date(detail.preferredDateOrTripStart!)),
          if (detail.numberOfPeople != null) _infoRow(Iconsax.profile_2user, 'People', '${detail.numberOfPeople}'),
          if (detail.message != null && detail.message!.isNotEmpty) _infoRow(Iconsax.message_text, 'Message', detail.message!, isLast: true),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(AgentModel agent, String roleLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: agent.photoUrl.isEmpty
                      ? Container(color: AppColors.surface, child: const Icon(Iconsax.user, color: AppColors.primaryLight, size: 24))
                      : CachedNetworkImage(
                          imageUrl: agent.photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => Container(color: AppColors.surface, child: const Icon(Iconsax.user, color: AppColors.primaryLight, size: 24)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text('Your assigned $roleLabel', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
              if (agent.experience != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '${agent.experience} yrs experience',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Deliberately no Call/WhatsApp buttons here — contact is one-directional, the agent
          // reaches out to the customer (using the customer's own submitted mobile), never the
          // other way around, so the agent's own number is never surfaced to the consumer.
          const Row(
            children: [
              Icon(Iconsax.message_notif, size: 15, color: AppColors.textLight),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "They'll reach out to you shortly regarding your inquiry.",
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAgentCard(String roleLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.user_search, size: 20, color: AppColors.textLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${RoleLabelFormat.withIndefiniteArticle(roleLabel)} will be assigned to your inquiry shortly.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

  // Only shown once at least one agent is actually assigned (the caller already gates this) — a
  // "report an issue" affordance before anyone is handling the lead wouldn't make sense. Once a
  // report is Pending, the row becomes a disabled confirmation chip instead of staying tappable —
  // it isn't meant to be spammable, and the agent themselves is never notified, only Admin.
  Widget _buildEscalateSection(InquiryDetailModel detail) {
    if (detail.hasPendingEscalation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Issue reported',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                  Text('Our team is reviewing — you\'ll be notified',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Color(0xFF059669))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => EscalateInquirySheet.show(context, inquiryId: detail.id, roleLabel: detail.agentRoleLabel),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDBA74), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: AppColors.reportAlert.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: const Icon(Iconsax.flag, size: 14, color: AppColors.reportAlert),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need help with this ${detail.agentRoleLabel}?',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.reportAlert)),
                  const Text('Report an issue · we\'ll review it',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Color(0xFFB45309))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFFDBA74)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() => Center(
        child: Text('Inquiry not found', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
      );

  Widget _buildShimmer() {
    return MaxWidthContent(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Column(
            children: [
              Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 16),
              Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 16),
              Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String label;
  final _StepState state;
  final bool isLast;
  final String? timestampText;
  final String? note;

  const _StepTile({required this.label, required this.state, required this.isLast, this.timestampText, this.note});

  Color get _dotColor => switch (state) {
        _StepState.completed => AppColors.success,
        _StepState.active => AppColors.primary,
        _StepState.pending => AppColors.divider,
        _StepState.terminalNegative => AppColors.error,
      };

  Color get _labelColor => state == _StepState.pending ? AppColors.textLight : AppColors.textDark;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: state == _StepState.pending ? Colors.white : _dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: _dotColor, width: 2),
                ),
                child: state == _StepState.completed || state == _StepState.terminalNegative
                    ? Icon(
                        state == _StepState.terminalNegative ? Icons.close_rounded : Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.divider)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: _labelColor)),
                  if (timestampText != null) ...[
                    const SizedBox(height: 2),
                    Text(timestampText!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                  ],
                  if (note != null && note!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(note!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMedium, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
