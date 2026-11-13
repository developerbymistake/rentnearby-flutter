import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';

class LegalSectionData {
  const LegalSectionData(this.title, {this.body, this.bullets = const []});
  final String title;
  final String? body;
  final List<String> bullets;
}

class LegalPage3D extends StatefulWidget {
  const LegalPage3D({
    super.key,
    required this.title,
    required this.updated,
    required this.art,
    required this.intro,
    required this.sections,
    required this.caption,
  });

  final String title;
  final String updated;
  final String art;
  final String intro;
  final List<LegalSectionData> sections;
  final String caption;

  static const List<String> sectionArt = [
    ListingArt.clipboard, ListingArt.key, ListingArt.compass, ListingArt.worldMap, ListingArt.speechBalloon,
    ListingArt.star, ListingArt.calendar, ListingArt.pushpin, ListingArt.moneyBag, ListingArt.backpack,
    ListingArt.roundPushpin, ListingArt.luggage, ListingArt.camera, ListingArt.bed, ListingArt.sunrise,
    ListingArt.mountain,
  ];

  @override
  State<LegalPage3D> createState() => _LegalPage3DState();
}

class _LegalPage3DState extends State<LegalPage3D> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _compact = ValueNotifier<bool>(false);
  static const double _compactAfter = 150;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _compact.value = _scroll.hasClients && _scroll.offset > _compactAfter);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _compact.dispose();
    super.dispose();
  }

  void _back() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final w = widget;
    return KitStatusBar(
      lightIcons: false,
      child: Scaffold(
        backgroundColor: ListingPalette.indigo.page,
        body: SafeArea(
          bottom: false,
          child: Stack(children: [
            ListView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: 40 + MediaQuery.paddingOf(context).bottom),
              children: [
                PageHeader3D(tone: tone, title: w.title, subtitle: w.updated, art: w.art, artSize: 128, onBack: _back),
                LegalCard3D(children: [
                  LegalIntro3D(w.intro),
                  for (var i = 0; i < w.sections.length; i++)
                    LegalSection3D(
                      tone: tone,
                      art: LegalPage3D.sectionArt[i % LegalPage3D.sectionArt.length],
                      title: w.sections[i].title,
                      body: w.sections[i].body,
                      bullets: w.sections[i].bullets,
                    ),
                  LegalCaption3D(w.caption),
                ]),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _compact,
                builder: (_, on, _) => IgnorePointer(
                  ignoring: !on,
                  child: AnimatedOpacity(
                    opacity: on ? 1 : 0,
                    duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 180),
                    child: LegalCompactBar3D(tone: tone, title: w.title, onBack: _back),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
