import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _longName = 'Maharaja Rajendra Singh Bahadur Travels And Local Taxi Service';

Map<String, Widget Function()> _cases() => {
      'ModuleHeader leading+widget subtitle+autoHeight': () => ModuleHeader(
            title: 'Conversation with a long name',
            subtitleWidget: Text.rich(const TextSpan(text: 'Stay owner and more words here'), style: TypeTokens.onGradientBody),
            leading: const CircleAvatar(radius: 20),
            trailing: [TextButton(onPressed: () {}, child: const Text('Mark all read'))],
            autoHeight: true,
            subtitleLines: 2,
            bottom: const Wrap(children: [Chip(label: Text('One')), Chip(label: Text('Two')), Chip(label: Text('Three'))]),
          ),
      'ListRow slots': () => ListRow(
            title: 'Cozy valley view room with a very long title for wrapping',
            subtitle: 'Subtitle line one that is long enough to wrap onto a second line okay',
            subtitleLines: 2,
            titleMaxLines: 3,
            tag: 'STAY',
            solidTag: true,
            tagBadge: const Text('Featured'),
            facts: const [CardFact('4 rooms'), CardFact('Meals')],
            priceValue: '12,500',
            priceUnit: '/night',
            elevated: true,
            header: const SizedBox(height: 60),
            body: const Text('body'),
            rows: const [Text('row one'), Text('row two')],
            onTap: () {},
          ),
      'OwnerListingCard variant': () => OwnerListingCard(
            title: 'Riverside homestay',
            subtitle: 'Bhimtal',
            status: 'Live',
            header: const OwnerPhotoBand(),
            toggle: const Row(children: [Expanded(child: Text('Accepting guests')), Switch(value: true, onChanged: null)]),
            strips: const [KitStatusStrip(label: 'Under review. We will tell you soon.', icon: Icons.info_outline)],
            actions: [PillAction(label: 'Edit', onTap: () {})],
          ),
      'DriverOptionCard variant': () => DriverOptionCard(
            name: _longName,
            nameMaxLines: 2,
            vehicle: 'Toyota Innova Crysta white',
            fareValue: '12,500',
            fareUnit: 'Local taxi',
            header: const Text('Best way'),
            selected: true,
            avatarInitial: 'M',
            legColor: DesignColors.primary,
            facts: const [CardFact('AC'), CardFact('6 seats')],
            actions: [PillAction(label: 'Call', onTap: () {}, maxWidth: 120)],
            onTap: () {},
          ),
      'RailCard stacked and no price': () => Wrap(children: [
            SizedBox(
              width: 168,
              height: RailCard.height,
              child: RailCard(title: 'Taxi', onTap: () {}, priceCaption: 'From', priceValue: '1,200', stackedCaption: true, trailing: const Text('Add')),
            ),
            SizedBox(width: 168, height: RailCard.height, child: RailCard(title: 'Taxi', onTap: () {}, noPriceLabel: 'LOCAL TAXI')),
          ]),
      'SlimBar elevated': () => SlimBar(title: 'Nearest stay with a long name here', subtitle: 'Sub', elevated: true, onTap: () {}),
      'HeroBanner reserve': () => HeroBanner(
            title: 'Seeker',
            subtitle: 'Short text',
            subtitleLines: 3,
            reserveSubtitle: true,
            tone: KitTone.seeker,
            onTap: () {},
          ),
      'Buttons compact scale pair': () => ButtonPair(
            first: PrimaryButton(label: 'Continue to the next step now', onPressed: () {}, compact: true, scaleLabel: true, heroCorner: true),
            second: SecondaryButton(label: 'Skip this step for now', onPressed: () {}, compact: true, scaleLabel: true),
          ),
      'KitChoiceChip': () => Wrap(children: [
            KitChoiceChip(label: 'Selected chip', selected: true, onTap: () {}),
            KitChoiceChip(label: 'Idle chip', selected: false, onTap: () {}),
          ]),
      'WhatsAppGlyph': () => const WhatsAppGlyph(size: 18),
      'TemplateTitleRow gutter': () => const TemplateTitleRow(titleTxt: 'Popular places', subTxt: 'See all', gutter: 20),
      'KitTone factories': () => Container(
            height: 40,
            decoration: BoxDecoration(gradient: KitTone.solid(DesignColors.primary).gradient),
          ),
    };

void main() {
  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final e in _cases().entries) {
        testWidgets('${e.key} @${w.toInt()} x$scale', (t) async {
          t.view.physicalSize = Size(w, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(w, 900), textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: ListView(children: [SizedBox(width: w, child: e.value())]),
              ),
            ),
          ));
          await t.pump(const Duration(milliseconds: 700));
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
