import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'hub_tokens.dart';

class HubHeader extends StatelessWidget {
  const HubHeader({
    super.key,
    required this.title,
    this.lead,
    this.back = false,
    this.onBack,
    this.minHeight = 104,
    this.titleTop = 0,
  });

  final String title;
  final String? lead;
  final bool back;
  final VoidCallback? onBack;
  final double minHeight;
  final double titleTop;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: EdgeInsets.only(top: safeTop, bottom: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -22,
              right: 12,
              child: Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(shape: BoxShape.circle, color: HubTokens.accent.withValues(alpha: Alpha.v16)),
              ),
            ),
            const Positioned(top: -30, right: 16, child: Art3D(asset: ListingArt.luggage, size: 118)),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: EdgeInsets.only(left: back ? 74 : 18, right: 150, top: titleTop),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lead != null) Text(lead!, style: Ink3D.text(14, FontWeight.w400, HubTokens.sub, letterSpacing: 0)),
                    Semantics(
                      header: true,
                      child: Text(title, style: Ink3D.text(28, FontWeight.w700, HubTokens.ink, height: 1.25, letterSpacing: 0)),
                    ),
                  ],
                ),
              ),
            ),
            if (back)
              Positioned(
                left: 16,
                top: 0,
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: GestureDetector(
                    onTap: onBack ?? Get.back,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: Ink3D.softShadow),
                      alignment: Alignment.center,
                      child: Text('\u2039', style: Ink3D.text(28, FontWeight.w400, HubTokens.blue, letterSpacing: 0)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
