/// Codec for CMD_SEND_UPSTREAM (0x11) — device → host CAN frame notification.
library;

import 'dart:typed_data';

import 'command_ids.dart';
import '../models/can_frame.dart';

/// Parses the CMD_SEND_UPSTREAM (0x11) notification payload into a [CanFrame].
///
/// Layout:
/// ```
/// [0]          0x11  CMD_SEND_UPSTREAM
/// [1]          RX_TYPE byte
/// [2-5]        Message ID (uint32, little-endian)
/// [6]          DLC
/// [7..7+DLC-1] CAN data bytes
/// ```
CanFrame parseSendUpstream(Uint8List payload) {
  if (payload.length < 7) {
    throw ArgumentError(
        'CMD_SEND_UPSTREAM payload too short: ${payload.length} bytes');
  }
  if (payload[0] != cmdSendUpstream) {
    throw ArgumentError(
        'CMD_SEND_UPSTREAM: unexpected command byte '
        '0x${payload[0].toRadixString(16)}');
  }

  final frameType = CanFrameType.fromByte(payload[1]);
  final int messageId =
      ByteData.sublistView(payload, 2, 6).getUint32(0, Endian.little);
  final int dlc = payload[6];

  if (payload.length < 7 + dlc) {
    throw ArgumentError(
        'CMD_SEND_UPSTREAM payload truncated: declared DLC=$dlc but only '
        '${payload.length - 7} data bytes present');
  }

  final data = Uint8List.sublistView(payload, 7, 7 + dlc);

  return CanFrame(
    frameType: frameType,
    messageId: messageId,
    dlc: dlc,
    data: data,
  );
}
