/// Per-output "audible floor": the lowest system volume (percent) at which
/// that output makes sound. The app shows volume on a scale where 0 is silent
/// and 1..100 runs from just audible to full, so the same number is about the
/// same quietness on USB and Bluetooth.
///
/// Measured by ear on the Eggel Active 3 (Windows, 2026-11-11).
double audibleFloorFor(String outputName) {
  final n = outputName.toLowerCase();
  if (n.contains('active 3')) return 5.5; // Bluetooth ("Headphones (Active 3)")
  if (n.contains('(speaker)')) return 0.5; // USB-C ("Speakers (Speaker)")
  return 0;
}

/// Device percent -> shown percent. Below the floor it is silent: 0.
double deviceToShown(double device, double floor) {
  if (device <= floor) return 0;
  return ((device - floor) / (100 - floor) * 100).clamp(0.0, 100.0);
}

/// Shown percent -> device percent. 0 stays silent, anything above starts at
/// the floor.
double shownToDevice(double shown, double floor) {
  if (shown <= 0) return 0;
  return (floor + shown.clamp(0.0, 100.0) / 100 * (100 - floor)).clamp(
    0.0,
    100.0,
  );
}
