import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import '../tokens/design_scale.dart';

class ThinNote3D extends StatelessWidget {
  const ThinNote3D(this.text, {super.key, this.art = ListingArt.sunrise});

  final String text;
  final String art;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(26), DS.s(18), 0),
        padding: EdgeInsets.fromLTRB(DS.s(10), DS.s(8), DS.s(20), DS.s(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DS.circular(24),
          boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(12))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Art3D(asset: art, size: 36, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25)),
            Gap.h(10),
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
        height: DS.s(height),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DS.circular(height / 2),
          boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(10))],
        ),
        child: SizedBox(width: DS.s(20), height: DS.s(20), child: CircularProgressIndicator(strokeWidth: DS.s(2.4), color: tone.g2)),
      ),
    );
  }
}

class BannerCard3D extends StatelessWidget {
  const BannerCard3D({super.key, required this.image, required this.onClose, this.buttons = const []});

  final Widget image;
  final VoidCallback onClose;
  final List<Widget> buttons;

  static BorderRadius get _radius => BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8)));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _radius,
        boxShadow: [BoxShadow(color: Color(0x40000000), offset: DS.shadowOffset(const Offset(0, 10)), blurRadius: DS.shadowBlur(30))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: buttons.isEmpty ? _radius : BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54))),
                child: image,
              ),
              Positioned(
                top: DS.s(12),
                right: DS.s(12),
                child: Tooltip(
                  message: 'Close',
                  child: Tap3D(
                    onTap: onClose,
                    label: 'Close',
                    child: Container(
                      width: DS.s(40),
                      height: DS.s(40),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: DS.shadows(Ink3D.whiteBtn)),
                      child: Icon(Icons.close_rounded, color: Ink3D.title, size: DS.s(22)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (buttons.isNotEmpty) Padding(padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(16), DS.s(18), DS.s(18)), child: PillButtonRow(children: buttons)),
        ],
      ),
    );
  }
}
