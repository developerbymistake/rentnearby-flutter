import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../models/listing_model.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onGoLive;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onDelete,
    this.onToggleActive,
    this.onGoLive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo — left side thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: Stack(
                children: [
                  listing.photos.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: listing.photos.first,
                          height: 110,
                          width: 100,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _photoPlaceholder(),
                          errorWidget: (_, _, _) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: listing.isActive ? AppColors.success : Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        listing.isActive ? 'LIVE' : 'DRAFT',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content — right side
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.roomTypeName ?? 'Room for Rent',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (listing.priceMonthly != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                            child: Text(listing.priceDisplay,
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Iconsax.location, size: 11, color: AppColors.primaryLight),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            [listing.districtName, listing.cityName].where((e) => e != null).join(', '),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (listing.roomTypeName != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                          child: Text(listing.roomTypeName!,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500)),
                        ),
                        const Spacer(),
                        Text(_timeAgo(listing.createdAt),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textHint)),
                      ]),
                    ],
                    if (onDelete != null || onToggleActive != null || onGoLive != null) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 6),
                      if (!listing.isActive && onGoLive != null)
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            child: InkWell(
                              onTap: onGoLive,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.white),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Make it Live',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            if (onToggleActive != null)
                              Expanded(
                                child: GestureDetector(
                                  onTap: onToggleActive,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(listing.isActive ? Iconsax.eye_slash : Iconsax.eye,
                                          size: 13, color: listing.isActive ? AppColors.textLight : AppColors.success),
                                      const SizedBox(width: 4),
                                      Text(listing.isActive ? 'Disable' : 'Enable',
                                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500,
                                              color: listing.isActive ? AppColors.textLight : AppColors.success)),
                                    ],
                                  ),
                                ),
                              ),
                            if (onDelete != null)
                              GestureDetector(
                                onTap: onDelete,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.trash, size: 13, color: AppColors.error),
                                    SizedBox(width: 4),
                                    Text('Delete', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.error)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Widget _photoPlaceholder() => Container(
        height: 110,
        width: 100,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: const Center(
          child: Icon(Icons.home_rounded, size: 36, color: Colors.white38),
        ),
      );
}
