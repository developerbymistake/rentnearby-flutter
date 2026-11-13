import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/design.dart';
import '../design/extra/ext_shared.dart';
import '../models/banner_model.dart';

class DistrictBannerOverlay extends StatefulWidget {
  final BannerModel banner;
  final VoidCallback onDismiss;

  const DistrictBannerOverlay({
    super.key,
    required this.banner,
    required this.onDismiss,
  });

  @override
  State<DistrictBannerOverlay> createState() => _DistrictBannerOverlayState();
}

class _DistrictBannerOverlayState extends State<DistrictBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this)
    ..forward();

  BannerModel get banner => widget.banner;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: DesignColors.scrim,
        child: SafeArea(
          child: Center(
            child: TemplateEntrance(
              animation: templateInterval(_c, 0, 1),
              animationController: _c,
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
    return BannerCard3D(
      onClose: widget.onDismiss,
      image: CachedNetworkImage(
        imageUrl: banner.imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SkeletonBox(height: 200, radius: 0),
        errorWidget: (context, url, error) => Container(
          height: 200,
          color: ListingTone.indigo.tint,
          alignment: Alignment.center,
          child: const Art3D(asset: ListingArt.camera, size: 72),
        ),
      ),
      buttons: [
        if (hasContact) _callButton(),
        if (hasUrl) _urlButton(),
      ],
    );
  }

  Widget _callButton() {
    return WhitePillButton(
      tone: ListingTone.indigo,
      label: 'Call',
      height: 46,
      icon: Icons.phone_rounded,
      onTap: () async {
        final uri = Uri.parse('tel:${banner.contactNumber}');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
    );
  }

  Widget _urlButton() {
    return GradientPillButton(
      tone: ListingTone.indigo,
      label: 'Visit',
      height: 46,
      icon: Icons.open_in_new_rounded,
      onTap: () async {
        final uri = Uri.parse(banner.redirectUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
