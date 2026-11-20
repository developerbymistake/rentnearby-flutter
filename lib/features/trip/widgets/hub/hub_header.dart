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
    this.minHeight = 66,
    this.titleTop = 0,
    this.bottom = 8,
  });

  final String title;
  final String? lead;
  final bool back;
  final VoidCallback? onBack;
  final double minHeight;
  final double titleTop;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: EdgeInsets.only(top: safeTop + DS.s(12), bottom: DS.s(bottom)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: DS.s(-10),
              right: DS.s(12),
              child: Container(
                width: DS.s(74),
                height: DS.s(74),
                decoration: BoxDecoration(shape: BoxShape.circle, color: HubTokens.accent.withValues(alpha: Alpha.v16)),
              ),
            ),
            Positioned(top: DS.s(-8), right: DS.s(16), child: const Art3D(asset: ListingArt.luggage, size: 71)),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(minHeight)),
              child: Padding(
                padding: EdgeInsets.only(left: DS.s(back ? 74 : 18), right: DS.s(98), top: DS.s(titleTop)),
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
                left: DS.s(16),
                top: 0,
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: GestureDetector(
                    onTap: onBack ?? Get.back,
                    child: Container(
                      width: DS.s(42),
                      height: DS.s(42),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: DS.shadows(Ink3D.softShadow)),
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
