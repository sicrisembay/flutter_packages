/// Codecs for CMD_GET_CAN_STATS (0x13) and CMD_RESET_CAN_STATS (0x14).
library;

import 'dart:typed_data';

import 'command_ids.dart';
import '../models/can_stats.dart';

export '../models/can_stats.dart';

// ---------------------------------------------------------------------------
// CMD_GET_CAN_STATS (0x13)
// ---------------------------------------------------------------------------

/// Builds the request payload for CMD_GET_CAN_STATS.
Uint8List buildGetCanStatsRequest() => Uint8List.fromList([cmdGetCanStats]);

/// Parses a CMD_GET_CAN_STATS (0x13) response or unsolicited notification
/// payload into a [CanStats].
CanStats parseGetCanStats(Uint8List payload) {
  if (payload.length < 18) {
    throw ArgumentError(
        'CMD_GET_CAN_STATS payload too short: ${payload.length} bytes');
  }
  if (payload[0] != cmdGetCanStats) {
    throw ArgumentError(
        'CMD_GET_CAN_STATS: unexpected command byte '
        '0x${payload[0].toRadixString(16)}');
  }
  return CanStats.fromPayload(payload);
}

// ---------------------------------------------------------------------------
// CMD_RESET_CAN_STATS (0x14)
// ---------------------------------------------------------------------------

/// Builds the request payload for CMD_RESET_CAN_STATS.
Uint8List buildResetCanStatsRequest() =>
    Uint8List.fromList([cmdResetCanStats]);

/// Parses the response payload for CMD_RESET_CAN_STATS.
///
/// Returns the status byte (0 = success).
int parseResetCanStatsResponse(Uint8List payload) {
  if (payload.length < 2) {
    throw ArgumentError(
        'CMD_RESET_CAN_STATS response too short: ${payload.length} bytes');
  }
  if (payload[0] != cmdResetCanStats) {
    throw ArgumentError(
        'CMD_RESET_CAN_STATS: unexpected command byte '
        '0x${payload[0].toRadixString(16)}');
  }
  return payload[1];
}
