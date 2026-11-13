import 'package:bakhli/design/extra/art_3d.dart';
import 'package:bakhli/design/extra/meals_card_v.dart';
import 'package:bakhli/design/extra/wide_card.dart';
import 'package:bakhli/design/extra/workout_card.dart';
import 'package:bakhli/design/tokens/listing_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

Widget _photo(int i) => Image.asset('assets/images/design/hotel/hotel_$i.png', fit: BoxFit.cover);

void _noop() {}

const _acts = [WideAction(icon: Icons.phone, label: 'Call', onTap: _noop), WideAction(icon: Icons.mail, label: 'Enquiry', onTap: _noop)];

List<Widget> _scene(String which) {
  void tap() {}
  return switch (which) {
    'stay' => [
        WideCard(
          tone: ListingTone.list(ListingTone.forest, 0),
          kind: WideKind.photo,
          photo: _photo(1),
          sticker: ListingArt.key,
          badge: 'Featured',
          tag: 'For stay',
          title: 'Deodar Cottage',
          subtitle: 'Kausani',
          chips: const ['Homestay', 'Breakfast', 'Deluxe room'],
          priceCaption: 'FROM',
          number: '1,500',
          unit: '/night',
          label: 'In Nainital',
          actions: _acts,
          onTap: tap,
        ),
        WideCard(
          tone: ListingTone.list(ListingTone.forest, 1),
          kind: WideKind.photo,
          sticker: ListingArt.bed,
          tag: 'FOR STAY',
          title: 'Himalayan View Homestay Retreat And Wellness Resort Long Name',
          subtitle: 'Bhimtal lake road, near the old bus stand, Uttarakhand, India 263136',
          priceCaption: 'FROM',
          number: '1,24,800',
          unit: '/night for two guests',
          label: 'Bhimtal. About 9 km away from your place',
          labelNote: 'By road it can take longer.',
          actions: _acts,
        ),
        WideCard(
          tone: ListingTone.cF,
          kind: WideKind.photo,
          photo: _photo(2),
          sticker: ListingArt.hotel,
          tag: 'FOR STAY',
          title: 'Pine Lodge',
          subtitle: 'Almora',
          reserveChips: false,
          priceCaption: 'FROM',
          number: '900',
          unit: '/night',
          onGo: tap,
        ),
        const WideCardSkeleton(kind: WideKind.photo),
      ],
    'taxi' => [
        WideCard(
          tone: ListingTone.cA,
          art: ListingArt.taxi,
          tag: 'TAXI \u00b7 FEATURED',
          title: 'Rakesh Singh',
          subtitle: 'Innova \u00b7 7 seats\nNainital',
          chips: const ['Round trip'],
          number: '\u20b92,400',
          unit: 'to Nainital',
          label: 'Based near Haldwani. About 5 km away',
          actions: _acts,
        ),
        WideCard(
          tone: ListingTone.cB,
          art: ListingArt.bus,
          tag: 'TAXI',
          title: 'Sunil Kumar Negi Travels',
          subtitle: 'Tempo Traveller \u00b7 12 seats\nMallital, Nainital \u00b7 Listed Nov 2026',
          chips: const ['Local taxi', 'Round trip', 'Replies in 10 min', 'Reverse'],
          picked: true,
          actions: [
            const WideAction(icon: Icons.phone, label: 'Call', onTap: _noop),
            WideAction(
              icon: Icons.mail,
              label: 'Enquiry',
              onTap: _noop,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Text('Asked')),
              ),
            ),
          ],
          actionRows: const [
            [WideAction(icon: Icons.check, label: 'Selected', selected: true), WideAction(icon: Icons.done_all, label: 'I booked', busy: true)],
          ],
        ),
        WideCard(
          tone: ListingTone.cC,
          art: ListingArt.taxi,
          tag: 'TAXI',
          title: 'Mohan',
          subtitle: 'Dzire \u00b7 4 seats',
          badge: 'New',
          number: '\u20b916',
          unit: '/km local',
          onGo: tap,
          trailing: const SizedBox(width: 44, height: 44, child: Icon(Icons.more_vert, color: Colors.white)),
          trailingWidth: 30,
        ),
        const WideCardSkeleton(),
      ],
    'trips' => [
        WideCard(
          tone: ListingTone.cB,
          art: ListingArt.luggage,
          tag: 'Continue your trip',
          title: 'Nainital to Almora',
          subtitle: '13 Nov \u00b7 3 days\nNext: ask taxi drivers',
          chips: const ['Stay 2 of 3', 'Taxi asked'],
          showPrice: false,
          progress: 0.6,
          onTap: tap,
        ),
        WideCard(
          tone: ListingTone.cB,
          art: ListingArt.luggage,
          tag: 'Continue your trip',
          title: 'Nainital to Almora',
          subtitle: '13 Nov \u00b7 3 days',
          reserveChips: false,
          showPrice: false,
          onGo: tap,
          onTap: tap,
        ),
        WideCard(tone: ListingTone.cD, kind: WideKind.slim, art: ListingArt.calendar, title: 'Kasol', subtitle: 'Himachal Pradesh\nComing soon', semanticsLabel: 'Kasol, Coming soon'),
        WideCard(
          tone: ListingTone.cF,
          kind: WideKind.slim,
          art: ListingArt.calendar,
          title: 'Your plan ends in 3 days',
          subtitle: 'Renew to keep your stay live',
                    trailing: DecoratedBox(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: Ink3D.whiteBtn),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), child: Text('Renew', style: Ink3D.text(14, FontWeight.w700, ListingTone.cF.button))),
          ),
        ),
        WideCard(
          tone: ListingTone.cE,
          kind: WideKind.photo,
          photo: _photo(3),
          sticker: ListingArt.key,
          tag: 'FOR STAY',
          title: 'Paused stay',
          subtitle: 'Not taking guests now',
          dimmed: true,
          number: 'On request',
        ),
        const WideCardSkeleton(kind: WideKind.slim),
      ],
    'rails' => [
        MealsRail(children: [
          MealsCardV(tone: ListingTone.cA, art: ListingArt.mountain, title: 'Nainital', description: 'Uttarakhand\n24 places', number: '24', unit: 'places', onTap: tap),
          MealsCardV(tone: ListingTone.cB, art: ListingArt.camping, title: 'Mussoorie', description: 'Uttarakhand', onTap: tap),
          MealsCardV(tone: ListingTone.cC, art: ListingArt.tent, title: 'Manali', description: 'Himachal\nComing soon'),
        ]),
        MealsRail(children: [
          MealsCardV(tone: ListingTone.cE, photo: _photo(1), sticker: ListingArt.key, title: 'Deodar Cottage Long', description: 'Kausani\nFeatured', number: '1,500', unit: '/night'),
          MealsCardV(tone: ListingTone.cF, photo: const ColoredBox(color: Colors.white24), sticker: ListingArt.bed, title: 'No photo', description: 'Bhimtal lake road near bus stand\nHomestay', number: '\u20b91,24,800', unit: '/night'),
          MealsCardV(tone: ListingTone.cA, art: ListingArt.taxi, title: 'Rakesh', description: 'Innova \u00b7 7 seats\nNainital', goIcon: Icons.add),
        ]),
        MealsGrid(
          count: 3,
          cardBuilder: (c, i, w) => MealsCardV(
            tone: ListingTone.at(i + 3),
            art: [ListingArt.beach, ListingArt.sunrise, ListingArt.mountain][i],
            title: ['Rishikesh', 'Kausani', 'Shimla'][i],
            description: i == 1 ? 'Uttarakhand' : 'Uttarakhand\n18 places',
            number: i == 1 ? null : '18',
            unit: 'places',
            width: w,
          ),
        ),
        const MealsRail(children: [MealsCardSkeleton(), MealsCardSkeleton(), MealsCardSkeleton()]),
      ],
    'workout' => [
        WorkoutCard(tone: ListingTone.forest, art: ListingArt.hotel, eyebrow: 'Looking for a stay?', title: 'Find your stay', subtitle: 'Browse stays near you', ctaLabel: 'Browse Stays', trailing: WorkoutTrailing.dots, onTap: tap),
        WorkoutCard(tone: ListingTone.indigo, art: ListingArt.luggage, eyebrow: 'Travel Planner', title: 'Plan a trip', subtitle: 'Places, days, stay and taxi', trailing: WorkoutTrailing.arrow),
        WorkoutCard(tone: ListingTone.coral, art: ListingArt.taxi, eyebrow: 'Featured \u00b7 Dzire \u00b7 4 seats', title: 'Pradeep Kumar', subtitle: 'Haldwani \u00b7 \u20b92,400 to Nainital', trailing: WorkoutTrailing.arrow),
        WorkoutCard(tone: ListingTone.forest, art: ListingArt.luggage, eyebrow: 'All done', title: 'Your trip is arranged', subtitle: 'Stay and taxi are both set for all three days', ctaLabel: 'Open summary', trailing: WorkoutTrailing.ring, progress: 1),
        WorkoutCard(tone: ListingTone.cF, art: ListingArt.calendar, eyebrow: '60% done', title: 'Saved for later', subtitle: 'Pick up where you left', ctaLabel: 'See what is still to do', chips: const ['Stay 2 of 3', 'Taxi asked', 'Way back open']),
        WorkoutCard(tone: ListingTone.cD, art: ListingArt.camera, eyebrow: 'Instagram', title: 'Follow us', ctaLabel: 'Follow', minHeight: 112),
      ],
    _ => const [],
  };
}

