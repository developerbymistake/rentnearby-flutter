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
  const DetailActionBar({
    super.key,
    this.latitude,
    this.longitude,
    this.ownerPhone,
    this.isOwner = false,
    this.onReport,
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

  Widget _directionsButton({required bool paired}) {
    return ElevatedButton.icon(
      onPressed: _directions,
      icon: Icon(Icons.near_me_rounded, size: paired ? 18 : 20),
      label: Text(
        paired ? 'Directions' : 'Get Directions',
        style: TextStyle(fontFamily: 'Poppins', fontSize: paired ? 13 : 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: Size(0, paired ? 50 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  Widget _reportButton() {
    final reported = onReport == null;
    return OutlinedButton.icon(
      onPressed: onReport,
      icon: Icon(reported ? Icons.flag_rounded : Icons.flag_outlined, size: 18),
      label: Text(reported ? 'Reported' : 'Report',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
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
          // Row 1: Get Directions (+ Report, when not the owner)
          if (showReport)
            Row(
              children: [
                Expanded(child: _directionsButton(paired: true)),
                const SizedBox(width: 10),
                Expanded(child: _reportButton()),
              ],
            )
          else
            SizedBox(width: double.infinity, child: _directionsButton(paired: false)),
          if (hasPhone) ...[
            const SizedBox(height: 10),
            // Row 2: Call Owner + WhatsApp side by side
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
        ],
      ),
    );
  }
}
