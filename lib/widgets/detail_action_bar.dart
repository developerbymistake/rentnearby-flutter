import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_insets.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import '../utils/contact_launcher.dart';
import '../utils/contact_message.dart';
import '../design/extra/ext_details.dart';

class DetailActionBar extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? ownerPhone;
  final bool isOwner;
  final VoidCallback? onReport;
  final VoidCallback? onChat;
  final ModulePalette? palette;
  final bool showDirections;
  final String? whatsAppPhone;
  final String? whatsAppMessage;
  final String reportLabel;
  final String? safetyText;
  final String? safetyArt;
  final bool calm;
  final bool showSafety;
  const DetailActionBar({
    super.key,
    this.latitude,
    this.longitude,
    this.ownerPhone,
    this.isOwner = false,
    this.onReport,
    this.onChat,
    this.palette,
    this.showDirections = true,
    this.whatsAppPhone,
    this.whatsAppMessage,
    this.reportLabel = 'Report this listing',
    this.safetyText,
    this.safetyArt,
    this.calm = false,
    this.showSafety = true,
  });

  static const String defaultSafety = 'Bakhli never collects payment. Always meet and visit before paying.';


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

  ListingTone get _tone {
    if (identical(palette, templateTaxiPalette)) return ListingTone.coral;
    if (identical(palette, templateModulePalette)) return ListingTone.forest;
    return ListingTone.indigo;
  }

  Widget _calm(BuildContext context, ListingTone tone) {
    final p = DetailLook.paletteOf(tone);
    final buttons = <Widget>[
      if (showDirections)
        DetailCalmButton(kind: DetailCalmKind.tint, palette: p, label: 'Directions', icon: Icons.directions_outlined, onTap: _directions),
      if (ownerPhone != null)
        DetailCalmButton(
          kind: DetailCalmKind.tint,
          palette: p,
          label: ContactMessage.call,
          icon: Icons.call_rounded,
          iconColor: Ink3D.title,
          onTap: () => ContactLauncher.call(ownerPhone!),
        ),
      if (onChat != null)
        DetailCalmButton(kind: DetailCalmKind.tint, palette: p, label: 'Chat', icon: Icons.chat_bubble_outline_rounded, onTap: onChat),
      if (whatsAppPhone != null)
        DetailCalmButton(
          kind: DetailCalmKind.whatsApp,
          palette: p,
          label: ContactMessage.whatsApp,
          onTap: () => ContactLauncher.whatsApp(whatsAppPhone!, message: whatsAppMessage),
        ),
    ];
    return DetailBarShell(
      calm: true,
      tone: tone,
      safety: showSafety ? (safetyText ?? defaultSafety) : '',
      bottomInset: AppInsets.bottomViewPadding(context),
      children: [
        if (buttons.isNotEmpty) DetailBarRow(calm: true, children: buttons),
        if (!isOwner)
          onReport == null
              ? DetailCalmButton(kind: DetailCalmKind.reported, palette: p, label: 'Reported')
              : DetailCalmButton(kind: DetailCalmKind.report, palette: p, label: reportLabel, onTap: onReport),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    if (calm) return _calm(context, tone);
    final hasPhone = ownerPhone != null;
    final showReport = !isOwner;
    final stacked = showDirections && (onChat != null || whatsAppPhone != null);
    final buttons = <Widget>[
      if (showDirections) DetailBarButton.primary(tone: tone, label: 'Directions', art: ListingArt.worldMap, onTap: _directions, stacked: stacked),
      if (hasPhone)
        DetailBarButton.primary(tone: tone, label: ContactMessage.call, icon: Icons.call_rounded, onTap: () => ContactLauncher.call(ownerPhone!), stacked: stacked),
      if (onChat != null)
        DetailBarButton.outline(tone: tone, label: 'Chat', art: ListingArt.speechBalloon, onTap: onChat, stacked: stacked),
      if (whatsAppPhone != null)
        DetailBarButton.outline(
          tone: tone,
          label: ContactMessage.whatsApp,
          icon: Icons.chat_rounded,
          onTap: () => ContactLauncher.whatsApp(whatsAppPhone!, message: whatsAppMessage),
          stacked: stacked,
        ),
    ];
    return DetailBarShell(
      tone: tone,
      safetyArt: safetyArt,
      safety: safetyText ?? defaultSafety,
      bottomInset: AppInsets.bottomViewPadding(context),
      children: [
        if (buttons.isNotEmpty) DetailBarRow(children: buttons),
        if (showReport)
          onReport == null
              ? DetailBarButton.reported(tone: tone, label: 'Reported')
              : DetailBarButton.report(tone: tone, label: reportLabel, onTap: onReport),
      ],
    );
  }
}
