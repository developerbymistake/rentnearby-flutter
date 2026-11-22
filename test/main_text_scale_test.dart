import 'package:bakhli/config/app_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FX-20 the phone font size is followed between 1.0 and 1.3', () {
    expect(AppFrame.textScalerFor(const TextScaler.linear(2.0)).scale(10), closeTo(13, 0.001));
    expect(AppFrame.textScalerFor(const TextScaler.linear(0.85)).scale(10), closeTo(10, 0.001));
    expect(AppFrame.textScalerFor(const TextScaler.linear(1.15)).scale(10), closeTo(11.5, 0.001));
    expect(AppFrame.textScalerFor(TextScaler.noScaling).scale(10), 10);
  });
}
