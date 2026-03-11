/// Codec for CMD_GET_DEVICE_ID (0x00).
library;

import 'dart:typed_data';

import 'command_ids.dart';
import '../models/device_id_info.dart';

/// Builds the request payload for CMD_GET_DEVICE_ID.
Uint8List buildGetDeviceIdRequest() =>
    Uint8List.fromList([cmdGetDeviceId]);

/// Parses the response payload for CMD_GET_DEVICE_ID.
///
/// Returns a [DeviceIdInfo] containing the device ID byte and the three
/// firmware version components.
///
/// The spec mandates 5 payload bytes:
/// ```
/// [0] cmd    [1] deviceId   [2] major   [3] minor   [4] patch
/// ```
/// Older firmware that returns only 2 bytes is accepted gracefully;
/// version fields default to 0 in that case.
///
/// Throws [ArgumentError] if the payload is shorter than 2 bytes or the
/// command byte does not match.
DeviceIdInfo parseGetDeviceIdResponse(Uint8List payload) {
  if (payload.length < 2) {
    throw ArgumentError(
        'CMD_GET_DEVICE_ID response too short: ${payload.length} bytes');
  }
  if (payload[0] != cmdGetDeviceId) {
    throw ArgumentError(
        'Unexpected command byte: 0x${payload[0].toRadixString(16)}');
  }
  return DeviceIdInfo(
    deviceId: payload[1],
    versionMajor: payload.length > 2 ? payload[2] : 0,
    versionMinor: payload.length > 3 ? payload[3] : 0,
    versionPatch: payload.length > 4 ? payload[4] : 0,
  );
}
