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
import '../utils/app_date_format.dart';
import '../utils/inquiry_status.dart';

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

  // Reject was dropped deliberately — it was functionally identical to Cancel everywhere in this
  // codebase (same color, same backend transition rules, no distinct downstream behavior) with no
  // documented reason to keep both as separate agent-facing actions. Backend/admin untouched —
  // Rejected remains a valid status generally, just no longer offered as a button here.
  List<(String label, String status, Color color)> _nextStatusOptions(String current) {
    if (current == InquiryStatus.submitted) {
      return [
        ('Mark Contacted', InquiryStatus.contacted, AppColors.warning),
        ('Cancel', InquiryStatus.cancelled, AppColors.error),
      ];
    }
    if (current == InquiryStatus.contacted) {
      return [
        ('Mark Confirmed', InquiryStatus.confirmed, AppColors.success),
        ('Cancel', InquiryStatus.cancelled, AppColors.error),
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
            return Row(
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : () => _handleStatusTap(options[i]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: options[i].$3,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: options[i].$3.withValues(alpha: 0.5),
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(options[i].$1, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  // Mark Contacted is a routine forward step — fires instantly, same as before. Confirmed/Cancelled
  // are more consequential (one is the terminal happy-path, the other ends the lead entirely), so
  // both now route through a confirmation dialog first rather than firing on a single tap.
  void _handleStatusTap((String, String, Color) opt) {
    final copy = _confirmationCopy(opt.$2);
    if (copy == null) {
      _updateStatus(opt.$2);
      return;
    }
    _showStatusConfirmDialog(status: opt.$2, color: opt.$3, copy: copy);
  }

  ({String title, String message, String confirmLabel})? _confirmationCopy(String status) {
    if (status == InquiryStatus.confirmed) {
      return (
        title: 'Mark as Confirmed?',
        message: 'Are you sure you want to mark this lead as Confirmed?',
        confirmLabel: 'Yes, Confirm',
      );
    }
    if (status == InquiryStatus.cancelled) {
      return (
        title: 'Cancel this Lead?',
        message: 'Are you sure you want to cancel this lead?',
        confirmLabel: 'Yes, Cancel Lead',
      );
    }
    return null;
  }

  // Same Dialog/Row/Expanded shape as ProfileScreen._confirmLogout — icon circle, title, message,
  // two Expanded buttons in one row. Dismiss button deliberately says "No, go back" on both dialogs
  // (not the bare "Cancel" _confirmLogout uses) since "Cancel" is also the lead-status action itself
  // here — using it for dismiss too would put two different-meaning "Cancel"s in the same dialog.
  void _showStatusConfirmDialog({
    required String status,
    required Color color,
    required ({String title, String message, String confirmLabel}) copy,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(InquiryStatus.icon(status), size: 28, color: color),
            ),
            const SizedBox(height: 16),
            Text(copy.title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(copy.message,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('No, go back', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateStatus(status);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(copy.confirmLabel, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildNotFound() => Center(
        child: const Text('Lead not found', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
      );

  Widget _buildShimmer() {
    return Padding(
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
