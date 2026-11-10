import 'dart:math';

/// Per-output "audible floor": the lowest system volume (percent) at which
/// that output makes sound. The app shows volume on a scale where 0 is silent
/// and 1..100 runs from just audible to full on a geometric scale: every
/// shown step multiplies the system volume by the same ratio, which is how
/// loudness is heard. So 5 is only slightly above 1, and the same number is
/// a similar quietness on USB and Bluetooth.
///
/// Measured by ear on the Eggel Active 3 (Windows, 2026-11-11).
double audibleFloorFor(String outputName) {
  final n = outputName.toLowerCase();
  if (n.contains('active 3')) return 5.5; // Bluetooth ("Headphones (Active 3)")
  if (n.contains('(speaker)')) return 0.5; // USB-C ("Speakers (Speaker)")
  return 0;
}

/// Device percent -> shown percent. At or below the floor it is silent: 0.
/// Outputs with no floor (0) stay linear.
double deviceToShown(double device, double floor) {
  if (device <= floor) return 0;
  if (floor <= 0) return device.clamp(0.0, 100.0).toDouble();
  return (100 * log(device / floor) / log(100 / floor)).clamp(0.0, 100.0);
}

/// Shown percent -> device percent. 0 stays silent; anything above it starts
/// just over the floor and rises geometrically to 100.
double shownToDevice(double shown, double floor) {
  if (shown <= 0) return 0;
  final s = shown.clamp(0.0, 100.0);
  if (floor <= 0) return s.toDouble();
  return (floor * pow(100 / floor, s / 100)).clamp(0.0, 100.0).toDouble();
}
