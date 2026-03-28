/// CAN bitrate configuration enumerations for CMD_CAN_START.
///
/// Both enums are calculated for an 80 MHz FDCAN clock (time quantum = 12.5 ns)
/// targeting an 87.5 % sample point where achievable.
///
/// The `.index` (0-based declaration order) of each value corresponds directly
/// to the `ARB_BITRATE_E` / `DATA_BITRATE_E` firmware index sent in
/// `Payload[1]` / `Payload[2]` of CMD_CAN_START.
library;

/// Arbitration phase bitrate selection for the FDCAN peripheral.
///
/// Index values match `ARB_BITRATE_E` in:
/// https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md
enum ArbBitrate {
  /// 1000 kbit/s  (index 0)
  rate1000k,

  /// 800 kbit/s — 87.0 % sample point (closest achievable)  (index 1)
  rate800k,

  /// 500 kbit/s  (index 2)
  rate500k,

  /// 250 kbit/s  (index 3)
  rate250k,

  /// 125 kbit/s  (index 4)
  rate125k,

  /// 100 kbit/s  (index 5)
  rate100k,

  /// 50 kbit/s   (index 6)
  rate50k,

  /// 20 kbit/s   (index 7)
  rate20k,

  /// 10 kbit/s   (index 8)
  rate10k;
}

/// Data phase bitrate selection for the FDCAN peripheral.
///
/// Index values match `DATA_BITRATE_E` in:
/// https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md
enum DataBitrate {
  /// 5000 kbit/s  (index 0)
  rate5000k,

  /// 2000 kbit/s  (index 1)
  rate2000k,

  /// 1000 kbit/s  (index 2)
  rate1000k,

  /// 800 kbit/s — 88.0 % sample point (closest achievable)  (index 3)
  rate800k,

  /// 500 kbit/s  (index 4)
  rate500k,

  /// 250 kbit/s  (index 5)
  rate250k,

  /// 125 kbit/s  (index 6)
  rate125k,

  /// 100 kbit/s  (index 7)
  rate100k;
}
