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
/// Bends the geometric scale so the middle is louder: a pure geometric scale put
/// shown 40 at about 4%, barely above the Bluetooth floor (owner heard almost
/// nothing at 40, 2026-11-11). Lower = louder middle; 1 = pure geometric.
/// Tune by ear.
const double kShape = 0.55;

double deviceToShown(double device, double floor) {
  if (device <= floor) return 0;
  if (floor <= 0) return device.clamp(0.0, 100.0).toDouble();
  final f =
      log(device / floor) / log(100 / floor); // 0..1 along the geometric span
  return (100 * pow(f.clamp(0.0, 1.0), 1 / kShape))
      .clamp(0.0, 100.0)
      .toDouble();
}

/// Shown percent -> device percent. 0 stays silent; anything above it starts
/// just over the floor and rises geometrically to 100.
double shownToDevice(double shown, double floor) {
  if (shown <= 0) return 0;
  final s = shown.clamp(0.0, 100.0);
  if (floor <= 0) return s.toDouble();
  return (floor * pow(100 / floor, pow(s / 100, kShape)))
      .clamp(0.0, 100.0)
      .toDouble();
}

/// The quietest audible level, as an "effective" system percent. Every output
/// with a floor is made to reach this level at shown 1, by attenuating
/// per-app volume when the output's own floor is higher (Bluetooth).
const double kQuietestPercent = 0.5;

/// How to set an output for a shown level: the output's own volume (percent)
/// and a per-app scale (0..1) applied on top, for going below its floor.
class VolumePlan {
  const VolumePlan(this.endpoint, this.scale);
  final double endpoint;
  final double scale;
}

VolumePlan planVolume(double shown, double floor) {
  if (shown <= 0) return const VolumePlan(0, 1);
  if (floor <= 0) return VolumePlan(shown.clamp(0.0, 100.0).toDouble(), 1);
  final e = shownToDevice(shown, kQuietestPercent);
  if (e >= floor) return VolumePlan(e, 1);
  return VolumePlan(floor, e / floor);
}

/// Inverse of [planVolume], from what the output reports.
double shownFromDevice(double endpoint, double scale, double floor) {
  if (endpoint <= 0) return 0;
  if (floor <= 0) return deviceToShown(endpoint, 0);
  return deviceToShown(endpoint * scale, kQuietestPercent);
}
