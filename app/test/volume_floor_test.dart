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

  test('1 shown is just above the floor', () {
    expect(shownToDevice(1, 5.5), closeTo(6.445, 1e-9));
  });
}
