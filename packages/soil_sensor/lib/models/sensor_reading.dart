class SensorReading {
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

  final double moisture;     // %
  final double temperature;  // °C
  final double conductivity; // µS/cm
  final double ph;
  final double nitrogen;     // mg/kg
  final double phosphorus;   // mg/kg
  final double potassium;    // mg/kg
  final DateTime readAt;

  /// Whether this reading has NPK data (extended 7-register sensor).
  bool get hasNpk =>
      nitrogen > 0 || phosphorus > 0 || potassium > 0;

  /// Whether this reading is recent enough to pre-fill a soil log form.
  bool get isRecent =>
      DateTime.now().difference(readAt).inMinutes < 10;
}
