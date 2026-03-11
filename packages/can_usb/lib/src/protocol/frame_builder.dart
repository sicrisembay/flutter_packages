/// Frame builder for the USB-CANFD binary frame protocol.
///
/// Frame layout (from FRAME_SPECIFICATION.md):
///
/// | Field      | Offset | Size | Description                          |
/// |------------|--------|------|--------------------------------------|
/// | TAG        | 0      | 1    | Start-of-frame marker (0xFF)         |
/// | Length     | 1      | 2    | Total frame length, little-endian    |
/// | Timestamp  | 3      | 4    | 10 µs resolution, little-endian      |
/// | Packet Seq | 7      | 2    | Sequence number, little-endian       |
/// | Payload    | 9      | N    | Command + data                       |
/// | Checksum   | 9+N    | 1    | Two's complement checksum            |
library;

import 'dart:typed_data';

import 'checksum.dart';

/// Byte value of the start-of-frame marker.
const int kFrameTag = 0xFF;

/// Fixed overhead added by the frame header and checksum (bytes).
const int kFrameOverhead = 10;

/// Maximum allowed total frame length (bytes).
const int kFrameMaxLength = 1023;

/// Builds a complete binary frame ready to send over the serial transport.
///
/// Parameters:
/// - [payload]: Command byte(s) + command-specific data (0 to 1013 bytes).
/// - [timestamp]: 32-bit timestamp in 10 µs ticks (default 0).
/// - [seqNum]: 16-bit packet sequence number (default 0).
///
/// Throws [ArgumentError] if the resulting frame would exceed [kFrameMaxLength].
Uint8List buildFrame({
  required Uint8List payload,
  int timestamp = 0,
  int seqNum = 0,
}) {
  final int totalLength = kFrameOverhead + payload.length;
  if (totalLength > kFrameMaxLength) {
    throw ArgumentError(
      'Frame length $totalLength exceeds maximum of $kFrameMaxLength bytes '
      '(payload is ${payload.length} bytes, max payload is '
      '${kFrameMaxLength - kFrameOverhead} bytes).',
    );
  }

  // Allocate buffer for everything except the checksum first.
  final int bufLen = totalLength - 1; // exclude trailing checksum byte
  final buffer = Uint8List(bufLen);
  final bd = ByteData.sublistView(buffer);

  buffer[0] = kFrameTag;
  bd.setUint16(1, totalLength, Endian.little);
  bd.setUint32(3, timestamp & 0xFFFFFFFF, Endian.little);
  bd.setUint16(7, seqNum & 0xFFFF, Endian.little);
  buffer.setRange(9, 9 + payload.length, payload);

  final int cs = computeChecksum(buffer);

  final frame = Uint8List(totalLength);
  frame.setRange(0, bufLen, buffer);
  frame[totalLength - 1] = cs;

  return frame;
}

/// Extracts the payload bytes from a validated frame.
///
/// Assumes the frame has already passed [verifyChecksum].
/// Returns the bytes at offsets `9 .. totalLength-2` (i.e. excluding
/// the trailing checksum byte).
Uint8List extractPayload(Uint8List frame) {
  final int totalLength = frame.length;
  if (totalLength < kFrameOverhead) {
    throw ArgumentError(
      'Frame too short: $totalLength bytes (minimum is $kFrameOverhead).',
    );
  }
  return Uint8List.sublistView(frame, 9, totalLength - 1);
}
