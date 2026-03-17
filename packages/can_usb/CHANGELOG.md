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
