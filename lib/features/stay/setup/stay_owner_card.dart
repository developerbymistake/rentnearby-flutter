import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../models/stay_owner_model.dart';
import 'stay_option_sets.dart';

class StayOwnerCard extends StatelessWidget {
  final StayOwnerModel stay;
  final ValueChanged<bool>? onAcceptingChanged;
  final ValueChanged<StayRoomModel>? onEditPrice;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onReportsTap;
  final VoidCallback? onOpenSetup;

  const StayOwnerCard({
    super.key,
    required this.stay,
    this.onAcceptingChanged,
    this.onEditPrice,
    this.onPreview,
    this.onShare,
    this.onDelete,
    this.onReportsTap,
    this.onOpenSetup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.premium(StayColors.accentDark, alpha: 0.10, blur: 16, offset: const Offset(0, 6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (stay.pendingReportCount > 0) _reportStrip(),
        _photoSection(),
        _content(),
        if (stay.isRejected)
          _bottomStrip(
            color: AppColors.error,
            icon: Icons.cancel_rounded,
            text: stay.rejectedReason != null && stay.rejectedReason!.isNotEmpty
                ? 'Rejected: ${stay.rejectedReason}'
                : 'Rejected',
            action: 'Fix and resubmit',
          ),
        if (stay.isDraft)
          _bottomStrip(
            color: StayColors.accentDark,
            icon: Iconsax.clock,
            text: 'Setup not finished',
            action: 'Continue setup',
          ),
      ]),
    );
  }

  Widget _reportStrip() {
    final count = stay.pendingReportCount;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: GestureDetector(
        onTap: onReportsTap,
        child: Container(
          width: double.infinity,
          color: AppColors.reportAlert,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Icon(Iconsax.warning_2, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text('$count report${count == 1 ? '' : 's'} on this stay',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
          ]),
        ),
      ),
    );
  }

  Widget _bottomStrip({required Color color, required IconData icon, required String text, required String action}) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: GestureDetector(
        onTap: onOpenSetup,
        child: Container(
          width: double.infinity,
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Text(action,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white)),
          ]),
        ),
      ),
    );
  }

  Widget _photoSection() {
    final photo = stay.photos.isNotEmpty ? stay.photos.first.url : null;
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: stay.pendingReportCount > 0 ? Radius.zero : const Radius.circular(16),
        ),
        child: photo != null
            ? CachedNetworkImage(
                imageUrl: photo,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => _placeholder(),
                errorWidget: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
      Positioned(top: 10, left: 10, child: _statusBadge()),
      if (stay.minPricePerNight != null)
        Positioned(top: 10, right: 10, child: _priceBadge()),
    ]);
  }

  Widget _statusBadge() {
    final (String label, List<Color> colors) = switch (stay.status) {
      StayStatus.approved when stay.acceptingGuests => ('LIVE', const [Color(0xFF10B981), Color(0xFF059669)]),
      StayStatus.approved => ('PAUSED', const [Color(0xFF94A3B8), Color(0xFF64748B)]),
      StayStatus.pendingReview => ('UNDER REVIEW', const [AppColors.warning, StayColors.accentDark]),
      StayStatus.rejected => ('REJECTED', const [AppColors.error, Color(0xFFDC2626)]),
      _ => ('DRAFT', const [Color(0xFF94A3B8), Color(0xFF64748B)]),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _priceBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Text('From ${BrowseItem.inr(stay.minPricePerNight!)}/night',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
      );

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(stay.name ?? 'My Stay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ),
          const SizedBox(width: 8),
          Text(_timeAgo(stay.createdAt),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
        ]),
        if (stay.stayTypeName != null && stay.stayTypeName!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(stay.stayTypeName!,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
        ],
        const SizedBox(height: 8),
        _fieldLabel('Locality'),
        const SizedBox(height: 3),
        Row(children: [
          const Icon(Iconsax.location, size: 13, color: StayColors.accent),
          const SizedBox(width: 4),
          Expanded(
            child: Text(stay.locality,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ),
        ]),
        if (stay.isApproved) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: StayColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Expanded(
                child: Text('Accepting guests',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
              ),
              Switch(
                value: stay.acceptingGuests,
                onChanged: onAcceptingChanged,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor: const Color(0xFFD1FAE5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
          ),
        ],
        if (stay.rooms.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final r in stay.rooms) _roomRow(r),
        ],
        if (onDelete != null || onPreview != null || onShare != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          _actions(),
        ],
      ]),
    );
  }

  Widget _roomRow(StayRoomModel r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text('Room ${r.roomIndex} · ${BrowseItem.inr(r.pricePerNight)} / night',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
          ),
          if (onEditPrice != null && !stay.isPendingReview)
            GestureDetector(
              onTap: () => onEditPrice!(r),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('Edit price',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
              ),
            ),
        ]),
      );

  Widget _actions() {
    final cells = <Widget>[
      if (onPreview != null) _actionCell(icon: Iconsax.eye, label: 'View', color: StayColors.accentDark, onTap: onPreview),
      if (onShare != null) _actionCell(icon: Icons.share_rounded, label: 'Share', color: StayColors.accentDark, onTap: onShare),
      if (onDelete != null) _actionCell(icon: Iconsax.trash, label: 'Delete', color: AppColors.error, onTap: onDelete),
    ];
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (int i = 0; i < cells.length; i++) ...[
          if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.divider),
          Expanded(child: cells[i]),
        ],
      ]),
    );
  }

  Widget _actionCell({required IconData icon, required String label, required Color color, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
        height: 100,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: StayColors.gradient),
        child: const Center(child: Icon(Iconsax.building_4, size: 44, color: Colors.white38)),
      );

  Widget _fieldLabel(String text) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textHint));

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}
