import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/design.dart';
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
        color: FitnessAppTheme.darkerText.withValues(alpha: Alpha.strong),
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
    const imageRadius = CardRadius.heroTop;
    final radius = hasContact || hasUrl
        ? imageRadius
        : TripKit.cardRadius;

    return Container(
      decoration: GateKit.card(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: radius,
                child: CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const TemplatePlaceholder(height: 200, radius: 0),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: FitnessAppTheme.background,
                    alignment: Alignment.center,
                    child: const TravelIcon(TravelIcon.photo, size: 44),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FitnessAppTheme.nearlyBlack.withValues(alpha: Alpha.strong),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: FitnessAppTheme.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    return GateOutlineButton(
      label: 'Call',
      height: 44,
      icon: Icons.phone_rounded,
      onPressed: () async {
        final uri = Uri.parse('tel:${banner.contactNumber}');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
    );
  }

  Widget _urlButton() {
    return GateButton(
      label: 'Visit',
      height: 44,
      icon: Icons.open_in_new_rounded,
      onPressed: () async {
        final uri = Uri.parse(banner.redirectUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