void main() {
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\foundation';
  });

  const pages = {'stay': Color(0xFFD8EEDA), 'taxi': Color(0xFFFFE3DA)};
  for (final s in ['stay', 'taxi', 'trips', 'rails', 'workout']) {
    for (final cfg in [(1.0, 360.0), (1.3, 360.0), (1.0, 300.0), (1.3, 300.0)]) {
      testWidgets('cards $s ${cfg.$1} ${cfg.$2}', (t) async {
        debugDisableShadows = false;
        await pumpPhone(
          t,
          Scaffold(
            backgroundColor: pages[s] ?? const Color(0xFFF2F3F8),
            body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _scene(s)))),
          ),
          size: Size(cfg.$2, 1900),
          devicePixelRatio: 2,
          textScale: cfg.$1,
        );
        await settlePhone(t);
        await shot(t, 'A_${s}_${cfg.$1}_${cfg.$2.toInt()}');
        debugDisableShadows = true;
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('cards taps reach the right callback', (t) async {
    final log = <String>[];
    await pumpPhone(
      t,
      Scaffold(
        body: ListView(children: [
          WideCard(
            tone: ListingTone.cA,
            art: ListingArt.taxi,
            title: 'Rakesh',
            onTap: () => log.add('card'),
            actions: [
              WideAction(icon: Icons.phone, label: 'Call', onTap: () => log.add('call')),
              const WideAction(icon: Icons.mail, label: 'Asked'),
            ],
          ),
          WideCard(tone: ListingTone.cB, art: ListingArt.taxi, title: 'Go', onGo: () => log.add('go'), onTap: () => log.add('card2')),
        ]),
      ),
    );
    await t.tap(find.text('Call'));
    await t.tap(find.text('Asked'));
    await t.tap(find.text('Rakesh'));
    await t.tap(find.byIcon(Icons.arrow_forward));
    await t.pump(const Duration(milliseconds: 400));
    expect(log, ['call', 'card', 'go']);
  });
}
