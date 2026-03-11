/// CAN error counter and frame-loss statistics model (CMD_GET_CAN_STATS 0x13).
library;

import 'dart:typed_data';

/// Decoded payload of a CMD_GET_CAN_STATS (0x13) response or unsolicited
/// notification frame.
///
/// Payload layout (all uint16 little-endian):
/// ```
/// [0]     0x13  command ID
/// [1-2]   TxErrorCnt
/// [3-4]   TxErrorCntMax
/// [5-6]   RxErrorCnt
/// [7-8]   RxErrorCntMax
/// [9-10]  PassiveErrorCnt
/// [11-12] stat_downstream_packet_loss_cnt
/// [13-14] stat_upstream_packet_loss_cnt
/// [15-16] stat_rx_buffer_overflow_cnt
/// [17]    Status (0 = success)
/// ```
class CanStats {
  /// Current transmit error counter value.
  final int txErrorCount;

  /// Peak transmit error counter value since last reset.
  final int txErrorCountMax;

  /// Current receive error counter value.
  final int rxErrorCount;

  /// Peak receive error counter value since last reset.
  final int rxErrorCountMax;

  /// Number of times the node entered error-passive state.
  final int passiveErrorCount;

  /// Number of downstream (host → bus) frames dropped due to buffer overflow.
  final int downstreamPacketLoss;

  /// Number of upstream (bus → host) frames dropped due to buffer overflow.
  final int upstreamPacketLoss;

  /// Number of times the RX FIFO buffer overflowed.
  final int rxBufferOverflow;

  /// Device-reported status byte (0 = success).
  final int status;

  const CanStats({
    required this.txErrorCount,
    required this.txErrorCountMax,
    required this.rxErrorCount,
    required this.rxErrorCountMax,
    required this.passiveErrorCount,
    required this.downstreamPacketLoss,
    required this.upstreamPacketLoss,
    required this.rxBufferOverflow,
    required this.status,
  });

  /// Decodes from the full command payload (starting with command byte 0x13).
  factory CanStats.fromPayload(Uint8List payload) {
    assert(payload.length >= 18, 'CanStats payload must be ≥ 18 bytes');
    final bd = ByteData.sublistView(payload);
    return CanStats(
      txErrorCount: bd.getUint16(1, Endian.little),
      txErrorCountMax: bd.getUint16(3, Endian.little),
      rxErrorCount: bd.getUint16(5, Endian.little),
      rxErrorCountMax: bd.getUint16(7, Endian.little),
      passiveErrorCount: bd.getUint16(9, Endian.little),
      downstreamPacketLoss: bd.getUint16(11, Endian.little),
      upstreamPacketLoss: bd.getUint16(13, Endian.little),
      rxBufferOverflow: bd.getUint16(15, Endian.little),
      status: payload[17],
    );
  }

  @override
  String toString() =>
      'CanStats(txErr=$txErrorCount/$txErrorCountMax, '
      'rxErr=$rxErrorCount/$rxErrorCountMax, '
      'passiveErr=$passiveErrorCount, '
      'dsLoss=$downstreamPacketLoss, usLoss=$upstreamPacketLoss, '
      'rxOverflow=$rxBufferOverflow, status=$status)';
}
