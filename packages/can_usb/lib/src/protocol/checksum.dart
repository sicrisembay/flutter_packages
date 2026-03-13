/// Two's complement checksum utilities for the USB-CANFD frame protocol.
///
/// The algorithm is defined in https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md :
///   1. Sum all bytes in the frame (TAG through last payload byte).
///   2. Compute two's complement: `checksum = (~sum + 1) & 0xFF`.
///   3. A complete frame (including checksum) must sum to 0 mod 256.
library;

import 'dart:typed_data';

/// Computes the two's complement checksum over [data].
///
/// Pass every byte of the frame **except** the checksum itself.
/// Append the returned byte to the frame.
int computeChecksum(Uint8List data) {
  int sum = 0;
  for (final byte in data) {
    sum = (sum + byte) & 0xFF;
  }
  return ((~sum) + 1) & 0xFF;
}

/// Verifies the checksum of a complete frame (all bytes **including**
/// the trailing checksum byte).
///
/// Returns `true` when the sum of all bytes is 0 mod 256.
bool verifyChecksum(Uint8List frame) {
  int sum = 0;
  for (final byte in frame) {
    sum = (sum + byte) & 0xFF;
  }
  return sum == 0;
}
