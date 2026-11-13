import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class ThinNote3D extends StatelessWidget {
  const ThinNote3D(this.text, {super.key, this.art = ListingArt.sunrise});

  final String text;
  final String art;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 26, 18, 0),
        padding: const EdgeInsets.fromLTRB(10, 8, 20, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(3, 5), blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Art3D(asset: art, size: 36, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25)),
            const SizedBox(width: 10),
            Flexible(child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, height: 1.35))),
          ],
        ),
      ),
    );
  }
}

class BusyWhitePill extends StatelessWidget {
  const BusyWhitePill({super.key, required this.tone, this.height = 54, this.semanticsLabel});

  final ListingTone tone;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: semanticsLabel,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: const [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(3, 5), blurRadius: 10)],
        ),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: tone.g2)),
      ),
    );
  }
}

class BannerCard3D extends StatelessWidget {
  const BannerCard3D({super.key, required this.image, required this.onClose, this.buttons = const []});

  final Widget image;
  final VoidCallback onClose;
  final List<Widget> buttons;

  static const BorderRadius _radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _radius,
        boxShadow: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 10), blurRadius: 30)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: buttons.isEmpty ? _radius : const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54)),
                child: image,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Tooltip(
                  message: 'Close',
                  child: Tap3D(
                    onTap: onClose,
                    label: 'Close',
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: Ink3D.whiteBtn),
                      child: const Icon(Icons.close_rounded, color: Ink3D.title, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (buttons.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 18), child: PillButtonRow(children: buttons)),
        ],
      ),
    );
  }
}
