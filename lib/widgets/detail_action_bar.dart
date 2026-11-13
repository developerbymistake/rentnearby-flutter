import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_insets.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import '../design/extra/ext_details.dart';

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
  final String? safetyArt;
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
    this.safetyArt,
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

  ListingTone get _tone {
    if (identical(palette, templateTaxiPalette)) return ListingTone.coral;
    if (identical(palette, templateModulePalette)) return ListingTone.forest;
    return ListingTone.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final hasPhone = ownerPhone != null;
    final showReport = !isOwner;
    final chat = DetailBarButton.outline(tone: tone, label: 'Chat', art: ListingArt.speechBalloon, onTap: onChat);
    final directions = DetailBarButton.primary(tone: tone, label: 'Directions', art: ListingArt.worldMap, onTap: _directions);
    return DetailBarShell(
      tone: tone,
      safetyArt: safetyArt,
      safety: safetyText ?? 'Bakhli never collects rent or advance. Always meet and visit before paying.',
      bottomInset: AppInsets.bottomViewPadding(context),
      children: [
        if (showDirections && onChat != null)
          DetailBarPair(left: chat, right: directions, leftLabel: 'Chat', rightLabel: 'Directions')
        else if (showDirections)
          directions
        else if (onChat != null)
          chat,
        if (hasPhone) DetailBarButton.primary(tone: tone, label: callLabel, icon: Icons.call_rounded, onTap: _call),
        if (showReport)
          onReport == null
              ? DetailBarButton.reported(tone: tone, label: 'Reported')
              : DetailBarButton.report(tone: tone, label: reportLabel, onTap: onReport),
      ],
    );
  }
}
