/// Immutable snapshot of a single soil sensor reading.
class SensorReading {
  /// Creates a [SensorReading] with all measured parameters.
  const SensorReading({
    required this.moisture,
    required this.temperature,
    required this.conductivity,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.readAt,
  });

  /// Volumetric water content (%).
  final double moisture;

  /// Soil temperature (°C). Negative values indicate sub-zero conditions.
  final double temperature;

  /// Electrical conductivity (µS/cm).
  final double conductivity;

  /// Soil pH value (0.0 – 14.0).
  final double ph;

  /// Available nitrogen content (mg/kg). Zero on basic 3-register sensors.
  final double nitrogen;

  /// Available phosphorus content (mg/kg). Zero on basic 3-register sensors.
  final double phosphorus;

  /// Available potassium content (mg/kg). Zero on basic 3-register sensors.
  final double potassium;

  /// Timestamp when the reading was taken.
  final DateTime readAt;

  /// Whether this reading has NPK data (extended 7-register sensor).
  bool get hasNpk =>
      nitrogen > 0 || phosphorus > 0 || potassium > 0;

  /// Whether this reading is recent enough to pre-fill a soil log form.
  bool get isRecent =>
      DateTime.now().difference(readAt).inMinutes < 10;
}
