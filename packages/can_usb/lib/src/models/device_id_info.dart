/// Model returned by CMD_GET_DEVICE_ID (0x00).
library;

/// Response data from CMD_GET_DEVICE_ID.
///
/// Contains the fixed device identity byte (expected: [kDeviceId] = `0xAC`)
/// and the three firmware version components added in the updated protocol.
class DeviceIdInfo {
  /// Device identity byte — expected to be `0xAC`.
  final int deviceId;

  /// Firmware major version number.
  final int versionMajor;

  /// Firmware minor version number.
  final int versionMinor;

  /// Firmware patch version number.
  final int versionPatch;

  const DeviceIdInfo({
    required this.deviceId,
    required this.versionMajor,
    required this.versionMinor,
    required this.versionPatch,
  });

  /// Human-readable firmware version string, e.g. `"1.2.3"`.
  String get firmwareVersion => '$versionMajor.$versionMinor.$versionPatch';

  @override
  String toString() =>
      'DeviceIdInfo(deviceId: 0x${deviceId.toRadixString(16).toUpperCase()}, '
      'firmware: $firmwareVersion)';

  @override
  bool operator ==(Object other) =>
      other is DeviceIdInfo &&
      other.deviceId == deviceId &&
      other.versionMajor == versionMajor &&
      other.versionMinor == versionMinor &&
      other.versionPatch == versionPatch;

  @override
  int get hashCode =>
      Object.hash(deviceId, versionMajor, versionMinor, versionPatch);
}
