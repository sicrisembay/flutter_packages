/// Command ID constants for the USB-CANFD binary frame protocol.
///
/// Matches the CMD_* definitions in https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md .
library;

/// Get Device ID (request / response).
const int cmdGetDeviceId = 0x00;

/// CAN Start — starts the FDCAN peripheral (request / response).
const int cmdCanStart = 0x01;

/// CAN Stop — stops the FDCAN peripheral (request / response).
const int cmdCanStop = 0x02;

/// Device Reset — triggers NVIC_SystemReset(); no response.
const int cmdDeviceReset = 0x03;

/// Send Downstream — transmit a CAN / CAN-FD frame to the bus (request / response).
const int cmdSendDownstream = 0x10;

/// Send Upstream — device → host notification of a received CAN frame.
const int cmdSendUpstream = 0x11;

/// Protocol Status — device → host unsolicited FDCAN protocol status notification.
const int cmdProtocolStatus = 0x12;

/// Get CAN Stats — retrieve error counters (request / response + unsolicited).
const int cmdGetCanStats = 0x13;

/// Reset CAN Stats — reset all error counters (request / response).
const int cmdResetCanStats = 0x14;

/// Enter DFU — triggers reset into the STM32 ROM USB DFU bootloader; no response.
const int cmdEnterDfu = 0xF0;

/// Expected Device ID value in the Get Device ID response.
const int kDeviceId = 0xAC;
