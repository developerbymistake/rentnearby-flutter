import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/nearby/nearby_strings.dart';
import 'package:bakhli/features/nearby/widgets/nearby_label_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('titles and fixed lines', () {
    expect(NearbyStrings.featuredTitle, 'Featured near you');
    expect(NearbyStrings.staysNearPlace('Delhi'), 'Stays near Delhi');
    expect(NearbyStrings.taxisNearestToPlace('Delhi'), 'Nearest taxis to Delhi');
    expect(NearbyStrings.jobsNearCity('Nainital'), 'Jobs near Nainital');
    expect(NearbyStrings.thin, 'That is all we have for now.');
  });

  test('km text never rounds down', () {
    expect(NearbyStrings.kmText(25), '25');
    expect(NearbyStrings.kmText(14.9), '15');
    expect(NearbyStrings.kmText(15.1), '16');
    expect(NearbyStrings.kmText(420), '420');
    expect(NearbyStrings.kmText(2.5), '2.5');
    expect(NearbyStrings.kmText(3.0), '3');
  });

  test('label lines', () {
    expect(NearbyStrings.inCity('Haldwani'), 'In Haldwani');
    expect(NearbyStrings.near(null, 25), 'About 25 km away');
    expect(NearbyStrings.far('Haldwani', 'Uttarakhand', 420), 'Haldwani, Uttarakhand. About 420 km away');
    expect(NearbyStrings.far('Haldwani', null, 420), 'Haldwani. About 420 km away');
    expect(NearbyStrings.far(null, 'Uttarakhand', 420), 'About 420 km away');
    expect(NearbyStrings.basedIn('Haldwani', 10), 'Based near Haldwani. About 10 km away');
  });

  test('14.9 km is near and 15.1 km is far, no near-you wording beyond 15', () {
    final a = NearbyDistance.checked(km: 14.9, label: NearbyLabel.near, city: 'Haldwani', state: 'Uttarakhand');
    final b = NearbyDistance.checked(km: 15.1, label: NearbyLabel.near, city: 'Haldwani', state: 'Uttarakhand');
    expect(NearbyLabelText.textFor(a), 'Haldwani. About 15 km away');
    expect(a.isFar, false);
    expect(NearbyLabelText.textFor(b), 'Haldwani, Uttarakhand. About 16 km away');
    expect(b.isFar, true);
    expect(NearbyLabelText.textFor(b).toLowerCase().contains('near you'), false);
  });

  test('inCity without a city falls back, taxi uses based near', () {
    const d = NearbyDistance(km: 3, label: NearbyLabel.inCity);
    expect(NearbyLabelText.textFor(d), 'About 3 km away');
    const t = NearbyDistance(km: 10, label: NearbyLabel.near, city: 'Haldwani');
    expect(NearbyLabelText.textFor(t, taxi: true), 'Based near Haldwani. About 10 km away');
  });
}
