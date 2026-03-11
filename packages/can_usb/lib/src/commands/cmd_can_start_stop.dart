/// Codecs for CMD_CAN_START (0x01), CMD_CAN_STOP (0x02), and
/// CMD_DEVICE_RESET (0x03).
library;

import 'dart:typed_data';

import 'command_ids.dart';

// ---------------------------------------------------------------------------
// CMD_CAN_START (0x01)
// ---------------------------------------------------------------------------

/// Builds the request payload for CMD_CAN_START.
Uint8List buildCanStartRequest() => Uint8List.fromList([cmdCanStart]);

/// Parses the response payload for CMD_CAN_START.
///
/// Returns the HAL status byte (0 = HAL_OK).
int parseCanStartResponse(Uint8List payload) {
  _assertCommand(payload, cmdCanStart, 'CMD_CAN_START');
  return payload[1];
}

// ---------------------------------------------------------------------------
// CMD_CAN_STOP (0x02)
// ---------------------------------------------------------------------------

/// Builds the request payload for CMD_CAN_STOP.
Uint8List buildCanStopRequest() => Uint8List.fromList([cmdCanStop]);

/// Parses the response payload for CMD_CAN_STOP.
///
/// Returns the HAL status byte (0 = HAL_OK).
int parseCanStopResponse(Uint8List payload) {
  _assertCommand(payload, cmdCanStop, 'CMD_CAN_STOP');
  return payload[1];
}

// ---------------------------------------------------------------------------
// CMD_DEVICE_RESET (0x03)
// ---------------------------------------------------------------------------

/// Builds the request payload for CMD_DEVICE_RESET.
///
/// Note: the device resets immediately and sends no response.
Uint8List buildDeviceResetRequest() => Uint8List.fromList([cmdDeviceReset]);

// ---------------------------------------------------------------------------
// Shared helper
// ---------------------------------------------------------------------------

void _assertCommand(Uint8List payload, int expectedCmd, String name) {
  if (payload.length < 2) {
    throw ArgumentError('$name response too short: ${payload.length} bytes');
  }
  if (payload[0] != expectedCmd) {
    throw ArgumentError(
        '$name: unexpected command byte 0x${payload[0].toRadixString(16)}');
  }
}
