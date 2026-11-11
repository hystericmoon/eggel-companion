import 'package:eggel_companion/speaker/volume_floor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('floors for the two Eggel outputs', () {
    expect(audibleFloorFor('Headphones (Active 3)'), 5.5);
    expect(audibleFloorFor('Speakers (Speaker)'), 0.5);
    expect(audibleFloorFor('Realtek'), 0);
  });

  test('round trip and edges', () {
    for (final f in [0.0, 0.5, 5.5]) {
      expect(shownToDevice(0, f), 0);
      expect(shownToDevice(100, f), 100);
      expect(deviceToShown(100, f), 100);
      expect(deviceToShown(f, f), 0);
      for (final v in [1.0, 10.0, 50.0, 99.0]) {
        expect(deviceToShown(shownToDevice(v, f), f), closeTo(v, 1e-9));
      }
    }
  });

  test('steps are geometric: 5 is only slightly above 1', () {
    // USB floor 0.5%: shown 1 ~0.52%, shown 5 ~0.65%, shown 50 ~7%.
    expect(shownToDevice(1, 0.5), closeTo(0.5 * 1.0546, 0.01));
    expect(shownToDevice(5, 0.5), lessThan(0.7));
    expect(shownToDevice(50, 0.5), closeTo(7.07, 0.05));
    // Bluetooth floor 5.5%: shown 5 is below 7%.
    expect(shownToDevice(5, 5.5), lessThan(7));
  });

  test('planVolume attenuates per app below the Bluetooth floor', () {
    expect(planVolume(0, 5.5).endpoint, 0);
    final low = planVolume(1, 5.5);
    expect(low.endpoint, 5.5);
    expect(low.scale, lessThan(0.15));
    final high = planVolume(100, 5.5);
    expect(high.endpoint, 100);
    expect(high.scale, 1);
    // USB floor equals the quietest level: no attenuation.
    expect(planVolume(1, 0.5).scale, 1);
    // Unknown outputs stay linear.
    expect(planVolume(40, 0).endpoint, 40);
  });

  test('shownFromDevice inverts planVolume', () {
    for (final f in [0.5, 5.5]) {
      for (final v in [1.0, 5.0, 30.0, 80.0, 100.0]) {
        final p = planVolume(v, f);
        expect(shownFromDevice(p.endpoint, p.scale, f), closeTo(v, 1e-6));
      }
    }
  });
}
