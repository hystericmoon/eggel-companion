import 'package:eggel_companion/speaker/volume_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('linear curve is the identity', () {
    expect(sliderToPercent(0.5, 1), closeTo(50, 1e-9));
    expect(percentToSlider(50, 1), closeTo(0.5, 1e-9));
  });

  test('cubic curve gives the quiet end more room', () {
    expect(sliderToPercent(0.5, 3), closeTo(12.5, 1e-9));
    expect(sliderToPercent(0.1, 3), closeTo(0.1, 1e-9));
    expect(sliderToPercent(1, 3), 100);
    expect(sliderToPercent(0, 3), 0);
  });

  test('percent and slider round-trip', () {
    for (final p in [0.2, 1.0, 5.0, 37.0, 100.0]) {
      expect(sliderToPercent(percentToSlider(p, 3), 3), closeTo(p, 1e-9));
    }
  });

  test('out-of-range input is clamped', () {
    expect(sliderToPercent(2, 3), 100);
    expect(percentToSlider(-5, 3), 0);
  });

  test('formatPercent shows a decimal only when quiet', () {
    expect(formatPercent(0.46), '0.5');
    expect(formatPercent(9.94), '9.9');
    expect(formatPercent(35.4), '35');
  });
}
