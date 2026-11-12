import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_insets.dart';
import '../config/module_palette.dart';
import '../design/design.dart';

class DetailActionBar extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? ownerPhone;
  final bool isOwner;
  final VoidCallback? onReport;
  final VoidCallback? onChat;
  final Color accent;
  final ModulePalette? palette;
  final bool showDirections;
  final String? whatsAppPhone;
  final String? whatsAppMessage;
  final String callLabel;
  final String reportLabel;
  final String? safetyText;
  const DetailActionBar({
    super.key,
    this.latitude,
    this.longitude,
    this.ownerPhone,
    this.isOwner = false,
    this.onReport,
    this.onChat,
    this.accent = FitnessAppTheme.nearlyBlue,
    this.palette,
    this.showDirections = true,
    this.whatsAppPhone,
    this.whatsAppMessage,
    this.callLabel = 'Call Owner',
    this.reportLabel = 'Report this listing',
    this.safetyText,
  });

  Color get _accent => palette?.accent ?? accent;

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
    final phone = whatsAppPhone ?? ownerPhone;
    if (phone == null) return;
    final url = Uri.parse(
        'https://wa.me/91$phone${whatsAppMessage == null ? '' : '?text=${Uri.encodeComponent(whatsAppMessage!)}'}');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _directionsButton() {
    return GateButton(
      label: 'Directions',
      iconAsset: TravelIcon.route,
      onPressed: _directions,
      gradient: LinearGradient(colors: [_accent, _accent]),
      shadowColor: _accent,
      radius: const BorderRadius.all(Radius.circular(16)),
    );
  }

  Widget _chatButton() {
    return GateOutlineButton(
      label: 'Chat',
      iconAsset: TravelIcon.chat,
      color: _accent,
      height: 52,
      onPressed: onChat,
    );
  }

  Widget _safetyStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(color: palette?.surface ?? FitnessAppTheme.background),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: palette?.accentLight ?? FitnessAppTheme.nearlyBlue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              safetyText ?? 'Bakhli never collects rent or advance. Always meet and visit before paying.',
              textAlign: TextAlign.center,
              style: FitnessAppTheme.caption.copyWith(fontSize: 11, color: FitnessAppTheme.darkText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportButton() {
    final reported = onReport == null;
    return GateOutlineButton(
      label: reported ? 'Reported' : reportLabel,
      icon: reported ? Icons.flag_rounded : Icons.flag_outlined,
      color: reported ? FitnessAppTheme.lightText : PickKit.bad,
      fill: reported ? FitnessAppTheme.nearlyWhite : PickKit.badTint,
      onPressed: onReport,
      height: 50,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = ownerPhone != null;
    final showReport = !isOwner;
    return Container(
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32)),
        boxShadow: GateKit.barShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32)),
            child: _safetyStrip(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + AppInsets.bottomViewPadding(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDirections && onChat != null)
                  Row(
                    children: [
                      Expanded(child: _chatButton()),
                      const SizedBox(width: 10),
                      Expanded(child: _directionsButton()),
                    ],
                  )
                else if (showDirections)
                  SizedBox(width: double.infinity, child: _directionsButton())
                else if (onChat != null)
                  SizedBox(width: double.infinity, child: _chatButton()),
                if (hasPhone) ...[
                  if (showDirections || onChat != null) const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GateButton(
                          label: callLabel,
                          icon: Icons.call_rounded,
                          height: 48,
                          gradient: palette == null
                              ? TripEntryStyle.sunrise
                              : LinearGradient(colors: [palette!.accent, palette!.accentDark]),
                          shadowColor: palette?.accentDark ?? TravelPalette.sunriseStart,
                          radius: const BorderRadius.all(Radius.circular(16)),
                          onPressed: _call,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GateButton(
                          label: 'WhatsApp',
                          icon: Icons.chat_rounded,
                          height: 48,
                          gradient: const LinearGradient(colors: [GateKit.whatsApp, GateKit.whatsApp]),
                          shadowColor: GateKit.whatsApp,
                          radius: const BorderRadius.all(Radius.circular(16)),
                          onPressed: _whatsapp,
                        ),
                      ),
                    ],
                  ),
                ],
                if (showReport) ...[
                  if (showDirections || onChat != null || hasPhone) const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: _reportButton()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
