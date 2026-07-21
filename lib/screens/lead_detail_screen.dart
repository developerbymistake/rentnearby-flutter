import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/agent_controller.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_status_history_model.dart';
import '../utils/inquiry_status.dart';
import '../widgets/max_width_content.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

enum _StepState { completed, active, pending, terminalNegative }

/// The Agent-facing mirror of InquiryDetailScreen — same summary card and
/// status stepper (InquiryStatus/_StepTile reused as-is, generic over
/// status+history already), same "Your Details" card (which is exactly what
/// an agent needs: the customer's name/mobile/message), but swaps the
/// consumer's read-only "Assigned Agent" card for a Contact Customer card
/// (Call/WhatsApp against the lead's own mobile) plus a genuinely new
/// status-update control. Matches AdminUpdateInquiryStatus's permissiveness
/// (no enforced state machine) rather than inventing new transition rules —
/// buttons just offer the natural forward step plus the two terminal
/// branches, same shape the stepper itself already draws.
class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({super.key});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  final _ctrl = Get.find<AgentController>();
  late final String _leadId;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _leadId = args['id'] as String? ?? '';
    if (_leadId.isNotEmpty) _ctrl.loadLeadDetail(_leadId);
  }

  @override
  void dispose() {
    _ctrl.clearCurrentLeadDetail();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${_months[local.month - 1]} ${local.year}, $hour12:$minute $ampm';
  }

  String _formatDateOnly(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  Future<void> _call(String phone) async {
    final url = Uri.parse('tel:+91$phone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsapp(String phone) async {
    final url = Uri.parse('https://wa.me/91$phone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _updateStatus(String status) async {
    final note = _noteCtrl.text.trim();
    final ok = await _ctrl.updateLeadStatus(_leadId, status, note: note.isEmpty ? null : note);
    if (ok) _noteCtrl.clear();
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
              final loading = _ctrl.isLoadingLeadDetail.value;
              final detail = _ctrl.currentLeadDetail.value;
              if (loading && (detail == null || detail.id != _leadId)) return _buildShimmer();
              if (detail == null || detail.id != _leadId) return _buildNotFound();
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => _ctrl.loadLeadDetail(_leadId),
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
                        _buildSectionTitle('Customer Details'),
                        const SizedBox(height: 10),
                        _buildDetailsCard(detail),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Contact Customer'),
                        const SizedBox(height: 10),
                        _buildContactCard(detail),
                        if (!InquiryStatus.isTerminalNegative(detail.status) && detail.status != InquiryStatus.confirmed) ...[
                          const SizedBox(height: 20),
                          _buildSectionTitle('Update Status'),
                          const SizedBox(height: 10),
                          _buildUpdateStatusCard(detail),
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
                  'Lead Details',
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
          Text('Submitted on ${_formatDateOnly(detail.createdAt)}',
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
              timestampText: reached.contains(steps[i]) ? _formatDate(_historyFor(detail, steps[i])!.createdAt) : null,
            ),
          if (isNegativeTerminal)
            _StepTile(
              label: detail.status,
              state: _StepState.terminalNegative,
              isLast: true,
              timestampText: _historyFor(detail, detail.status) != null ? _formatDate(_historyFor(detail, detail.status)!.createdAt) : null,
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
            _infoRow(Iconsax.calendar_1, 'Preferred Date', _formatDateOnly(detail.preferredDateOrTripStart!)),
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

  Widget _buildContactCard(InquiryDetailModel detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      // Same two-genuinely-separate-buttons treatment as InquiryDetailScreen's
      // agent card — here both point at detail.mobile since a lead only has
      // one phone number on file, not agent.phone vs agent.whatsAppNumber.
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _call(detail.mobile),
              icon: const Icon(Icons.call_rounded, size: 20),
              label: const Text('Call', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _whatsapp(detail.mobile),
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text('WhatsApp', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<(String label, String status, Color color)> _nextStatusOptions(String current) {
    if (current == InquiryStatus.submitted) {
      return [
        ('Mark Contacted', InquiryStatus.contacted, AppColors.warning),
        ('Cancel', InquiryStatus.cancelled, AppColors.error),
        ('Reject', InquiryStatus.rejected, AppColors.error),
      ];
    }
    if (current == InquiryStatus.contacted) {
      return [
        ('Mark Confirmed', InquiryStatus.confirmed, AppColors.success),
        ('Cancel', InquiryStatus.cancelled, AppColors.error),
        ('Reject', InquiryStatus.rejected, AppColors.error),
      ];
    }
    return const [];
  }

  Widget _buildUpdateStatusCard(InquiryDetailModel detail) {
    final options = _nextStatusOptions(detail.status);
    if (options.isEmpty) return const SizedBox.shrink();
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
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final busy = _ctrl.isUpdatingStatus.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in options)
                  ElevatedButton(
                    onPressed: busy ? null : () => _updateStatus(opt.$2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: opt.$3,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: opt.$3.withValues(alpha: 0.5),
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(opt.$1, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotFound() => Center(
        child: const Text('Lead not found', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
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
