import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../controllers/inquiry_controller.dart';
import '../models/agent_model.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_status_history_model.dart';
import '../utils/inquiry_status.dart';
import '../widgets/max_width_content.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

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

class _InquiryDetailScreenState extends State<InquiryDetailScreen> {
  final _ctrl = Get.find<InquiryController>();
  late final String _inquiryId;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _inquiryId = args['id'] as String? ?? '';
    if (_inquiryId.isNotEmpty) _ctrl.loadInquiryDetail(_inquiryId);
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
                        _buildSectionTitle('Assigned Agent'),
                        const SizedBox(height: 10),
                        detail.assignedAgent != null ? _buildAgentCard(detail.assignedAgent!) : _buildNoAgentCard(),
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
                  detail.serviceSectionName,
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

  Widget _buildAgentCard(AgentModel agent) {
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
                    const Text('Your assigned agent', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Two genuinely separate buttons — Call (agent.phone) and WhatsApp
          // (agent.whatsAppNumber) are confirmed-separate fields, never one
          // combined "contact" action. Same visual treatment as
          // DetailActionBar's Call Owner/WhatsApp pair.
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _call(agent.phone),
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
                  onPressed: () => _whatsapp(agent.whatsAppNumber),
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
        ],
      ),
    );
  }

  Widget _buildNoAgentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: const Row(
        children: [
          Icon(Iconsax.user_search, size: 20, color: AppColors.textLight),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'An agent will be assigned to your inquiry shortly.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight),
            ),
          ),
        ],
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
