import 'package:bakhli/models/browse_item.dart';
import 'package:bakhli/models/plot_model.dart';
import 'package:bakhli/utils/area_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('area keeps its real digits', () {
    expect(AreaFormat.number(0.25), '0.25');
    expect(AreaFormat.number(0.04), '0.04');
    expect(AreaFormat.number(0.05), '0.05');
    expect(AreaFormat.number(2.25), '2.25');
    expect(AreaFormat.number(0.3), '0.3');
    expect(AreaFormat.number(1.0), '1');
    expect(AreaFormat.number(12000), '12000');
    expect(AreaFormat.number(0), '0');
    expect(AreaFormat.number(double.nan), '0');
  });

  test('card and detail show the same area', () {
    final card = BrowseItem.plot(id: 'p', userId: 'u', areaValue: 0.25, areaUnit: 'acre');
    final nearby = NearbyPlotModel.fromJson({
      'id': 'p',
      'areaValue': 0.25,
      'areaUnit': 'acre',
      'plotType': 'Residential',
      'latitude': 29.2,
      'longitude': 79.5,
      'distanceKm': 1.0,
    });
    expect(card.priceValue, '0.25 acre');
    expect(nearby.areaDisplay, '0.25 acre');
    expect(AreaFormat.label(0.04, 'acre'), '0.04 acre');
  });
}
