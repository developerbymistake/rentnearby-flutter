import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../models/banner_model.dart';

class DistrictBannerOverlay extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback onDismiss;

  const DistrictBannerOverlay({
    super.key,
    required this.banner,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: FadeInUp(
              duration: const Duration(milliseconds: 280),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final hasContact = banner.contactNumber != null;
    final hasUrl = banner.redirectUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image + close button
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(hasContact || hasUrl ? 20 : 20),
                  bottom: Radius.circular(hasContact || hasUrl ? 0 : 20),
                ),
                child: CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: AppColors.surface,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: AppColors.surface,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      size: 40,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Action buttons
          if (hasContact || hasUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  if (hasContact) ...[
                    Expanded(child: _callButton()),
                    if (hasUrl) const SizedBox(width: 12),
                  ],
                  if (hasUrl) Expanded(child: _urlButton()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _callButton() {
    return OutlinedButton.icon(
      onPressed: () async {
        final uri = Uri.parse('tel:${banner.contactNumber}');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      icon: const Icon(Icons.phone_rounded, size: 16),
      label: const Text(
        'Call',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _urlButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(banner.redirectUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: const Text(
        'Visit',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
