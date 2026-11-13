import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_details.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../models/browse_item.dart';
import '../../trip/trip_strings.dart';
import '../enquiries/stay_enquiry_strings.dart';
import '../models/stay_owner_model.dart';

class StayOwnerCard extends StatelessWidget {
  final StayOwnerModel stay;
  final ValueChanged<bool>? onAcceptingChanged;
  final ValueChanged<StayRoomModel>? onEditPrice;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onReportsTap;
  final VoidCallback? onOpenSetup;
  final VoidCallback? onEnquiries;
  final RxInt? enquiryNewCount;

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
    this.onEnquiries,
    this.enquiryNewCount,
  });

  static final _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    final photo = stay.photos.isNotEmpty && stay.photos.first.url.isNotEmpty ? stay.photos.first.url : null;
    final (String label, Color color) = _status();
    return OwnerStayCard3D(
      tone: _tone,
      title: stay.name ?? 'My Stay',
      subtitle: _timeAgo(stay.createdAt),
      statusLabel: label,
      statusColor: color,
      photo: photo == null
          ? _noPhoto()
          : CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover, placeholder: (_, _) => _noPhoto(), errorWidget: (_, _, _) => _noPhoto()),
      sticker: ListingArt.hotel,
      chips: [if (stay.minPricePerNight != null) 'From ${BrowseItem.inr(stay.minPricePerNight!)}/night'],
      localityLabel: 'LOCALITY',
      locality: stay.locality,
      actions: [
        if (onPreview != null) OwnerAction(icon: Icons.visibility_outlined, label: 'View', onTap: onPreview),
        if (onShare != null) OwnerAction(icon: Icons.ios_share_rounded, label: 'Share', onTap: onShare),
        if (onDelete != null) OwnerAction(icon: Icons.close_rounded, label: 'Delete', onTap: onDelete, danger: true),
      ],
      children: [
        if (stay.rooms.isNotEmpty) OwnerRoomsBox(rows: [for (final r in stay.rooms) _roomRow(r)]),
        if (stay.pendingReportCount > 0) _reportStrip(),
        ?_statusRow(),
        if (onEnquiries != null && !stay.isDraft) _enquiriesRow(),
      ],
    );
  }

  static Widget _noPhoto() => Align(
    alignment: const Alignment(0.62, 0.15),
    child: ExcludeSemantics(
      child: Art3D(
        asset: ListingArt.sunrise,
        size: 104,
        halo: 124,
        haloColor: DetailLook.cardHalo,
        shadowBlur: 6,
        shadowOffset: const Offset(5, 8),
        shadowAlpha: 0.3,
      ),
    ),
  );

  (String, Color) _status() => switch (stay.status) {
    StayStatus.approved when stay.acceptingGuests => ('LIVE', StayOwnerInk.live),
    StayStatus.approved => ('PAUSED', StayOwnerInk.paused),
    StayStatus.pendingReview => ('UNDER REVIEW', StayOwnerInk.review),
    StayStatus.rejected => ('REJECTED', StayOwnerInk.rejected),
    _ => ('DRAFT', StayOwnerInk.paused),
  };

  Widget? _statusRow() {
    if (stay.isApproved) {
      return OwnerStatusRow(
        art: ListingArt.key,
        text: 'Accepting guests',
        trailing: Switch3D(
          tone: _tone,
          value: stay.acceptingGuests,
          onChanged: onAcceptingChanged,
          onGradient: true,
          semanticsLabel: 'Accepting guests',
        ),
      );
    }
    if (stay.isPendingReview) return const OwnerStatusRow(art: ListingArt.calendar, text: 'Under review · We will notify you');
    if (stay.isRejected) {
      final reason = stay.rejectedReason;
      return OwnerStatusRow(
        art: ListingArt.warning,
        text: reason != null && reason.isNotEmpty ? 'Rejected: $reason' : 'Rejected',
        trailing: OnCardPill(label: 'Fix and resubmit', onTap: onOpenSetup, color: _tone.button),
        wideTrailing: true,
      );
    }
    if (stay.isDraft) {
      return OwnerStatusRow(
        art: ListingArt.clipboard,
        text: 'Setup not finished',
        trailing: OnCardPill(label: 'Continue setup', onTap: onOpenSetup, color: _tone.button),
        wideTrailing: true,
      );
    }
    return null;
  }

  Widget _reportStrip() {
    final count = stay.pendingReportCount;
    return OwnerStatusRow(
      light: true,
      art: ListingArt.warning,
      text: '$count report${count == 1 ? '' : 's'} on this stay',
      trailing: const OnCardChevron3D(color: StayOwnerInk.newBadge),
      onTap: onReportsTap,
    );
  }

  Widget _roomRow(StayRoomModel r) {
    final canEdit = onEditPrice != null && !stay.isPendingReview;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${r.label} · ${BrowseItem.inr(r.pricePerNight)} / night',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(13, FontWeight.w600, DesignColors.onPrimary, height: 1.3),
              ),
            ),
            if (canEdit) ...[const SizedBox(width: 8), OnCardPill(label: 'Edit price', width: 84, color: _tone.button, onTap: () => onEditPrice!(r))],
          ],
        ),
      ),
    );
  }

  Widget _enquiriesRow() {
    const ink = DesignColors.onPrimary;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: ink.withValues(alpha: Alpha.v18), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Art3D(asset: ListingArt.speechBalloon, size: 34, shadowBlur: 3, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(TripStrings.enquiries, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, ink)),
                Text(
                  StayEnquiryStrings.rowSubtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(11.5, FontWeight.w400, ink.withValues(alpha: Alpha.v92)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (enquiryNewCount != null)
            Obx(() {
              final n = enquiryNewCount!.value;
              return n > 0 ? OnCardBadge3D(TripStrings.newCount(n)) : const SizedBox.shrink();
            }),
          const OnCardChevron3D(),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: TripStrings.enquiries,
      child: PressScale(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onEnquiries, child: row),
      ),
    );
  }

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
