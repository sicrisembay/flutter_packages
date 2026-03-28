## 0.1.3

* feat(CMD_CAN_START): add configurable FDCAN bitrate selection to `canStart()`.
  The command now sends two additional payload bytes — arbitration-phase index
  (`Payload[1]`) and data-phase index (`Payload[2]`) — matching the updated
  `CMD_CAN_START` (0x01) spec in FRAME_SPECIFICATION.md.
* feat: add `ArbBitrate` and `DataBitrate` enums (`lib/src/models/bitrate.dart`)
  with one value per supported firmware bitrate setting.
* `CanusbDevice.canStart()` now accepts optional `arbBitrate` and `dataBitrate`
  named parameters; defaults to `ArbBitrate.rate500k` / `DataBitrate.rate2000k`
  for backward-compatible behaviour.
* Export the new `bitrate.dart` model from the package entry point.

## 0.1.2

* feat(Android): add `AndroidSerialTransport` — new `ISerialTransport`
  implementation for Android using the USB Host API (`usb_serial` package).
  `CanusbDevice` now auto-selects `AndroidSerialTransport` on Android and
  `SerialPortTransport` on all other platforms.
* fix(`SerialPortTransport`): null `_port` in `onError` so `isConnected`
  returns `false` immediately on physical USB removal (Windows).
* fix(`SerialPortTransport`): explicitly close the OS serial handle in
  `onError` so Windows releases the COM port and allows re-open after
  the device is plugged back in.

## 0.1.1

* Metadata fix: shortened `pubspec.yaml` description to comply with pub.dev
  60–180 character limit (no functional changes).

## 0.1.0

* Initial release.
* Serial transport layer via `flutter_libserialport` (`SerialPortTransport`).
* Injectable `ISerialTransport` interface for easy unit-test mocking.
* Binary frame builder (`buildFrame`) and streaming frame parser (`FrameParser`).
* CRC/checksum implementation matching the device frame specification.
* Commands: Get Device ID, CAN Start, CAN Stop, Send Downstream (TX), Send
  Upstream (RX), Protocol Status, Get/Reset CAN Stats, Enter DFU.
* High-level `CanusbDevice` API with broadcast streams for received frames,
  protocol status notifications, and CAN stats notifications.
* Typed exception hierarchy: `CanConnectionException`, `CanTimeoutException`,
  `CanChecksumException`, `CanProtocolException`.
