/// Codec for CMD_SEND_DOWNSTREAM (0x10).
library;

import 'dart:typed_data';

import 'command_ids.dart';
import '../models/can_frame.dart';

/// Builds the request payload for CMD_SEND_DOWNSTREAM (0x10).
///
/// Layout:
/// ```
/// [0]       0x10  CMD_SEND_DOWNSTREAM
/// [1]       TX_TYPE byte
/// [2-5]     Message ID (uint32, little-endian)
/// [6]       DLC
/// [7..7+N]  Data bytes
/// ```
Uint8List buildSendDownstreamRequest(CanFrame frame) {
  final builder = BytesBuilder();
  builder.addByte(cmdSendDownstream);
  builder.addByte(frame.frameType.toByte());

  final idBuf = Uint8List(4);
  ByteData.sublistView(idBuf).setUint32(0, frame.messageId, Endian.little);
  builder.add(idBuf);

  builder.addByte(frame.dlc);
  builder.add(frame.data);
  return builder.toBytes();
}

/// Parses the response payload for CMD_SEND_DOWNSTREAM (0x10).
///
/// Returns the status byte (0 = success, 1 = error).
int parseSendDownstreamResponse(Uint8List payload) {
  if (payload.length < 2) {
    throw ArgumentError(
        'CMD_SEND_DOWNSTREAM response too short: ${payload.length} bytes');
  }
  if (payload[0] != cmdSendDownstream) {
    throw ArgumentError(
        'CMD_SEND_DOWNSTREAM: unexpected command byte '
        '0x${payload[0].toRadixString(16)}');
  }
  return payload[1];
}
