/// FDCAN protocol status notification model (CMD_PROTOCOL_STATUS 0x12).
library;

/// Decoded payload of a CMD_PROTOCOL_STATUS (0x12) frame.
///
/// Sent automatically by the device whenever the FDCAN protocol status changes.
///
/// Payload layout:
/// ```
/// [0] 0x12  command ID
/// [1] LastErrorCode
/// [2] DataLastErrorCode
/// [3] Activity
/// [4] Flags byte
///       bit0: ErrorPassive
///       bit1: Warning
///       bit2: BusOff
///       bit3: RxESIflag
///       bit4: RxBRSflag
///       bit5: RxFDFflag
///       bit6: ProtocolException
/// [5] TDCvalue
/// ```
class ProtocolStatus {
  /// Last error code from the nominal bit phase (FDCAN_LEC_* value).
  final int lastErrorCode;

  /// Last error code from the data bit phase, CAN-FD only (FDCAN_LEC_* value).
  final int dataLastErrorCode;

  /// Node activity state: 0 = synchronising, 1 = idle, 2 = receiver, 3 = transmitter.
  final int activity;

  /// `true` when the node is in error-passive state (TEC or REC > 127).
  final bool errorPassive;

  /// `true` when the error warning limit has been reached (TEC or REC ≥ 96).
  final bool warning;

  /// `true` when the node is in bus-off state (TEC > 255).
  final bool busOff;

  /// Received Error Status Indicator flag (CAN-FD ESI bit).
  final bool rxEsiFlag;

  /// Received Bit Rate Switch flag (CAN-FD BRS bit of last received frame).
  final bool rxBrsFlag;

  /// Received FD Format flag (CAN-FD FDF bit of last received frame).
  final bool rxFdfFlag;

  /// `true` when a protocol exception event has occurred.
  final bool protocolException;

  /// Transceiver Delay Compensation value in time quanta.
  final int tdcValue;

  const ProtocolStatus({
    required this.lastErrorCode,
    required this.dataLastErrorCode,
    required this.activity,
    required this.errorPassive,
    required this.warning,
    required this.busOff,
    required this.rxEsiFlag,
    required this.rxBrsFlag,
    required this.rxFdfFlag,
    required this.protocolException,
    required this.tdcValue,
  });

  /// Decodes from the full command payload (starting with command byte 0x12).
  factory ProtocolStatus.fromPayload(List<int> payload) {
    assert(payload.length >= 6, 'ProtocolStatus payload must be ≥ 6 bytes');
    final int flags = payload[4];
    return ProtocolStatus(
      lastErrorCode: payload[1],
      dataLastErrorCode: payload[2],
      activity: payload[3],
      errorPassive: (flags & 0x01) != 0,
      warning: (flags & 0x02) != 0,
      busOff: (flags & 0x04) != 0,
      rxEsiFlag: (flags & 0x08) != 0,
      rxBrsFlag: (flags & 0x10) != 0,
      rxFdfFlag: (flags & 0x20) != 0,
      protocolException: (flags & 0x40) != 0,
      tdcValue: payload[5],
    );
  }

  @override
  String toString() =>
      'ProtocolStatus(lec=$lastErrorCode, dlec=$dataLastErrorCode, '
      'busOff=$busOff, errorPassive=$errorPassive, warning=$warning)';
}
