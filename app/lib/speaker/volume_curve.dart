import 'dart:math';

/// Maps the slider position (0..1) to a volume percent (0..100).
///
/// With [exponent] 1 the slider is linear. A larger exponent spends more of the
/// slider on the quiet end: at 3, half the slider is only 12.5% volume, so
/// quiet levels get many small steps instead of one jump.
double sliderToPercent(double position, double exponent) =>
    100 * pow(position.clamp(0.0, 1.0), exponent).toDouble();

/// Inverse of [sliderToPercent].
double percentToSlider(double percent, double exponent) =>
    pow((percent / 100).clamp(0.0, 1.0), 1 / exponent).toDouble();

/// Text for a volume readout: one decimal below 10%, whole numbers above.
String formatPercent(double percent) =>
    percent < 10 ? percent.toStringAsFixed(1) : percent.round().toString();
