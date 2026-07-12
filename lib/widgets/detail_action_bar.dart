import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';

class DetailActionBar extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? ownerPhone;
  final bool isOwner;
  final VoidCallback? onReport;
  final VoidCallback? onChat;
  const DetailActionBar({
    super.key,
    this.latitude,
    this.longitude,
    this.ownerPhone,
    this.isOwner = false,
    this.onReport,
    this.onChat,
  });

  void _directions() async {
    if (latitude == null || longitude == null) return;
    final geoUrl = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
    if (await canLaunchUrl(geoUrl)) {
      launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      return;
    }
    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    );
    launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
  }

  void _call() async {
    if (ownerPhone == null) return;
    final url = Uri.parse('tel:+91$ownerPhone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _whatsapp() async {
    if (ownerPhone == null) return;
    final url = Uri.parse('https://wa.me/91$ownerPhone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _directionsButton() {
    return ElevatedButton.icon(
      onPressed: _directions,
      icon: const Icon(Icons.near_me_rounded, size: 20),
      label: const Text(
        'Directions',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  // Always the white/outlined style — stays visually consistent whether Chat
  // is the sole contact method (phone hidden) or paired alongside Call/WhatsApp.
  Widget _chatButton() {
    return OutlinedButton.icon(
      onPressed: onChat,
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: const Text('Chat',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primaryLight),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _reportButton() {
    final reported = onReport == null;
    return OutlinedButton.icon(
      onPressed: onReport,
      icon: Icon(reported ? Icons.flag_rounded : Icons.flag_outlined, size: 18),
      label: Text(reported ? 'Reported' : 'Report this listing',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
      style: reported
          ? OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMedium,
              side: const BorderSide(color: AppColors.divider),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            )
          : OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              backgroundColor: AppColors.error.withValues(alpha: 0.06),
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = ownerPhone != null;
    final showReport = !isOwner;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + AppInsets.bottomViewPadding(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Chat + Directions — always paired when onChat is available,
          // regardless of whether the owner's phone is visible (Chat is the sole
          // contact method in that case, or sits alongside Call/WhatsApp below —
          // either way, same layout, same outlined style).
          if (onChat != null)
            Row(
              children: [
                Expanded(child: _chatButton()),
                const SizedBox(width: 10),
                Expanded(child: _directionsButton()),
              ],
            )
          else
            SizedBox(width: double.infinity, child: _directionsButton()),
          if (hasPhone) ...[
            const SizedBox(height: 10),
            // Row 3: Call Owner + WhatsApp side by side
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.call_rounded, size: 20),
                    label: const Text('Call Owner',
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
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
                    onPressed: _whatsapp,
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: const Text('WhatsApp',
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
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
          if (showReport) ...[
            const SizedBox(height: 10),
            // Row 4: Report this listing — full width
            SizedBox(width: double.infinity, child: _reportButton()),
          ],
        ],
      ),
    );
  }
}
