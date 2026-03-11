/// Codec for CMD_PROTOCOL_STATUS (0x12) — device → host unsolicited notification.
library;

import 'dart:typed_data';

import 'command_ids.dart';
import '../models/protocol_status.dart';

export '../models/protocol_status.dart';

/// Parses the CMD_PROTOCOL_STATUS (0x12) notification payload into a
/// [ProtocolStatus].
ProtocolStatus parseProtocolStatus(Uint8List payload) {
  if (payload.length < 6) {
    throw ArgumentError(
        'CMD_PROTOCOL_STATUS payload too short: ${payload.length} bytes');
  }
  if (payload[0] != cmdProtocolStatus) {
    throw ArgumentError(
        'CMD_PROTOCOL_STATUS: unexpected command byte '
        '0x${payload[0].toRadixString(16)}');
  }
  return ProtocolStatus.fromPayload(payload);
}
