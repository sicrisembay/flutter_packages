/// CAN / CAN-FD frame model and TX_TYPE / RX_TYPE bit-field helpers.
library;

import 'dart:typed_data';

/// Encodes and decodes the TX_TYPE / RX_TYPE byte used in CMD_SEND_DOWNSTREAM
/// and CMD_SEND_UPSTREAM payloads.
///
/// Bit layout (https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md ):
/// | Bit | Meaning                          |
/// |-----|----------------------------------|
/// |  0  | 0 = CAN Classic, 1 = CAN-FD      |
/// |  1  | 0 = BRS ON,       1 = BRS OFF    |
/// |  2  | 0 = Standard ID,  1 = Extended ID|
/// | 3-7 | Reserved (0)                     |
class CanFrameType {
  /// `true` → CAN-FD frame; `false` → CAN Classic.
  final bool isFd;

  /// `true` → Bit Rate Switch OFF (nominal rate only).
  /// `false` → Bit Rate Switch ON (faster data phase). Only valid for CAN-FD.
  final bool brsOff;

  /// `true` → Extended ID (29-bit); `false` → Standard ID (11-bit).
  final bool isExtended;

  const CanFrameType({
    required this.isFd,
    required this.brsOff,
    required this.isExtended,
  });

  /// Convenience: CAN Classic, BRS OFF, Standard ID (most common).
  const CanFrameType.classic()
      : isFd = false,
        brsOff = true,
        isExtended = false;

  /// Convenience: CAN-FD, BRS ON, Standard ID.
  const CanFrameType.fd({this.isExtended = false})
      : isFd = true,
        brsOff = false;

  /// Encodes to a TX_TYPE byte.
  int toByte() =>
      (isFd ? 0x01 : 0x00) |
      (brsOff ? 0x02 : 0x00) |
      (isExtended ? 0x04 : 0x00);

  /// Decodes from an RX_TYPE / TX_TYPE byte.
  factory CanFrameType.fromByte(int byte) => CanFrameType(
        isFd: (byte & 0x01) != 0,
        brsOff: (byte & 0x02) != 0,
        isExtended: (byte & 0x04) != 0,
      );

  @override
  String toString() =>
      'CanFrameType(fd=$isFd, brsOff=$brsOff, extended=$isExtended)';

  @override
  bool operator ==(Object other) =>
      other is CanFrameType &&
      isFd == other.isFd &&
      brsOff == other.brsOff &&
      isExtended == other.isExtended;

  @override
  int get hashCode => Object.hash(isFd, brsOff, isExtended);
}

/// Represents a CAN or CAN-FD frame (upstream or downstream).
class CanFrame {
  /// Frame type and identifier format.
  final CanFrameType frameType;

  /// 11-bit (standard) or 29-bit (extended) message identifier.
  final int messageId;

  /// Data Length Code: 0-8 for CAN Classic; 0-64 for CAN-FD.
  final int dlc;

  /// Payload bytes. Length must match [dlc].
  final Uint8List data;

  CanFrame({
    required this.frameType,
    required this.messageId,
    required this.dlc,
    required this.data,
  });

  @override
  String toString() =>
      'CanFrame(id=0x${messageId.toRadixString(16)}, dlc=$dlc, type=$frameType)';
}
